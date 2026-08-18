import { useEffect, useMemo, useState } from "react";
import { supabase } from "@/integrations/supabase/client";

export interface GeoItem {
  id: string;
  nom: string;
}

/**
 * Listes géographiques officielles du système (régions / sous-préfectures)
 * utilisées par les formulaires AgriPlan.
 */
export function useAgriPlanGeo() {
  const [regions, setRegions] = useState<GeoItem[]>([]);
  const [departements, setDepartements] = useState<Array<GeoItem & { region_id: string | null }>>([]);
  const [sousPrefectures, setSousPrefectures] = useState<Array<GeoItem & { departement_id: string | null }>>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      const [r, d, sp] = await Promise.all([
        supabase.from("regions").select("id, nom").eq("est_active", true).order("nom"),
        supabase.from("departements").select("id, nom, region_id").order("nom"),
        supabase.from("sous_prefectures").select("id, nom, departement_id").eq("est_active", true).order("nom"),
      ]);
      setRegions((r.data || []) as GeoItem[]);
      setDepartements((d.data || []) as Array<GeoItem & { region_id: string | null }>);
      setSousPrefectures((sp.data || []) as Array<GeoItem & { departement_id: string | null }>);
      setLoading(false);
    })();
  }, []);

  const spByRegion = useMemo(() => {
    return (regionId?: string | null) => {
      if (!regionId) return sousPrefectures;
      const deps = departements.filter((d) => d.region_id === regionId).map((d) => d.id);
      const filtered = sousPrefectures.filter((s) => s.departement_id && deps.includes(s.departement_id));
      return filtered.length ? filtered : sousPrefectures;
    };
  }, [departements, sousPrefectures]);

  const nomRegion = (id?: string | null) => regions.find((r) => r.id === id)?.nom || "—";
  const nomSousPrefecture = (id?: string | null) => sousPrefectures.find((s) => s.id === id)?.nom || "—";

  return { regions, sousPrefectures, spByRegion, nomRegion, nomSousPrefecture, loading };
}

export default useAgriPlanGeo;
