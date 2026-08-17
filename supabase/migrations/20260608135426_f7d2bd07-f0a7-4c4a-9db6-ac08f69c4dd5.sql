
-- ============ OFFRES : nouvelles colonnes ============
ALTER TABLE public.offres
  ADD COLUMN IF NOT EXISTS montant_cash_par_ha numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS montant_total_par_ha numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS montant_depot_initial_par_ha numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS duree_paiement_mois integer NOT NULL DEFAULT 34,
  ADD COLUMN IF NOT EXISTS gestion_type text NOT NULL DEFAULT 'propre',
  ADD COLUMN IF NOT EXISTS pourcentage_revenus_reverses integer NOT NULL DEFAULT 100,
  ADD COLUMN IF NOT EXISTS tranches_paiement jsonb NOT NULL DEFAULT '[]'::jsonb;

-- Seed/Upsert des 4 offres officielles du flyer (par hectare)
INSERT INTO public.offres
  (code, nom, description, type_offre, ordre, actif,
   montant_da_par_ha, contribution_mensuelle_par_ha,
   montant_cash_par_ha, montant_total_par_ha, montant_depot_initial_par_ha,
   duree_paiement_mois, duree_installation_mois, duree_production_ans,
   gestion_type, pourcentage_revenus_reverses, redevance_production_par_ha_an,
   tranches_paiement, avantages)
VALUES
  ('palm-invest','PalmInvest',
   'Plantation clé en main, sans terre préalable, remise après 36 mois — propriété 28 ans',
   'sans_terre',1,true,
   90700, 60000, 3890700, 4190700, 90700,
   34, 34, 25, 'propre', 100, 0,
   '[{"annee":1,"mois":12,"mensualite_par_ha":60000},{"annee":2,"mois":12,"mensualite_par_ha":120000},{"annee":3,"mois":10,"mensualite_par_ha":194000}]'::jsonb,
   '["100% Gestion propre","100% des revenus sur 25 ans","Plateforme digitale & rapports"]'::jsonb),
  ('palm-invest-plus','PalmInvest+',
   'Plantation clé en main, sans terre, gestion intégrale déléguée — propriété 28 ans',
   'sans_terre',2,true,
   90700, 60000, 3890700, 4190700, 90700,
   34, 34, 25, 'deleguee', 75, 0,
   '[{"annee":1,"mois":12,"mensualite_par_ha":60000},{"annee":2,"mois":12,"mensualite_par_ha":120000},{"annee":3,"mois":10,"mensualite_par_ha":194000}]'::jsonb,
   '["100% Gestion déléguée — tout inclus","75% des revenus reversés","Plateforme digitale & rapports"]'::jsonb),
  ('terra-palm','TerraPalm',
   'Vous avez la terre, nous en faisons une plantation productive en 36 mois — 100% propriété',
   'avec_terre',3,true,
   84700, 54000, 2294700, 2594700, 84700,
   34, 34, 25, 'propre', 100, 0,
   '[{"annee":1,"mois":12,"mensualite_par_ha":54000},{"annee":2,"mois":12,"mensualite_par_ha":75000},{"annee":3,"mois":10,"mensualite_par_ha":96200}]'::jsonb,
   '["100% Gestion propre","100% des revenus sur 25 ans","Plateforme digitale & rapports"]'::jsonb),
  ('terra-palm-plus','TerraPalm+',
   'Vous avez la terre, nous en faisons une plantation productive — gestion intégrale déléguée 28 ans',
   'avec_terre',4,true,
   84700, 54000, 2294700, 2594700, 84700,
   34, 34, 25, 'deleguee', 75, 0,
   '[{"annee":1,"mois":12,"mensualite_par_ha":54000},{"annee":2,"mois":12,"mensualite_par_ha":75000},{"annee":3,"mois":10,"mensualite_par_ha":96200}]'::jsonb,
   '["100% Gestion déléguée — tout inclus","75% des revenus reversés","Plateforme digitale & rapports"]'::jsonb)
ON CONFLICT (code) DO UPDATE SET
  nom = EXCLUDED.nom,
  description = EXCLUDED.description,
  type_offre = EXCLUDED.type_offre,
  ordre = EXCLUDED.ordre,
  actif = true,
  montant_da_par_ha = EXCLUDED.montant_da_par_ha,
  contribution_mensuelle_par_ha = EXCLUDED.contribution_mensuelle_par_ha,
  montant_cash_par_ha = EXCLUDED.montant_cash_par_ha,
  montant_total_par_ha = EXCLUDED.montant_total_par_ha,
  montant_depot_initial_par_ha = EXCLUDED.montant_depot_initial_par_ha,
  duree_paiement_mois = EXCLUDED.duree_paiement_mois,
  duree_installation_mois = EXCLUDED.duree_installation_mois,
  duree_production_ans = EXCLUDED.duree_production_ans,
  gestion_type = EXCLUDED.gestion_type,
  pourcentage_revenus_reverses = EXCLUDED.pourcentage_revenus_reverses,
  redevance_production_par_ha_an = 0,
  tranches_paiement = EXCLUDED.tranches_paiement,
  avantages = EXCLUDED.avantages,
  updated_at = now();

-- Désactive les anciennes offres non listées
UPDATE public.offres SET actif = false
  WHERE code NOT IN ('palm-invest','palm-invest-plus','terra-palm','terra-palm-plus');

-- ============ PROMOTIONS : enrichissement ============
ALTER TABLE public.promotions
  ADD COLUMN IF NOT EXISTS montant_fixe_reduction numeric,
  ADD COLUMN IF NOT EXISTS code text;

-- S'assurer que pourcentage est numeric (peut être int)
ALTER TABLE public.promotions ALTER COLUMN pourcentage_reduction TYPE numeric USING pourcentage_reduction::numeric;

-- cible déjà présente : forcer default + valeurs valides
ALTER TABLE public.promotions ALTER COLUMN cible SET DEFAULT 'depot_initial';
UPDATE public.promotions SET cible = 'depot_initial' WHERE cible IS NULL OR cible NOT IN ('depot_initial','total_contrat');
ALTER TABLE public.promotions ALTER COLUMN cible SET NOT NULL;

-- Index unique sur code (si non null)
CREATE UNIQUE INDEX IF NOT EXISTS promotions_code_uidx ON public.promotions(lower(code)) WHERE code IS NOT NULL;

-- Seed promo flyer
INSERT INTO public.promotions (nom, description, pourcentage_reduction, date_debut, date_fin, active, applique_toutes_offres, cible, code, type_promotion)
SELECT 'Promo Lancement -25%', 'Promotion de lancement: -25% sur le total contrat jusqu''au 30 juin 2026',
       25, '2026-01-01'::timestamptz, '2026-06-30 23:59:59'::timestamptz, true, true, 'total_contrat', 'LANCEMENT25', 'pourcentage'
WHERE NOT EXISTS (SELECT 1 FROM public.promotions WHERE lower(code) = 'lancement25');

-- ============ SOUSCRIPTEURS : ajustements 34 mois ============
ALTER TABLE public.souscripteurs
  ADD COLUMN IF NOT EXISTS promotion_id uuid REFERENCES public.promotions(id),
  ADD COLUMN IF NOT EXISTS montant_promo_applique numeric NOT NULL DEFAULT 0;

-- ============ RECOMPUTE TOTAUX (34 mois) ============
CREATE OR REPLACE FUNCTION public.recompute_contrat_totaux(_souscripteur_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_s RECORD; v_o RECORD;
  v_total numeric; v_jours_total int; v_taux numeric;
BEGIN
  SELECT * INTO v_s FROM public.souscripteurs WHERE id = _souscripteur_id;
  IF v_s IS NULL THEN RETURN; END IF;
  SELECT * INTO v_o FROM public.offres WHERE id = v_s.offre_id;
  IF v_o IS NULL THEN RETURN; END IF;

  v_total := COALESCE(v_o.montant_total_par_ha, 0) * COALESCE(v_s.total_hectares, 0)
             - COALESCE(v_s.montant_promo_applique, 0);
  v_jours_total := COALESCE(v_o.duree_paiement_mois, 34) * 30;
  v_taux := CASE WHEN v_jours_total > 0 AND COALESCE(v_s.total_hectares,0) > 0
                 THEN v_total / v_jours_total / v_s.total_hectares ELSE 0 END;

  UPDATE public.souscripteurs
    SET montant_total_contrat = v_total,
        jours_contrat_total = v_jours_total,
        taux_journalier_ha = v_taux
    WHERE id = _souscripteur_id;
END;
$$;

-- ============ HANDLE PAIEMENT VALIDE : 34 échéances depuis tranches_paiement ============
CREATE OR REPLACE FUNCTION public.handle_paiement_valide()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_s RECORD; v_o RECORD;
  v_debut date; v_tranche jsonb; v_idx int := 0; v_mois int;
  v_mensualite numeric; v_annee_offre int;
BEGIN
  IF NEW.statut <> 'valide' OR COALESCE(OLD.statut,'') = 'valide' THEN
    RETURN NEW;
  END IF;

  IF NEW.est_depot_initial = true THEN
    SELECT * INTO v_s FROM public.souscripteurs WHERE id = NEW.souscripteur_id;
    IF v_s IS NULL THEN RETURN NEW; END IF;
    SELECT * INTO v_o FROM public.offres WHERE id = v_s.offre_id;
    IF v_o IS NULL THEN RETURN NEW; END IF;

    v_debut := current_date;

    UPDATE public.souscripteurs SET
      compte_actif = true,
      da_paye_at = now(),
      contrat_debut_at = v_debut,
      contrat_fin_at = v_debut + (COALESCE(v_o.duree_paiement_mois,34) || ' months')::interval,
      phase_actuelle = 'annee_1',
      prochaine_echeance = v_debut + interval '1 month'
    WHERE id = NEW.souscripteur_id;

    PERFORM public.recompute_contrat_totaux(NEW.souscripteur_id);

    -- Génération des échéances depuis tranches_paiement
    IF NOT EXISTS (
      SELECT 1 FROM public.paiements
        WHERE souscripteur_id = NEW.souscripteur_id AND type_paiement = 'REDEVANCE'
    ) THEN
      FOR v_tranche IN SELECT * FROM jsonb_array_elements(COALESCE(v_o.tranches_paiement,'[]'::jsonb))
      LOOP
        v_annee_offre := (v_tranche->>'annee')::int;
        v_mensualite := (v_tranche->>'mensualite_par_ha')::numeric * COALESCE(v_s.total_hectares,0);
        FOR v_mois IN 1..((v_tranche->>'mois')::int) LOOP
          v_idx := v_idx + 1;
          INSERT INTO public.paiements(
            souscripteur_id, type_paiement, statut, montant, montant_theorique,
            numero_echeance, date_echeance, annee, phase
          ) VALUES (
            NEW.souscripteur_id, 'REDEVANCE', 'en_attente', v_mensualite, v_mensualite,
            v_idx, (v_debut + (v_idx || ' months')::interval)::date,
            EXTRACT(YEAR FROM v_debut + (v_idx || ' months')::interval)::int,
            'annee_' || v_annee_offre
          );
        END LOOP;
      END LOOP;
    END IF;

    IF v_s.user_id IS NOT NULL THEN
      INSERT INTO public.notifications(user_id, type, title, message, data)
      VALUES (v_s.user_id, 'compte', 'Compte activé',
        'Votre compte est activé. Votre contrat de 34 mois démarre aujourd''hui.',
        jsonb_build_object('debut', v_debut));
    END IF;

  ELSIF NEW.type_paiement = 'REDEVANCE' THEN
    UPDATE public.souscripteurs s SET
      prochaine_echeance = (
        SELECT MIN(date_echeance) FROM public.paiements
        WHERE souscripteur_id = s.id AND type_paiement = 'REDEVANCE' AND statut <> 'valide'
      ),
      phase_actuelle = CASE
        WHEN NOT EXISTS (
          SELECT 1 FROM public.paiements
            WHERE souscripteur_id = s.id AND type_paiement = 'REDEVANCE' AND statut <> 'valide'
        ) THEN 'termine_construction'
        ELSE s.phase_actuelle
      END
    WHERE id = NEW.souscripteur_id;
  END IF;

  RETURN NEW;
END;
$$;

-- (Re)attach trigger
DROP TRIGGER IF EXISTS trg_handle_paiement_valide ON public.paiements;
CREATE TRIGGER trg_handle_paiement_valide
  AFTER UPDATE ON public.paiements
  FOR EACH ROW EXECUTE FUNCTION public.handle_paiement_valide();

DROP TRIGGER IF EXISTS trg_check_docs_create_depot ON public.documents_souscription;
CREATE TRIGGER trg_check_docs_create_depot
  AFTER INSERT OR UPDATE ON public.documents_souscription
  FOR EACH ROW EXECUTE FUNCTION public.check_docs_and_create_depot();

DROP TRIGGER IF EXISTS trg_compute_jours_couverts ON public.paiements;
CREATE TRIGGER trg_compute_jours_couverts
  BEFORE UPDATE ON public.paiements
  FOR EACH ROW EXECUTE FUNCTION public.compute_paiement_jours_couverts();

-- ============ create_depot_initial : utilise montant_depot_initial_par_ha + promo ============
CREATE OR REPLACE FUNCTION public.create_depot_initial(_souscripteur_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_existing uuid; v_s RECORD; v_o RECORD; v_p RECORD;
  v_montant numeric; v_paiement_id uuid;
BEGIN
  SELECT id INTO v_existing FROM public.paiements
    WHERE souscripteur_id = _souscripteur_id AND est_depot_initial = true LIMIT 1;
  IF v_existing IS NOT NULL THEN RETURN v_existing; END IF;

  SELECT * INTO v_s FROM public.souscripteurs WHERE id = _souscripteur_id;
  IF v_s IS NULL THEN RAISE EXCEPTION 'Souscripteur introuvable'; END IF;

  SELECT * INTO v_o FROM public.offres WHERE id = v_s.offre_id;
  IF v_o IS NULL THEN RETURN NULL; END IF;

  v_montant := COALESCE(v_o.montant_depot_initial_par_ha, v_o.montant_da_par_ha, 0)
               * COALESCE(v_s.total_hectares, 0);

  -- Applique promo DI éventuelle
  IF v_s.promotion_id IS NOT NULL THEN
    SELECT * INTO v_p FROM public.promotions WHERE id = v_s.promotion_id;
    IF v_p IS NOT NULL AND v_p.cible = 'depot_initial' THEN
      IF COALESCE(v_p.montant_fixe_reduction,0) > 0 THEN
        v_montant := GREATEST(0, v_montant - v_p.montant_fixe_reduction);
      ELSIF COALESCE(v_p.pourcentage_reduction,0) > 0 THEN
        v_montant := v_montant - (v_montant * v_p.pourcentage_reduction / 100.0);
      END IF;
    END IF;
  END IF;

  IF v_montant <= 0 THEN RETURN NULL; END IF;

  INSERT INTO public.paiements(
    souscripteur_id, type_paiement, est_depot_initial, statut, montant, montant_theorique,
    date_echeance, notes
  ) VALUES (
    _souscripteur_id, 'DA', true, 'en_attente', v_montant, v_montant,
    (current_date + interval '7 days')::date,
    'Dépôt initial généré automatiquement après validation des documents'
  ) RETURNING id INTO v_paiement_id;

  IF v_s.user_id IS NOT NULL THEN
    INSERT INTO public.notifications(user_id, type, title, message, data)
    VALUES (v_s.user_id, 'paiement', 'Dépôt initial disponible',
      'Votre dépôt initial de ' || v_montant::text || ' FCFA est prêt.',
      jsonb_build_object('paiement_id', v_paiement_id, 'montant', v_montant));
  END IF;

  RETURN v_paiement_id;
END;
$$;

-- ============ Vue de synthèse 34 mois ============
DROP VIEW IF EXISTS public.v_souscripteur_synthese;
CREATE VIEW public.v_souscripteur_synthese
WITH (security_invoker = true) AS
SELECT
  s.id AS souscripteur_id,
  s.id_unique,
  s.nom_complet,
  s.offre_id,
  o.nom AS offre_nom,
  o.gestion_type,
  o.pourcentage_revenus_reverses,
  s.total_hectares,
  s.compte_actif,
  s.phase_actuelle,
  s.contrat_debut_at,
  s.contrat_fin_at,
  s.montant_total_contrat,
  s.taux_journalier_ha,
  s.prochaine_echeance,
  s.jours_retard,
  COALESCE(o.duree_paiement_mois, 34) AS duree_paiement_mois,
  (SELECT COUNT(*) FROM public.paiements p
     WHERE p.souscripteur_id = s.id AND p.type_paiement = 'REDEVANCE' AND p.statut = 'valide') AS mois_payes,
  (SELECT COUNT(*) FROM public.paiements p
     WHERE p.souscripteur_id = s.id AND p.type_paiement = 'REDEVANCE' AND p.statut <> 'valide') AS mois_restants,
  COALESCE((SELECT SUM(COALESCE(montant_paye, montant)) FROM public.paiements p
     WHERE p.souscripteur_id = s.id AND p.statut = 'valide'), 0) AS total_paye,
  GREATEST(0, COALESCE(s.montant_total_contrat,0) -
    COALESCE((SELECT SUM(COALESCE(montant_paye, montant)) FROM public.paiements p
       WHERE p.souscripteur_id = s.id AND p.statut = 'valide'), 0)
  ) AS reste_a_payer,
  CASE WHEN COALESCE(s.montant_total_contrat,0) > 0
       THEN ROUND(
         COALESCE((SELECT SUM(COALESCE(montant_paye, montant)) FROM public.paiements p
            WHERE p.souscripteur_id = s.id AND p.statut = 'valide'),0)
         * 100.0 / s.montant_total_contrat, 2)
       ELSE 0 END AS pourcentage_avancement
FROM public.souscripteurs s
LEFT JOIN public.offres o ON o.id = s.offre_id;

GRANT SELECT ON public.v_souscripteur_synthese TO authenticated;
GRANT SELECT ON public.v_souscripteur_synthese TO service_role;

-- Recompute pour tous les souscripteurs existants
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT id FROM public.souscripteurs WHERE offre_id IS NOT NULL LOOP
    PERFORM public.recompute_contrat_totaux(r.id);
  END LOOP;
END $$;
