import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { adminClient, corsHeaders, json, requireUser } from "../_shared/auth.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const admin = adminClient();

    // 1) Authentification obligatoire
    const { user, error: authError } = await requireUser(req, admin);
    if (authError) return authError;

    const { transactionId } = await req.json();
    if (!transactionId || typeof transactionId !== "string" || transactionId.length > 128) {
      return json({ success: false, error: "Identifiant de transaction invalide" }, 400);
    }

    // 2) Autorisation : staff, ou souscripteur propriétaire du paiement lié
    const { data: isStaff } = await admin.rpc("is_staff", { _user_id: user!.id });

    if (!isStaff) {
      const { data: souscripteur } = await admin
        .from("souscripteurs")
        .select("id")
        .eq("user_id", user!.id)
        .maybeSingle();

      let allowed = false;
      if (souscripteur?.id) {
        const { data: paiement } = await admin
          .from("paiements")
          .select("id")
          .eq("souscripteur_id", souscripteur.id)
          .contains("metadata", { kkiapay_transaction_id: transactionId })
          .maybeSingle();
        allowed = !!paiement;
      }

      if (!allowed) {
        return json({ success: false, error: "Accès non autorisé à cette transaction" }, 403);
      }
    }

    const privateKey = Deno.env.get("KKIAPAY_PRIVATE_KEY");
    if (!privateKey) {
      console.error("KKIAPAY_PRIVATE_KEY missing");
      return json({ success: false, error: "Service de paiement indisponible" }, 500);
    }

    const response = await fetch(`https://api.kkiapay.me/api/v1/transactions/status`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-private-key": privateKey,
      },
      body: JSON.stringify({ transactionId }),
    });

    const result = await response.json();

    // KKiaPay status: SUCCESS, PENDING, FAILED
    const status = result.status?.toUpperCase();
    const isSuccess = status === "SUCCESS";

    return json({
      success: true,
      transaction: {
        id: transactionId,
        status,
        isPaymentSuccessful: isSuccess,
        amount: result.amount,
        fees: result.fees || 0,
        source: result.source,
        performedAt: result.performed_at || result.createdAt,
        failureMessage: result.failureMessage || null,
      },
    });
  } catch (error) {
    console.error("KKiaPay verify error:", error);
    return json({ success: false, error: "Une erreur est survenue lors de la vérification" }, 400);
  }
});
