import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.75.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-kkiapay-signature",
};

serve(async (req) => {
  console.log("=== KKiaPay Webhook received ===");
  
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // --- Vérification obligatoire de la signature HMAC KKiaPay (fail-closed) ---
    const webhookSecret = Deno.env.get("KKIAPAY_WEBHOOK_SECRET") ?? Deno.env.get("KKIAPAY_PRIVATE_KEY");
    if (!webhookSecret) {
      console.error("KKIAPAY_WEBHOOK_SECRET non configuré — webhook refusé");
      return new Response(JSON.stringify({ success: false, error: "Webhook non configuré" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 503,
      });
    }

    const signature = req.headers.get("x-kkiapay-signature");
    if (!signature) {
      return new Response(JSON.stringify({ success: false, error: "Signature manquante" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 401,
      });
    }

    const rawBody = await req.text();
    const key = await crypto.subtle.importKey(
      "raw", new TextEncoder().encode(webhookSecret),
      { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
    );
    const sigBuf = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(rawBody));
    const expected = Array.from(new Uint8Array(sigBuf)).map((b) => b.toString(16).padStart(2, "0")).join("");

    if (signature.toLowerCase().replace(/^sha256=/, "") !== expected) {
      console.error("Signature KKiaPay invalide");
      return new Response(JSON.stringify({ success: false, error: "Signature invalide" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 401,
      });
    }

    let body: any;
    try {
      body = JSON.parse(rawBody);
    } catch {
      return new Response(JSON.stringify({ success: false, error: "Payload invalide" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400,
      });
    }
    
    const { status, transactionId, amount, fees, source, data, performed_at } = body;
    console.log(`Transaction ${transactionId}: Status=${status}, Amount=${amount}`);
    
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    
    const reference = data?.reference;
    const paiementId = data?.paiement_id;

    // Find the payment record
    let paiement: any = null;
    
    if (reference) {
      const { data: records } = await supabase.from('paiements').select('*').eq('reference', reference);
      paiement = records?.[0];
    }
    
    if (!paiement && paiementId) {
      const { data: records } = await supabase.from('paiements').select('*').eq('id', paiementId);
      paiement = records?.[0];
    }
    
    if (!paiement && transactionId) {
      const { data: records } = await supabase
        .from('paiements')
        .select('*')
        .contains('metadata', { kkiapay_transaction_id: transactionId });
      paiement = records?.[0];
    }
    
    if (!paiement) {
      console.log("No matching payment found");
      return new Response(
        JSON.stringify({ success: true, message: "No matching payment found, webhook acknowledged" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }
    
    console.log("Found payment:", paiement.id);
    
    // Map status
    let newStatus: string;
    switch (status?.toUpperCase()) {
      case "SUCCESS": newStatus = "valide"; break;
      case "FAILED": newStatus = "echoue"; break;
      case "PENDING": newStatus = "en_attente"; break;
      default: newStatus = paiement.statut;
    }
    
    const updateData: any = {
      statut: newStatus,
      updated_at: new Date().toISOString(),
      metadata: {
        ...(paiement.metadata || {}),
        kkiapay_transaction_id: transactionId,
        kkiapay_status: status,
        method: source || data?.method,
        fees: fees || 0,
        performed_at: performed_at || new Date().toISOString(),
        webhook_received_at: new Date().toISOString()
      }
    };
    
    if (newStatus === "valide") {
      updateData.date_paiement = new Date().toISOString();
      updateData.montant_paye = amount || paiement.montant;
      updateData.mode_paiement = source || 'KKiaPay';
      
      // DA payment: activate plantation
      if (paiement.type_paiement === 'DA' && paiement.plantation_id) {
        const { data: plantation } = await supabase
          .from('plantations')
          .select('superficie_ha, superficie_activee, montant_da, montant_da_paye')
          .eq('id', paiement.plantation_id)
          .single();
        
        if (plantation) {
          const newDaPaye = (plantation.montant_da_paye || 0) + (amount || 0);
          const totalDa = plantation.montant_da || 0;
          const isFullyPaid = newDaPaye >= totalDa;
          
          const plantUpdate: any = {
            montant_da_paye: newDaPaye,
            updated_at: new Date().toISOString()
          };
          
          if (isFullyPaid) {
            plantUpdate.superficie_activee = plantation.superficie_ha;
            plantUpdate.date_activation = new Date().toISOString();
            plantUpdate.statut = 'active';
            plantUpdate.statut_global = 'active';
          }
          
          await supabase.from('plantations').update(plantUpdate).eq('id', paiement.plantation_id);
          console.log(`Plantation ${paiement.plantation_id} updated, DA payé: ${newDaPaye}/${totalDa}`);
        }
      }
    }
    
    const { error: updateError } = await supabase.from('paiements').update(updateData).eq('id', paiement.id);
    
    if (updateError) {
      console.error("Error updating payment:", updateError);
      throw updateError;
    }
    
    console.log(`Payment ${paiement.id} updated to: ${newStatus}`);

    // --- Activation temps réel (0 jour) du compte souscripteur ---
    let activation: any = null;
    if (newStatus === "valide") {
      // 1) Finalisation métier centralisée (échéances, commissions, statuts)
      const { data: finalized, error: finalizeError } = await supabase.rpc('finalize_portal_payment', {
        _paiement_id: paiement.id,
        _transaction_id: transactionId,
        _provider_amount: amount ?? paiement.montant,
        _metadata: updateData.metadata,
        _validated_at: new Date().toISOString(),
      });
      if (finalizeError) console.error("finalize_portal_payment:", finalizeError.message);
      else activation = finalized;

      // 2) Activation immédiate du compte au paiement du dépôt initial
      if (paiement.souscripteur_id && (paiement.est_depot_initial || paiement.type_paiement === 'DA')) {
        const nowIso = new Date().toISOString();
        const { error: activationError } = await supabase
          .from('souscripteurs')
          .update({
            compte_actif: true,
            da_paye_at: nowIso,
            statut: 'actif',
            statut_global: 'actif',
            updated_at: nowIso,
          })
          .eq('id', paiement.souscripteur_id);
        if (activationError) console.error("Activation compte:", activationError.message);
        else console.log(`Compte souscripteur ${paiement.souscripteur_id} activé immédiatement`);
      }
    }

    // Trace de l'événement KKiaPay (source unique d'agrégateur)
    await supabase.from('kkiapay_events').insert({
      transaction_id: transactionId,
      reference: reference ?? paiement.reference,
      paiement_id: paiement.id,
      status: status ?? newStatus,
      amount: amount ?? paiement.montant,
      fees: fees ?? 0,
      source: source ?? 'kkiapay',
      signature_valid: true,
      raw_payload: body,
      processed: true,
      processed_at: new Date().toISOString(),
    });
    
    // Log in historique_activites
    await supabase.from('historique_activites').insert({
      table_name: 'paiements',
      record_id: paiement.id,
      action: 'WEBHOOK_KKIAPAY',
      details: `Webhook KKiaPay: ${status} - ${amount} FCFA - Transaction: ${transactionId}`,
    });
    
    return new Response(
      JSON.stringify({ success: true, paiement_id: paiement.id, new_status: newStatus, activation }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    );

    
  } catch (error: any) {
    console.error("Webhook error:", error);
    return new Response(
      JSON.stringify({ success: false, error: "Erreur de traitement", acknowledged: true }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    );
  }
});
