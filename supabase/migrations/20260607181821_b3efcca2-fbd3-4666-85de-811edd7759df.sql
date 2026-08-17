
-- =========================================================
-- 1. OFFRES — durées + redevance production
-- =========================================================
ALTER TABLE public.offres
  ADD COLUMN IF NOT EXISTS duree_installation_mois integer NOT NULL DEFAULT 36,
  ADD COLUMN IF NOT EXISTS duree_production_ans integer NOT NULL DEFAULT 25,
  ADD COLUMN IF NOT EXISTS redevance_production_par_ha_an numeric NOT NULL DEFAULT 0;

-- =========================================================
-- 2. SOUSCRIPTEURS — cycle 28 ans, jours, phase
-- =========================================================
ALTER TABLE public.souscripteurs
  ADD COLUMN IF NOT EXISTS phase_actuelle text NOT NULL DEFAULT 'pre_activation',
  ADD COLUMN IF NOT EXISTS jours_contrat_total integer NOT NULL DEFAULT 10220, -- 28*365
  ADD COLUMN IF NOT EXISTS jours_payes integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS jours_retard integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS taux_journalier_ha numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS montant_total_contrat numeric NOT NULL DEFAULT 0;

-- =========================================================
-- 3. PAIEMENTS — fractionnement + retard
-- =========================================================
ALTER TABLE public.paiements
  ADD COLUMN IF NOT EXISTS jours_couverts integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS periode_debut date,
  ADD COLUMN IF NOT EXISTS periode_fin date,
  ADD COLUMN IF NOT EXISTS phase text,
  ADD COLUMN IF NOT EXISTS jours_retard integer NOT NULL DEFAULT 0;

-- =========================================================
-- 4. PROMOTIONS — cible explicite
-- =========================================================
ALTER TABLE public.promotions
  ADD COLUMN IF NOT EXISTS cible text NOT NULL DEFAULT 'depot_initial';

UPDATE public.promotions SET cible =
  CASE WHEN type_promotion IN ('cout_global','total','total_contrat') THEN 'total_contrat'
       ELSE 'depot_initial' END
WHERE cible IS NULL OR cible = 'depot_initial';

ALTER TABLE public.promotions
  DROP CONSTRAINT IF EXISTS promotions_cible_check;
ALTER TABLE public.promotions
  ADD CONSTRAINT promotions_cible_check CHECK (cible IN ('depot_initial','total_contrat'));

-- =========================================================
-- 5. FONCTION : recalcul du contrat (montant total, taux journalier)
-- =========================================================
CREATE OR REPLACE FUNCTION public.recompute_contrat_totaux(_souscripteur_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_s RECORD;
  v_o RECORD;
  v_mois_inst int;
  v_ans_prod int;
  v_total numeric;
  v_jours_total int;
  v_taux numeric;
BEGIN
  SELECT * INTO v_s FROM public.souscripteurs WHERE id = _souscripteur_id;
  IF v_s IS NULL THEN RETURN; END IF;
  SELECT * INTO v_o FROM public.offres WHERE id = v_s.offre_id;
  IF v_o IS NULL THEN RETURN; END IF;

  v_mois_inst := COALESCE(v_o.duree_installation_mois, 36);
  v_ans_prod := COALESCE(v_o.duree_production_ans, 25);
  v_jours_total := (v_mois_inst * 30) + (v_ans_prod * 365);

  v_total :=
      (COALESCE(v_o.montant_da_par_ha,0) * COALESCE(v_s.total_hectares,0))
    + (COALESCE(v_o.contribution_mensuelle_par_ha,0) * v_mois_inst * COALESCE(v_s.total_hectares,0))
    + (COALESCE(v_o.redevance_production_par_ha_an,0) * v_ans_prod * COALESCE(v_s.total_hectares,0));

  v_taux := CASE WHEN v_jours_total > 0 AND COALESCE(v_s.total_hectares,0) > 0
                 THEN v_total / v_jours_total / v_s.total_hectares
                 ELSE 0 END;

  UPDATE public.souscripteurs
    SET montant_total_contrat = v_total,
        jours_contrat_total = v_jours_total,
        taux_journalier_ha = v_taux
    WHERE id = _souscripteur_id;
END;
$$;

-- =========================================================
-- 6. TRIGGER : calcul jours couverts à la validation
-- =========================================================
CREATE OR REPLACE FUNCTION public.compute_paiement_jours_couverts()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_s RECORD;
  v_taux numeric;
  v_jours int;
  v_debut date;
  v_phase text;
BEGIN
  IF NEW.statut <> 'valide' OR COALESCE(OLD.statut,'') = 'valide' THEN
    RETURN NEW;
  END IF;
  IF NEW.souscripteur_id IS NULL THEN RETURN NEW; END IF;

  SELECT * INTO v_s FROM public.souscripteurs WHERE id = NEW.souscripteur_id;
  IF v_s IS NULL THEN RETURN NEW; END IF;

  v_taux := COALESCE(v_s.taux_journalier_ha, 0) * COALESCE(v_s.total_hectares, 0);
  IF v_taux > 0 AND NEW.est_depot_initial = false THEN
    v_jours := floor(COALESCE(NEW.montant_paye, NEW.montant, 0) / v_taux);
    NEW.jours_couverts := v_jours;
    v_debut := COALESCE(v_s.contrat_debut_at, current_date) + (COALESCE(v_s.jours_payes,0) || ' days')::interval;
    NEW.periode_debut := v_debut::date;
    NEW.periode_fin := (v_debut + (v_jours || ' days')::interval - interval '1 day')::date;

    IF v_s.contrat_debut_at IS NOT NULL AND
       (current_date - v_s.contrat_debut_at) < (COALESCE((SELECT duree_installation_mois FROM offres WHERE id = v_s.offre_id), 36) * 30)
    THEN v_phase := 'installation'; ELSE v_phase := 'production'; END IF;
    NEW.phase := v_phase;

    UPDATE public.souscripteurs
      SET jours_payes = COALESCE(jours_payes,0) + v_jours,
          phase_actuelle = v_phase
      WHERE id = NEW.souscripteur_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_compute_paiement_jours_couverts ON public.paiements;
CREATE TRIGGER trg_compute_paiement_jours_couverts
  BEFORE UPDATE ON public.paiements
  FOR EACH ROW
  EXECUTE FUNCTION public.compute_paiement_jours_couverts();

-- =========================================================
-- 7. FONCTION publique : simulation paiement fractionné
-- =========================================================
CREATE OR REPLACE FUNCTION public.simuler_paiement_fractionne(
  _souscripteur_id uuid, _montant numeric
) RETURNS TABLE(jours_couverts int, periode_debut date, periode_fin date, phase text, taux_journalier numeric)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_s RECORD; v_taux numeric; v_jours int; v_debut date; v_phase text;
BEGIN
  SELECT * INTO v_s FROM public.souscripteurs WHERE id = _souscripteur_id;
  IF v_s IS NULL THEN RETURN; END IF;
  v_taux := COALESCE(v_s.taux_journalier_ha,0) * COALESCE(v_s.total_hectares,0);
  IF v_taux <= 0 THEN RETURN; END IF;
  v_jours := floor(_montant / v_taux);
  v_debut := COALESCE(v_s.contrat_debut_at, current_date) + (COALESCE(v_s.jours_payes,0) || ' days')::interval;
  v_phase := COALESCE(v_s.phase_actuelle,'installation');
  RETURN QUERY SELECT v_jours, v_debut::date,
    (v_debut + (v_jours || ' days')::interval - interval '1 day')::date,
    v_phase, v_taux;
END;
$$;
GRANT EXECUTE ON FUNCTION public.simuler_paiement_fractionne(uuid, numeric) TO authenticated, service_role;

-- =========================================================
-- 8. JOB : marquer paiements en retard
-- =========================================================
CREATE OR REPLACE FUNCTION public.mark_overdue_payments()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.paiements
    SET statut = 'en_retard',
        jours_retard = GREATEST(0, (current_date - date_echeance))
    WHERE statut = 'en_attente'
      AND date_echeance IS NOT NULL
      AND date_echeance < current_date;

  UPDATE public.souscripteurs s
    SET jours_retard = COALESCE((
      SELECT MAX(GREATEST(0, current_date - p.date_echeance))
        FROM public.paiements p
        WHERE p.souscripteur_id = s.id
          AND p.statut IN ('en_attente','en_retard','partiel')
          AND p.date_echeance IS NOT NULL
    ), 0);
END;
$$;
REVOKE ALL ON FUNCTION public.mark_overdue_payments() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_overdue_payments() TO service_role;

-- =========================================================
-- 9. VUE v_souscripteur_synthese — version étendue
-- =========================================================
DROP VIEW IF EXISTS public.v_souscripteur_synthese CASCADE;
CREATE VIEW public.v_souscripteur_synthese
WITH (security_invoker = true) AS
SELECT
  s.id,
  s.id_unique,
  s.nom_complet,
  s.user_id,
  s.compte_actif,
  s.phase_actuelle,
  s.total_hectares,
  s.contrat_debut_at,
  s.contrat_fin_at,
  s.mensualite_montant,
  s.prochaine_echeance,
  s.jours_contrat_total,
  s.jours_payes,
  s.jours_retard,
  s.taux_journalier_ha,
  s.montant_total_contrat,
  GREATEST(0, s.jours_contrat_total - COALESCE(s.jours_payes,0)) AS jours_restants,
  COALESCE((SELECT SUM(montant_paye) FROM paiements p WHERE p.souscripteur_id = s.id AND p.statut='valide'),0) AS total_paye,
  GREATEST(0, s.montant_total_contrat - COALESCE((SELECT SUM(montant_paye) FROM paiements p WHERE p.souscripteur_id = s.id AND p.statut='valide'),0)) AS restant_du,
  (SELECT COUNT(*) FROM paiements p WHERE p.souscripteur_id = s.id AND p.statut='valide')::bigint AS echeances_payees,
  (SELECT COUNT(*) FROM paiements p WHERE p.souscripteur_id = s.id AND p.statut IN ('en_attente','en_retard','partiel') AND p.date_echeance < current_date)::bigint AS echeances_en_retard,
  CASE WHEN s.montant_total_contrat > 0
    THEN ROUND(100.0 * COALESCE((SELECT SUM(montant_paye) FROM paiements p WHERE p.souscripteur_id = s.id AND p.statut='valide'),0) / s.montant_total_contrat, 2)
    ELSE 0 END AS avancement_pct
FROM public.souscripteurs s;

GRANT SELECT ON public.v_souscripteur_synthese TO authenticated, service_role;
