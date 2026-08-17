import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.75.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (p: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(p), { headers: { ...corsHeaders, "Content-Type": "application/json" }, status });

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  let step = "init";
  try {
    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    step = "auth_caller";
    const token = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
    if (!token) return json({ error: "Non authentifié", step }, 401);
    const { data: caller } = await admin.auth.getUser(token);
    if (!caller?.user) return json({ error: "Session invalide", step }, 401);
    const { data: isAdmin } = await admin.rpc("is_admin", { _user_id: caller.user.id });
    if (!isAdmin) return json({ error: "Accès réservé aux super administrateurs", step }, 403);

    step = "parse_body";
    const { action, user_id, password, username, roles } = await req.json();
    if (!action || !user_id) return json({ error: "action et user_id requis", step }, 400);

    if (action === "set_password") {
      step = "set_password";
      if (!password || String(password).length < 8) {
        return json({ error: "Mot de passe : 8 caractères minimum", step }, 400);
      }
      const { error } = await admin.auth.admin.updateUserById(user_id, { password: String(password) });
      if (error) return json({ error: error.message, step }, 400);
      return json({ success: true, action });
    }

    if (action === "set_username") {
      step = "set_username";
      const clean = String(username ?? "").trim().toLowerCase();
      if (!/^[a-zA-Z0-9._-]{3,30}$/.test(clean)) {
        return json({ error: "Identifiant invalide (3 à 30 caractères : lettres, chiffres, . _ -)", step }, 400);
      }
      const { data: taken } = await admin
        .from("profiles").select("id").eq("username", clean).neq("id", user_id).maybeSingle();
      if (taken) return json({ error: "Cet identifiant est déjà utilisé", step }, 409);
      const { error } = await admin.from("profiles").update({ username: clean }).eq("id", user_id);
      if (error) return json({ error: error.message, step }, 400);
      return json({ success: true, action, username: clean });
    }

    if (action === "set_roles") {
      step = "set_roles";
      const list: string[] = Array.isArray(roles) ? roles.filter(Boolean) : [];
      if (list.length === 0) return json({ error: "Au moins un rôle est requis", step }, 400);
      step = "delete_old_roles";
      const { error: delErr } = await admin.from("user_roles").delete().eq("user_id", user_id);
      if (delErr) return json({ error: delErr.message, step }, 400);
      step = "insert_roles";
      const { error: insErr } = await admin
        .from("user_roles")
        .upsert(list.map((r) => ({ user_id, role: r })), { onConflict: "user_id,role" });
      if (insErr) return json({ error: insErr.message, step }, 400);
      step = "verify_roles";
      const { data: check } = await admin.from("user_roles").select("role").eq("user_id", user_id);
      await admin.from("profiles").update({ actif: true }).eq("id", user_id);
      return json({ success: true, action, roles: (check ?? []).map((r: any) => r.role) });
    }

    if (action === "delete_user") {
      step = "delete_user";
      if (user_id === caller.user.id) {
        return json({ error: "Impossible de supprimer votre propre compte", step }, 400);
      }
      await admin.from("user_roles").delete().eq("user_id", user_id);
      await admin.from("account_requests").delete().eq("auth_user_id", user_id);
      await admin.from("profiles").delete().eq("id", user_id);
      const { error } = await admin.auth.admin.deleteUser(user_id);
      if (error) return json({ error: error.message, step }, 400);
      return json({ success: true, action });
    }

    return json({ error: `Action inconnue: ${action}`, step }, 400);
  } catch (e) {
    console.error("admin-manage-user error", step, e);
    return json({ error: (e as Error).message, step }, 500);
  }
});
