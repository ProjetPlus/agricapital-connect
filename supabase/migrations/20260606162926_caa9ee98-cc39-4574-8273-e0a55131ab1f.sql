
-- =========================================================
-- 1. SOUSCRIPTEURS — colonnes de cycle de vie
-- =========================================================
ALTER TABLE public.souscripteurs
  ADD COLUMN IF NOT EXISTS documents_valides_at timestamptz,
  ADD COLUMN IF NOT EXISTS compte_actif boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS da_paye_at timestamptz,
  ADD COLUMN IF NOT EXISTS contrat_debut_at date,
  ADD COLUMN IF NOT EXISTS contrat_fin_at date,
  ADD COLUMN IF NOT EXISTS mensualite_montant numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS prochaine_echeance date;

-- =========================================================
-- 2. PAIEMENTS — flag dépôt initial + numéro d'échéance
-- =========================================================
ALTER TABLE public.paiements
  ADD COLUMN IF NOT EXISTS est_depot_initial boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS numero_echeance integer;

CREATE UNIQUE INDEX IF NOT EXISTS uq_paiement_depot_initial
  ON public.paiements(souscripteur_id)
  WHERE est_depot_initial = true;

-- =========================================================
-- 3. FUNCTION: create_depot_initial
-- =========================================================
CREATE OR REPLACE FUNCTION public.create_depot_initial(_souscripteur_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing uuid;
  v_souscripteur RECORD;
  v_offre RECORD;
  v_montant numeric;
  v_paiement_id uuid;
BEGIN
  SELECT id INTO v_existing FROM public.paiements
    WHERE souscripteur_id = _souscripteur_id AND est_depot_initial = true LIMIT 1;
  IF v_existing IS NOT NULL THEN RETURN v_existing; END IF;

  SELECT * INTO v_souscripteur FROM public.souscripteurs WHERE id = _souscripteur_id;
  IF v_souscripteur IS NULL THEN RAISE EXCEPTION 'Souscripteur introuvable'; END IF;

  SELECT * INTO v_offre FROM public.offres WHERE id = v_souscripteur.offre_id;
  IF v_offre IS NULL THEN RETURN NULL; END IF;

  v_montant := COALESCE(v_offre.montant_da_par_ha, 0) * COALESCE(v_souscripteur.total_hectares, 0);
  IF v_montant <= 0 THEN RETURN NULL; END IF;

  INSERT INTO public.paiements(
    souscripteur_id, type_paiement, est_depot_initial, statut, montant, montant_theorique,
    date_echeance, notes
  ) VALUES (
    _souscripteur_id, 'DA', true, 'en_attente', v_montant, v_montant,
    (current_date + interval '7 days')::date,
    'Dépôt initial généré automatiquement après validation des documents'
  ) RETURNING id INTO v_paiement_id;

  -- Notif souscripteur
  IF v_souscripteur.user_id IS NOT NULL THEN
    INSERT INTO public.notifications(user_id, type, title, message, data)
    VALUES (v_souscripteur.user_id, 'paiement',
      'Dépôt initial disponible',
      'Votre dépôt initial de ' || v_montant::text || ' FCFA est prêt. Payez-le pour activer votre compte.',
      jsonb_build_object('paiement_id', v_paiement_id, 'montant', v_montant));
  END IF;

  RETURN v_paiement_id;
END;
$$;

-- =========================================================
-- 4. TRIGGER: validation documents → dépôt initial
-- =========================================================
CREATE OR REPLACE FUNCTION public.check_docs_and_create_depot()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sid uuid;
  v_total int;
  v_valides int;
BEGIN
  v_sid := COALESCE(NEW.souscripteur_id, OLD.souscripteur_id);
  IF v_sid IS NULL THEN RETURN NEW; END IF;

  SELECT COUNT(*), COUNT(*) FILTER (WHERE statut = 'valide')
    INTO v_total, v_valides
    FROM public.documents_souscription WHERE souscripteur_id = v_sid;

  IF v_total >= 1 AND v_total = v_valides THEN
    UPDATE public.souscripteurs
      SET documents_valides_at = COALESCE(documents_valides_at, now())
      WHERE id = v_sid AND documents_valides_at IS NULL;
    PERFORM public.create_depot_initial(v_sid);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_docs_souscription ON public.documents_souscription;
CREATE TRIGGER trg_check_docs_souscription
AFTER INSERT OR UPDATE OF statut ON public.documents_souscription
FOR EACH ROW EXECUTE FUNCTION public.check_docs_and_create_depot();

-- =========================================================
-- 5. TRIGGER: paiement validé → débloque compte + 36 échéances
-- =========================================================
CREATE OR REPLACE FUNCTION public.handle_paiement_valide()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_souscripteur RECORD;
  v_offre RECORD;
  v_mensualite numeric;
  v_debut date;
  i int;
BEGIN
  IF NEW.statut <> 'valide' OR COALESCE(OLD.statut,'') = 'valide' THEN
    RETURN NEW;
  END IF;

  -- ===== Dépôt initial =====
  IF NEW.est_depot_initial = true THEN
    SELECT * INTO v_souscripteur FROM public.souscripteurs WHERE id = NEW.souscripteur_id;
    IF v_souscripteur IS NULL THEN RETURN NEW; END IF;

    SELECT * INTO v_offre FROM public.offres WHERE id = v_souscripteur.offre_id;
    v_mensualite := COALESCE(v_offre.contribution_mensuelle_par_ha, 0) * COALESCE(v_souscripteur.total_hectares, 0);
    v_debut := current_date;

    UPDATE public.souscripteurs SET
      compte_actif = true,
      da_paye_at = now(),
      contrat_debut_at = v_debut,
      contrat_fin_at = v_debut + interval '36 months',
      mensualite_montant = v_mensualite,
      prochaine_echeance = v_debut + interval '1 month'
    WHERE id = NEW.souscripteur_id;

    -- Génère 36 échéances si pas déjà créées
    IF v_mensualite > 0 AND NOT EXISTS (
      SELECT 1 FROM public.paiements
      WHERE souscripteur_id = NEW.souscripteur_id AND type_paiement = 'REDEVANCE'
    ) THEN
      FOR i IN 1..36 LOOP
        INSERT INTO public.paiements(
          souscripteur_id, type_paiement, statut, montant, montant_theorique,
          numero_echeance, date_echeance, annee
        ) VALUES (
          NEW.souscripteur_id, 'REDEVANCE', 'en_attente', v_mensualite, v_mensualite,
          i, (v_debut + (i || ' months')::interval)::date,
          EXTRACT(YEAR FROM v_debut + (i || ' months')::interval)::int
        );
      END LOOP;
    END IF;

    -- Notif activation
    IF v_souscripteur.user_id IS NOT NULL THEN
      INSERT INTO public.notifications(user_id, type, title, message, data)
      VALUES (v_souscripteur.user_id, 'compte',
        'Compte activé',
        'Votre compte est activé. Votre contrat de 36 mois démarre aujourd''hui.',
        jsonb_build_object('debut', v_debut, 'fin', v_debut + interval '36 months'));
    END IF;

    -- Notif staff
    PERFORM public.notify_hierarchy('paiement', 'Dépôt initial encaissé',
      'Souscripteur ' || v_souscripteur.id_unique || ' — compte activé',
      jsonb_build_object('souscripteur_id', NEW.souscripteur_id));

  -- ===== Redevance mensuelle =====
  ELSIF NEW.type_paiement = 'REDEVANCE' THEN
    UPDATE public.souscripteurs s SET
      prochaine_echeance = (
        SELECT MIN(date_echeance) FROM public.paiements
        WHERE souscripteur_id = s.id AND type_paiement = 'REDEVANCE' AND statut <> 'valide'
      )
    WHERE id = NEW.souscripteur_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_handle_paiement_valide ON public.paiements;
CREATE TRIGGER trg_handle_paiement_valide
AFTER UPDATE OF statut ON public.paiements
FOR EACH ROW EXECUTE FUNCTION public.handle_paiement_valide();

-- =========================================================
-- 6. VUE: synthèse souscripteur (Dashboard + Portail)
-- =========================================================
CREATE OR REPLACE VIEW public.v_souscripteur_synthese AS
SELECT
  s.id,
  s.id_unique,
  s.nom_complet,
  s.compte_actif,
  s.contrat_debut_at,
  s.contrat_fin_at,
  s.mensualite_montant,
  s.prochaine_echeance,
  COALESCE((SELECT SUM(montant_paye) FROM public.paiements
            WHERE souscripteur_id = s.id AND statut = 'valide'), 0) AS total_paye,
  COALESCE((SELECT SUM(montant_theorique) FROM public.paiements
            WHERE souscripteur_id = s.id AND statut <> 'valide'), 0) AS restant_du,
  (SELECT COUNT(*) FROM public.paiements
   WHERE souscripteur_id = s.id AND type_paiement = 'REDEVANCE' AND statut = 'valide') AS echeances_payees,
  CASE WHEN s.contrat_debut_at IS NOT NULL
       THEN GREATEST(0, (s.contrat_fin_at - current_date))
       ELSE NULL END AS jours_restants,
  CASE WHEN s.contrat_debut_at IS NOT NULL
       THEN ROUND(((current_date - s.contrat_debut_at)::numeric
                  / NULLIF((s.contrat_fin_at - s.contrat_debut_at), 0)::numeric) * 100, 2)
       ELSE 0 END AS avancement_pct
FROM public.souscripteurs s;

GRANT SELECT ON public.v_souscripteur_synthese TO authenticated, service_role;

-- =========================================================
-- 7. Realtime replication
-- =========================================================
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'paiements','souscripteurs','plantations','commissions',
    'portefeuilles','notifications','documents_souscription'
  ] LOOP
    BEGIN
      EXECUTE format('ALTER TABLE public.%I REPLICA IDENTITY FULL', t);
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    EXCEPTION WHEN duplicate_object THEN NULL;
             WHEN others THEN NULL;
    END;
  END LOOP;
END $$;
