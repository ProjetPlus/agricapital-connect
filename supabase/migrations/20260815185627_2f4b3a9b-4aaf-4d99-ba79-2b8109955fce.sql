-- =====================================================================
-- 1. MIGRATION TERMINOLOGIQUE DA -> DI
-- =====================================================================
UPDATE public.paiements SET type_paiement = 'DI' WHERE type_paiement = 'DA';
UPDATE public.plantations SET statut_global = 'en_attente_di' WHERE statut_global = 'en_attente_da';
UPDATE public.plantations SET statut_global = 'di_valide' WHERE statut_global = 'da_valide';
UPDATE public.plantations SET statut = 'en_attente_di' WHERE statut = 'en_attente_da';
UPDATE public.plantations SET statut = 'di_valide' WHERE statut = 'da_valide';
UPDATE public.souscripteurs SET statut = 'en_attente_di' WHERE statut = 'en_attente_da';
UPDATE public.souscripteurs SET statut = 'di_valide' WHERE statut = 'da_valide';
UPDATE public.souscripteurs SET statut_global = 'en_attente_di' WHERE statut_global = 'en_attente_da';
UPDATE public.souscripteurs SET statut_global = 'di_valide' WHERE statut_global = 'da_valide';

CREATE OR REPLACE FUNCTION public.create_depot_initial(_souscripteur_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
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

  SELECT di_effectif INTO v_montant FROM public.v_prix_effectif_offres WHERE offre_id = v_s.offre_id;
  v_montant := COALESCE(v_montant, COALESCE(v_o.montant_da_par_ha, v_o.montant_depot_initial_par_ha, 0))
               * COALESCE(v_s.total_hectares, 0);

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
    _souscripteur_id, 'DI', true, 'en_attente', v_montant, v_montant,
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
$fn$;

CREATE OR REPLACE FUNCTION public.reverse_plantation_on_refund()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_amount NUMERIC;
BEGIN
  IF NEW.statut IN ('annule','rembourse')
     AND OLD.statut NOT IN ('annule','rembourse')
     AND NEW.type_paiement IN ('DI','DA')
     AND NEW.plantation_id IS NOT NULL THEN

    v_amount := COALESCE(NEW.montant_paye, NEW.montant, 0);

    UPDATE public.plantations
    SET
      superficie_activee = GREATEST(0, COALESCE(superficie_activee,0) - COALESCE(superficie_ha,0)),
      montant_da = GREATEST(0, COALESCE(montant_da,0) - v_amount),
      statut_global = CASE
        WHEN GREATEST(0, COALESCE(superficie_activee,0) - COALESCE(superficie_ha,0)) <= 0
        THEN 'en_attente_di'
        ELSE statut_global
      END,
      date_activation = CASE
        WHEN GREATEST(0, COALESCE(superficie_activee,0) - COALESCE(superficie_ha,0)) <= 0
        THEN NULL
        ELSE date_activation
      END,
      updated_at = now()
    WHERE id = NEW.plantation_id;

    IF NEW.statut = 'annule' AND NEW.cancelled_at IS NULL THEN
      NEW.cancelled_at := now();
    END IF;
    IF NEW.statut = 'rembourse' AND NEW.refunded_at IS NULL THEN
      NEW.refunded_at := now();
    END IF;
  END IF;
  RETURN NEW;
END;
$fn$;

-- =====================================================================
-- 2. MODULE AGRIPLANT — SUIVI AGRONOMIQUE
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.agriplant_suivis (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plantation_id uuid NOT NULL REFERENCES public.plantations(id) ON DELETE CASCADE,
  souscripteur_id uuid REFERENCES public.souscripteurs(id) ON DELETE SET NULL,
  type_suivi text NOT NULL DEFAULT 'visite',
  titre text NOT NULL,
  observations text,
  actions_recommandees text,
  meteo text,
  note_sante integer,
  date_visite date NOT NULL DEFAULT current_date,
  prochaine_visite date,
  statut text NOT NULL DEFAULT 'planifie',
  responsable_id uuid,
  photos jsonb NOT NULL DEFAULT '[]'::jsonb,
  documents jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_by uuid DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.agriplant_suivi_historique (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  suivi_id uuid NOT NULL REFERENCES public.agriplant_suivis(id) ON DELETE CASCADE,
  action text NOT NULL,
  champ text,
  ancienne_valeur text,
  nouvelle_valeur text,
  commentaire text,
  acteur_id uuid DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_agriplant_suivis_plantation ON public.agriplant_suivis(plantation_id);
CREATE INDEX IF NOT EXISTS idx_agriplant_suivis_souscripteur ON public.agriplant_suivis(souscripteur_id);
CREATE INDEX IF NOT EXISTS idx_agriplant_suivis_statut ON public.agriplant_suivis(statut);
CREATE INDEX IF NOT EXISTS idx_agriplant_suivis_date ON public.agriplant_suivis(date_visite DESC);
CREATE INDEX IF NOT EXISTS idx_agriplant_hist_suivi ON public.agriplant_suivi_historique(suivi_id, created_at DESC);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.agriplant_suivis TO authenticated;
GRANT ALL ON public.agriplant_suivis TO service_role;
GRANT SELECT, INSERT ON public.agriplant_suivi_historique TO authenticated;
GRANT ALL ON public.agriplant_suivi_historique TO service_role;

ALTER TABLE public.agriplant_suivis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agriplant_suivi_historique ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "agriplant_suivis_select" ON public.agriplant_suivis;
CREATE POLICY "agriplant_suivis_select" ON public.agriplant_suivis
  FOR SELECT TO authenticated
  USING (
    public.is_staff(auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.souscripteurs s
      WHERE s.id = agriplant_suivis.souscripteur_id AND s.user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.plantations p
      JOIN public.souscripteurs s2 ON s2.id = p.souscripteur_id
      WHERE p.id = agriplant_suivis.plantation_id AND s2.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "agriplant_suivis_insert" ON public.agriplant_suivis;
CREATE POLICY "agriplant_suivis_insert" ON public.agriplant_suivis
  FOR INSERT TO authenticated
  WITH CHECK (public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "agriplant_suivis_update" ON public.agriplant_suivis;
CREATE POLICY "agriplant_suivis_update" ON public.agriplant_suivis
  FOR UPDATE TO authenticated
  USING (public.is_staff(auth.uid()))
  WITH CHECK (public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "agriplant_suivis_delete" ON public.agriplant_suivis;
CREATE POLICY "agriplant_suivis_delete" ON public.agriplant_suivis
  FOR DELETE TO authenticated
  USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "agriplant_hist_select" ON public.agriplant_suivi_historique;
CREATE POLICY "agriplant_hist_select" ON public.agriplant_suivi_historique
  FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "agriplant_hist_insert" ON public.agriplant_suivi_historique;
CREATE POLICY "agriplant_hist_insert" ON public.agriplant_suivi_historique
  FOR INSERT TO authenticated
  WITH CHECK (public.is_staff(auth.uid()) AND acteur_id = auth.uid());

DROP TRIGGER IF EXISTS trg_agriplant_suivis_updated_at ON public.agriplant_suivis;
CREATE TRIGGER trg_agriplant_suivis_updated_at
  BEFORE UPDATE ON public.agriplant_suivis
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE OR REPLACE FUNCTION public.trace_agriplant_suivi()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.agriplant_suivi_historique(suivi_id, action, commentaire, acteur_id)
    VALUES (NEW.id, 'creation', NEW.titre, auth.uid());
    RETURN NEW;
  END IF;

  IF NEW.statut IS DISTINCT FROM OLD.statut THEN
    INSERT INTO public.agriplant_suivi_historique(suivi_id, action, champ, ancienne_valeur, nouvelle_valeur, acteur_id)
    VALUES (NEW.id, 'changement_statut', 'statut', OLD.statut, NEW.statut, auth.uid());
  END IF;
  IF NEW.responsable_id IS DISTINCT FROM OLD.responsable_id THEN
    INSERT INTO public.agriplant_suivi_historique(suivi_id, action, champ, ancienne_valeur, nouvelle_valeur, acteur_id)
    VALUES (NEW.id, 'affectation', 'responsable_id', OLD.responsable_id::text, NEW.responsable_id::text, auth.uid());
  END IF;
  IF NEW.observations IS DISTINCT FROM OLD.observations THEN
    INSERT INTO public.agriplant_suivi_historique(suivi_id, action, champ, ancienne_valeur, nouvelle_valeur, acteur_id)
    VALUES (NEW.id, 'modification', 'observations', left(COALESCE(OLD.observations,''), 500), left(COALESCE(NEW.observations,''), 500), auth.uid());
  END IF;
  IF NEW.date_visite IS DISTINCT FROM OLD.date_visite THEN
    INSERT INTO public.agriplant_suivi_historique(suivi_id, action, champ, ancienne_valeur, nouvelle_valeur, acteur_id)
    VALUES (NEW.id, 'modification', 'date_visite', OLD.date_visite::text, NEW.date_visite::text, auth.uid());
  END IF;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_agriplant_suivi_trace ON public.agriplant_suivis;
CREATE TRIGGER trg_agriplant_suivi_trace
  AFTER INSERT OR UPDATE ON public.agriplant_suivis
  FOR EACH ROW EXECUTE FUNCTION public.trace_agriplant_suivi();

CREATE OR REPLACE FUNCTION public.agriplant_fill_souscripteur()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF NEW.souscripteur_id IS NULL AND NEW.plantation_id IS NOT NULL THEN
    SELECT p.souscripteur_id INTO NEW.souscripteur_id FROM public.plantations p WHERE p.id = NEW.plantation_id;
  END IF;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_agriplant_fill_souscripteur ON public.agriplant_suivis;
CREATE TRIGGER trg_agriplant_fill_souscripteur
  BEFORE INSERT OR UPDATE ON public.agriplant_suivis
  FOR EACH ROW EXECUTE FUNCTION public.agriplant_fill_souscripteur();

-- =====================================================================
-- 3. POLITIQUES STOCKAGE AGRIPLANT
-- =====================================================================
DROP POLICY IF EXISTS "agriplant_files_read" ON storage.objects;
CREATE POLICY "agriplant_files_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'agriplant');

DROP POLICY IF EXISTS "agriplant_files_write" ON storage.objects;
CREATE POLICY "agriplant_files_write" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'agriplant' AND public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "agriplant_files_delete" ON storage.objects;
CREATE POLICY "agriplant_files_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'agriplant' AND public.is_staff(auth.uid()));