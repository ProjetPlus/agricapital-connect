import { createClient } from "https://esm.sh/@supabase/supabase-js@2.75.0";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-internal-secret, x-cron-secret, x-api-key",
};

export const json = (p: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(p), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  });

export const adminClient = () =>
  createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    { auth: { autoRefreshToken: false, persistSession: false } },
  );

/** Vérifie le JWT du caller. Retourne l'utilisateur ou null. */
export async function getCaller(req: Request, admin: any) {
  const token = (req.headers.get("Authorization") ?? "").replace("Bearer ", "").trim();
  if (!token) return null;
  const { data } = await admin.auth.getUser(token);
  return data?.user ?? null;
}

/** Exige un caller authentifié administrateur. Retourne une Response en cas d'échec. */
export async function requireAdmin(req: Request, admin: any) {
  const user = await getCaller(req, admin);
  if (!user) return { user: null, error: json({ error: "Non authentifié" }, 401) };
  const { data: isAdmin } = await admin.rpc("is_admin", { _user_id: user.id });
  if (!isAdmin) return { user, error: json({ error: "Accès réservé aux administrateurs" }, 403) };
  return { user, error: null as Response | null };
}

/** Exige un caller authentifié (n'importe quel utilisateur connecté). */
export async function requireUser(req: Request, admin: any) {
  const user = await getCaller(req, admin);
  if (!user) return { user: null, error: json({ error: "Non authentifié" }, 401) };
  return { user, error: null as Response | null };
}

/** Compare un header secret partagé (fail-closed si le secret n'est pas configuré). */
export function checkSharedSecret(req: Request, headerName: string, envName: string) {
  const expected = Deno.env.get(envName);
  if (!expected) return false;
  const provided = req.headers.get(headerName);
  return !!provided && provided === expected;
}
