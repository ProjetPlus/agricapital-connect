import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { adminClient, corsHeaders, json } from "../_shared/auth.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });

  try {
    const { username } = await req.json();
    const clean = typeof username === "string" ? username.trim().toLowerCase() : "";
    if (!clean || clean.length < 3 || clean.length > 64 || !/^[a-z0-9._-]+$/.test(clean)) {
      return json({ error: "Identifiant invalide" }, 400);
    }

    const admin = adminClient();
    const { data, error } = await admin.rpc("resolve_username_email", { _username: clean });
    if (error) {
      console.error("resolve_username_email:", error.message);
      return json({ error: "Nom d'utilisateur introuvable" }, 404);
    }
    if (!data) return json({ error: "Nom d'utilisateur introuvable" }, 404);

    return json({ email: data as string });
  } catch (_e) {
    return json({ error: "Requête invalide" }, 400);
  }
});
