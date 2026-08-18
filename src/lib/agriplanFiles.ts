import { supabase } from "@/integrations/supabase/client";
import { AGRIPLAN_BUCKET } from "@/lib/agriplan";

const slug = (s: string) =>
  s.normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-zA-Z0-9._-]+/g, "-").toLowerCase();

/** Upload d'un fichier AgriPlan : agriplan/<client_id>/<categorie>/<fichier> */
export async function uploadAgriPlanFile(
  clientId: string,
  categorie: string,
  file: File,
): Promise<{ path: string | null; error: Error | null }> {
  const path = `${clientId}/${categorie}/${Date.now()}-${slug(file.name)}`;
  const { error } = await supabase.storage
    .from(AGRIPLAN_BUCKET)
    .upload(path, file, { upsert: false, contentType: file.type || undefined });
  if (error) return { path: null, error: error as unknown as Error };
  return { path, error: null };
}

/** Lien temporaire de consultation d'un fichier AgriPlan */
export async function agriPlanFileUrl(path?: string | null, seconds = 3600): Promise<string | null> {
  if (!path) return null;
  const { data } = await supabase.storage.from(AGRIPLAN_BUCKET).createSignedUrl(path, seconds);
  return data?.signedUrl || null;
}

export async function openAgriPlanFile(path?: string | null) {
  const url = await agriPlanFileUrl(path);
  if (url) window.open(url, "_blank", "noopener");
}
