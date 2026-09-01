import { corsHeaders } from "npm:@supabase/supabase-js@2/cors";
import { createClient } from "npm:@supabase/supabase-js@2";

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Méthode refusée" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const password = Deno.env.get("ADMIN_RECOVERY_PASSWORD");
  if (!url || !serviceRoleKey || !password) return json({ error: "Configuration indisponible" }, 500);

  const admin = createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
  if (error) return json({ error: "Recherche du compte impossible" }, 500);

  const user = data.users.find((candidate) => candidate.email?.toLowerCase() === "admin@agricapital.ci");
  if (!user) return json({ error: "Compte administrateur introuvable" }, 404);

  const { error: updateError } = await admin.auth.admin.updateUserById(user.id, {
    password,
    email_confirm: true,
    ban_duration: "none",
  });
  if (updateError) return json({ error: "Réinitialisation impossible" }, 500);

  return json({ success: true });
});