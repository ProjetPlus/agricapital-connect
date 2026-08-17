import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.75.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
};
const json = (p: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(p), { headers: { ...corsHeaders, "Content-Type": "application/json" }, status });


/** Autorise soit un administrateur authentifié, soit un appel interne (service role / secret cron). */
async function authorize(req: Request, admin: any): Promise<Response | null> {
  const deny = (msg: string, status: number) =>
    new Response(JSON.stringify({ success: false, error: msg }), {
      status, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  const bearer = (req.headers.get("Authorization") ?? "").replace("Bearer ", "").trim();
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const cronSecret = Deno.env.get("CRON_SECRET");

  if (serviceKey && bearer === serviceKey) return null;
  if (cronSecret && req.headers.get("x-cron-secret") === cronSecret) return null;
  if (!bearer) return deny("Non authentifié", 401);

  const { data } = await admin.auth.getUser(bearer);
  const user = data?.user;
  if (!user) return deny("Session invalide", 401);
  const { data: isAdmin } = await admin.rpc("is_admin", { _user_id: user.id });
  if (!isAdmin) return deny("Accès réservé aux administrateurs", 403);
  return null;
}

const DEMO_EMAIL = "demo@agricapital.ci";
const DEMO_USERNAME = "agricapital";
const DEMO_PASSWORD = "AgriCapital";

/** Crée (ou réinitialise) le compte de démonstration en lecture seule. Idempotent. */
serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  try {
    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    const denied = await authorize(req, admin);
    if (denied) return denied;

    let userId: string | null = null;
    for (let page = 1; page <= 10; page++) {
      const { data } = await admin.auth.admin.listUsers({ page, perPage: 1000 });
      const found = data?.users?.find((u: any) => u.email?.toLowerCase() === DEMO_EMAIL);
      if (found) { userId = found.id; break; }
      if (!data?.users || data.users.length < 1000) break;
    }

    if (userId) {
      await admin.auth.admin.updateUserById(userId, { password: DEMO_PASSWORD, email_confirm: true });
    } else {
      const { data, error } = await admin.auth.admin.createUser({
        email: DEMO_EMAIL,
        password: DEMO_PASSWORD,
        email_confirm: true,
        user_metadata: { nom_complet: "Compte Démonstration" },
      });
      if (error) return json({ error: error.message }, 400);
      userId = data.user!.id;
    }

    await admin.from("profiles").upsert({
      id: userId, user_id: userId, email: DEMO_EMAIL,
      nom_complet: "Compte Démonstration", username: DEMO_USERNAME,
      poste: "Démonstration (lecture seule)", actif: true,
    }, { onConflict: "id" });

    await admin.from("user_roles").upsert({ user_id: userId, role: "demo" }, { onConflict: "user_id,role" });

    return json({ success: true, username: DEMO_USERNAME, user_id: userId });
  } catch (e) {
    console.error("seed-demo-account error", e);
    return json({ error: "Erreur interne" }, 500);
  }
});