import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });

  try {
    const { messages, context, mode } = await req.json();

    // Authentification obligatoire pour TOUS les modes (quota IA payant)
    const token = (req.headers.get("Authorization") ?? "").replace("Bearer ", "").trim();
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    if (!token || token === anonKey) {
      return new Response(JSON.stringify({ error: "Non authentifié" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const authClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { data: userData } = await authClient.auth.getUser(token);
    const caller = userData?.user;
    if (!caller) {
      return new Response(JSON.stringify({ error: "Session invalide" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Mode "admin" : accès réservé aux administrateurs authentifiés (données agrégées sensibles)
    if (mode === "admin") {
      const { data: isAdmin } = await authClient.rpc("is_admin", { _user_id: caller.id });
      if (!isAdmin) {
        return new Response(JSON.stringify({ error: "Accès réservé aux administrateurs" }), {
          status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }
    const LOVABLE_API_KEY = Deno.env.get("LOVABLE_API_KEY");
    if (!LOVABLE_API_KEY) throw new Error("LOVABLE_API_KEY is not configured");

    // Optionally fetch live stats for admin mode
    let liveContext = "";
    if (mode === "admin") {
      try {
        const supabase = createClient(
          Deno.env.get("SUPABASE_URL")!,
          Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
        );
        const [
          { count: totalSouscripteurs },
          { count: totalPlantations },
          { count: totalPaiements },
          { data: recentPaiements },
        ] = await Promise.all([
          supabase.from("souscripteurs").select("*", { count: "exact", head: true }),
          supabase.from("plantations").select("*", { count: "exact", head: true }),
          supabase.from("paiements").select("*", { count: "exact", head: true }),
          supabase.from("paiements").select("montant_paye, statut, type_paiement").order("created_at", { ascending: false }).limit(100),
        ]);

        const totalEncaisse = (recentPaiements || [])
          .filter((p: any) => p.statut === "valide")
          .reduce((s: number, p: any) => s + (p.montant_paye || 0), 0);

        liveContext = `\n\nDonnées temps réel de la base:
- ${totalSouscripteurs || 0} souscripteurs au total
- ${totalPlantations || 0} plantations enregistrées
- ${totalPaiements || 0} paiements (dont ${new Intl.NumberFormat("fr-FR").format(totalEncaisse)} FCFA encaissés sur les 100 derniers)`;
      } catch (e) {
        console.warn("Could not fetch live stats:", e);
      }
    }

    let systemPrompt = "";
    
    if (mode === "subscriber") {
      systemPrompt = `Tu es l'assistant IA du Portail Souscripteur AgriCapital. Tu aides les souscripteurs (partenaires agricoles) avec leurs questions sur:
- Leurs plantations (superficie, statut, localisation, villages)
- Leurs paiements (Droit d'Accès, redevances mensuelles, arriérés)
- Leur portefeuille et statistiques
- Les offres AgriCapital (PalmElite, PalmInvest, TerraPalm - gratuit)
- Les procédures et démarches
- La hiérarchie géographique: District > Région > Département > Sous-Préfecture > Village

Contexte du souscripteur connecté:
${context || "Aucun contexte disponible"}

Règles:
- Réponds toujours en français
- Sois concis, professionnel et chaleureux
- Utilise le nom du souscripteur quand disponible
- Pour les questions de paiement, oriente vers le bouton "Effectuer un paiement"
- Pour les problèmes techniques, oriente vers le support: +225 07 59 56 60 87
- Ne donne jamais d'informations sur d'autres souscripteurs
- L'offre TerraPalm est entièrement GRATUITE (DA et redevance à 0 FCFA)
- Les paiements se font exclusivement via KKiaPay (Mobile Money et carte bancaire)`;
    } else {
      systemPrompt = `Tu es l'assistant IA avancé du CRM AgriCapital, une plateforme de gestion agro-industrielle de palmiers à huile en Côte d'Ivoire. Tu aides les administrateurs, commerciaux, comptables et responsables avec:

- Analyse des données (souscripteurs, plantations, paiements, commissions)
- Aide à la prise de décision (tendances, alertes, recommandations)
- Guide d'utilisation des fonctionnalités du CRM
- Rédaction de rapports et synthèses
- Optimisation des processus métier
- Gestion géographique: 14 Districts > 31 Régions > 107 Départements > S/Préfectures > Villages

Hiérarchie des rôles:
- Super Admin: accès complet
- Directeur Technico-Commercial: gestion stratégique
- Responsable Commercial de Zone (RCom): gestion régionale
- Chef d'Équipe: encadrement terrain
- Comptable: finances et paiements
- Commercial: prospection et souscriptions
- Service Client: support et tickets
- Opérations: suivi technique des plantations

Offres:
- PalmElite: offre premium avec accompagnement complet
- PalmInvest: offre investissement
- TerraPalm: offre GRATUITE (DA et redevance à 0 FCFA)

Contexte utilisateur:
${context || "Aucun contexte disponible"}${liveContext}

Règles:
- Réponds toujours en français
- Sois professionnel, analytique et proactif
- Fournis des données chiffrées quand possible
- Propose des actions concrètes
- Respecte la confidentialité des données
- Le terme correct est "redevance mensuelle" (pas "redevance modulable")
- Les souscripteurs sont des partenaires agricoles
- Support technique: +225 07 59 56 60 87`;
    }

    const response = await fetch("https://ai.gateway.lovable.dev/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${LOVABLE_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "google/gemini-3-flash-preview",
        messages: [
          { role: "system", content: systemPrompt },
          ...messages,
        ],
        stream: true,
      }),
    });

    if (!response.ok) {
      if (response.status === 429) {
        return new Response(JSON.stringify({ error: "Trop de requêtes. Veuillez réessayer dans quelques instants." }), {
          status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      if (response.status === 402) {
        return new Response(JSON.stringify({ error: "Crédit IA épuisé. Veuillez contacter l'administrateur." }), {
          status: 402, headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      const t = await response.text();
      console.error("AI gateway error:", response.status, t);
      return new Response(JSON.stringify({ error: "Erreur du service IA" }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(response.body, {
      headers: { ...corsHeaders, "Content-Type": "text/event-stream" },
    });
  } catch (e) {
    console.error("AI assistant error:", e);
    return new Response(JSON.stringify({ error: e instanceof Error ? e.message : "Erreur inconnue" }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
