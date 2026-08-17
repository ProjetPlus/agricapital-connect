import { useCallback, useEffect, useMemo, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import {
  AGRIPLAN_DEFAULT_CONFIG,
  AgriPlanConfig,
  AgriPlanTranche,
  buildAgriPlanEcheancier,
  computeAgriPlanTotaux,
  summarizeAgriPlan,
} from "@/lib/agriplan";

const CLE = {
  MISE_EN_PLACE: "agriplan_montant_mise_en_place",
  TRANCHES: "agriplan_tranches_mise_en_place",
  TRIMESTRE: "agriplan_montant_trimestre",
  NB_TRIMESTRES: "agriplan_nb_trimestres",
  DUREE_MOIS: "agriplan_duree_mois",
} as const;

function parseConfig(rows: Array<{ cle: string; valeur: string }>): AgriPlanConfig {
  const map = new Map(rows.map((r) => [r.cle, r.valeur]));
  const num = (cle: string, fallback: number) => {
    const v = Number(map.get(cle));
    return Number.isFinite(v) && v >= 0 ? v : fallback;
  };
  let tranches: AgriPlanTranche[] = AGRIPLAN_DEFAULT_CONFIG.tranchesMiseEnPlace;
  const raw = map.get(CLE.TRANCHES);
  if (raw) {
    try {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed) && parsed.length > 0) tranches = parsed as AgriPlanTranche[];
    } catch {
      /* repli */
    }
  }
  return {
    montantMiseEnPlace: num(CLE.MISE_EN_PLACE, AGRIPLAN_DEFAULT_CONFIG.montantMiseEnPlace),
    tranchesMiseEnPlace: tranches,
    montantTrimestre: num(CLE.TRIMESTRE, AGRIPLAN_DEFAULT_CONFIG.montantTrimestre),
    nbTrimestres: num(CLE.NB_TRIMESTRES, AGRIPLAN_DEFAULT_CONFIG.nbTrimestres),
    dureeMois: num(CLE.DUREE_MOIS, AGRIPLAN_DEFAULT_CONFIG.dureeMois),
  };
}

/**
 * Lit la configuration AgriPlan depuis `configurations_systeme` (catégorie `agriplan`)
 * avec repli sur AGRIPLAN_DEFAULT_CONFIG tant que la migration n'est pas exécutée.
 */
export function useAgriPlan(dateDebut?: string | Date) {
  const [config, setConfig] = useState<AgriPlanConfig>(AGRIPLAN_DEFAULT_CONFIG);
  const [loading, setLoading] = useState(true);
  const [fromDatabase, setFromDatabase] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from("configurations_systeme")
        .select("cle, valeur")
        .eq("categorie", "agriplan");
      if (error || !data || data.length === 0) {
        setConfig(AGRIPLAN_DEFAULT_CONFIG);
        setFromDatabase(false);
      } else {
        setConfig(parseConfig(data as Array<{ cle: string; valeur: string }>));
        setFromDatabase(true);
      }
    } catch {
      setConfig(AGRIPLAN_DEFAULT_CONFIG);
      setFromDatabase(false);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const totaux = useMemo(() => computeAgriPlanTotaux(config), [config]);
  const echeancier = useMemo(
    () => buildAgriPlanEcheancier(config, dateDebut ?? new Date()),
    [config, dateDebut],
  );
  const synthese = useMemo(() => summarizeAgriPlan(echeancier), [echeancier]);

  /** Enregistre la configuration (réservé aux rôles autorisés par la RLS) */
  const save = useCallback(async (next: AgriPlanConfig) => {
    const rows = [
      { cle: CLE.MISE_EN_PLACE, valeur: String(next.montantMiseEnPlace), type_valeur: "number" },
      { cle: CLE.TRANCHES, valeur: JSON.stringify(next.tranchesMiseEnPlace), type_valeur: "json" },
      { cle: CLE.TRIMESTRE, valeur: String(next.montantTrimestre), type_valeur: "number" },
      { cle: CLE.NB_TRIMESTRES, valeur: String(next.nbTrimestres), type_valeur: "number" },
      { cle: CLE.DUREE_MOIS, valeur: String(next.dureeMois), type_valeur: "number" },
    ].map((r) => ({ ...r, categorie: "agriplan", modifiable: true }));

    const { error } = await (supabase as any)
      .from("configurations_systeme")
      .upsert(rows, { onConflict: "cle" });
    if (!error) setConfig(next);
    return { error };
  }, []);

  return { config, setConfig, totaux, echeancier, synthese, loading, fromDatabase, reload: load, save };
}

export default useAgriPlan;
