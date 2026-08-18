import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { AGRIPLAN_OFFRE_FALLBACK, AgriPlanOffre, AgriPlanTranche } from "@/lib/agriplan";

/**
 * Configuration commerciale unique de l'offre AgriPlan (`agriplan_offre`).
 * Modifiable depuis Paramètres → Offres → AgriPlan.
 */
export function useAgriPlanOffre() {
  const [offre, setOffre] = useState<AgriPlanOffre>(AGRIPLAN_OFFRE_FALLBACK);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    const { data } = await supabase
      .from("agriplan_offre")
      .select("*")
      .eq("code", "agriplan")
      .maybeSingle();
    if (data) {
      setOffre({
        ...(data as unknown as AgriPlanOffre),
        tranches: (Array.isArray(data.tranches) ? data.tranches : []) as unknown as AgriPlanTranche[],
      });
    }
    setLoading(false);
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const save = useCallback(async (next: AgriPlanOffre) => {
    setSaving(true);
    const { error } = await supabase
      .from("agriplan_offre")
      .update({
        nom: next.nom,
        description: next.description,
        prix_total: next.prix_total,
        montant_mise_en_place: next.montant_mise_en_place,
        montant_accompagnement_periode: next.montant_accompagnement_periode,
        periodicite_accompagnement: next.periodicite_accompagnement,
        nb_periodes_accompagnement: next.nb_periodes_accompagnement,
        duree_mois: next.duree_mois,
        tranches: next.tranches as never,
        actif: next.actif,
      })
      .eq("code", "agriplan");
    if (!error) setOffre(next);
    setSaving(false);
    return { error };
  }, []);

  return { offre, setOffre, loading, saving, reload: load, save };
}

export default useAgriPlanOffre;
