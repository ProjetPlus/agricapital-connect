-- Correctif global CRM AgriCapital : écritures DB, storage, relations, triggers et géographie

-- 1) Colonnes utilisées par les formulaires mais absentes du schéma actuel
ALTER TABLE public.paiements
  ADD COLUMN IF NOT EXISTS montant_theorique numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS annee integer,
  ADD COLUMN IF NOT EXISTS type_preuve text,
  ADD COLUMN IF NOT EXISTS id_transaction text,
  ADD COLUMN IF NOT EXISTS operateur_mobile_money text,
  ADD COLUMN IF NOT EXISTS fichier_preuve_url text,
  ADD COLUMN IF NOT EXISTS date_upload_preuve timestamptz,
  ADD COLUMN IF NOT EXISTS observations text;

ALTER TABLE public.plantations
  ADD COLUMN IF NOT EXISTS village_nom text,
  ADD COLUMN IF NOT EXISTS localite text,
  ADD COLUMN IF NOT EXISTS latitude numeric,
  ADD COLUMN IF NOT EXISTS longitude numeric,
  ADD COLUMN IF NOT EXISTS altitude numeric,
  ADD COLUMN IF NOT EXISTS document_foncier_type text,
  ADD COLUMN IF NOT EXISTS document_foncier_numero text,
  ADD COLUMN IF NOT EXISTS document_foncier_date_delivrance date,
  ADD COLUMN IF NOT EXISTS date_signature_contrat date,
  ADD COLUMN IF NOT EXISTS chef_village_nom text,
  ADD COLUMN IF NOT EXISTS chef_village_telephone text,
  ADD COLUMN IF NOT EXISTS notes_internes text,
  ADD COLUMN IF NOT EXISTS type_culture text DEFAULT 'Palmier à huile';

-- Synchroniser les alias historiques avec les colonnes déjà utilisées ailleurs
UPDATE public.plantations
SET
  village_nom = COALESCE(village_nom, village),
  localite = COALESCE(localite, village),
  latitude = COALESCE(latitude, localisation_gps_lat),
  longitude = COALESCE(longitude, localisation_gps_lng),
  notes_internes = COALESCE(notes_internes, notes)
WHERE village_nom IS NULL OR localite IS NULL OR latitude IS NULL OR longitude IS NULL OR notes_internes IS NULL;

-- 2) Table documents de souscription utilisée par upload/validation
CREATE TABLE IF NOT EXISTS public.documents_souscription (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  souscripteur_id uuid,
  type_document text NOT NULL,
  fichier_url text NOT NULL,
  statut text DEFAULT 'en_attente',
  observations text,
  validated_by uuid,
  validated_at timestamptz,
  uploaded_by uuid,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.documents_souscription ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage documents_souscription" ON public.documents_souscription;
CREATE POLICY "Staff manage documents_souscription"
ON public.documents_souscription
FOR ALL
TO authenticated
USING (public.is_staff(auth.uid()))
WITH CHECK (public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "Souscripteurs read own documents_souscription" ON public.documents_souscription;
CREATE POLICY "Souscripteurs read own documents_souscription"
ON public.documents_souscription
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.souscripteurs s
    WHERE s.id = documents_souscription.souscripteur_id
      AND s.user_id = auth.uid()
  )
);

-- 3) Storage : bucket foncier manquant + policies staff complètes
INSERT INTO storage.buckets (id, name, public)
VALUES ('documents-fonciers', 'documents-fonciers', true)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;

DROP POLICY IF EXISTS "Staff read documents-fonciers" ON storage.objects;
CREATE POLICY "Staff read documents-fonciers"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'documents-fonciers' AND public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "Staff upload documents-fonciers" ON storage.objects;
CREATE POLICY "Staff upload documents-fonciers"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'documents-fonciers' AND public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "Staff update documents-fonciers" ON storage.objects;
CREATE POLICY "Staff update documents-fonciers"
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'documents-fonciers' AND public.is_staff(auth.uid()))
WITH CHECK (bucket_id = 'documents-fonciers' AND public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "Staff delete documents-fonciers" ON storage.objects;
CREATE POLICY "Staff delete documents-fonciers"
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'documents-fonciers' AND public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "Staff update photos-profils" ON storage.objects;
CREATE POLICY "Staff update photos-profils"
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'photos-profils' AND public.is_staff(auth.uid()))
WITH CHECK (bucket_id = 'photos-profils' AND public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "Staff delete photos-profils" ON storage.objects;
CREATE POLICY "Staff delete photos-profils"
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'photos-profils' AND public.is_staff(auth.uid()));

-- 4) Fonctions de synchronisation et validation
CREATE OR REPLACE FUNCTION public.sync_plantation_aliases()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.village := COALESCE(NEW.village, NEW.village_nom, NEW.localite);
  NEW.village_nom := COALESCE(NEW.village_nom, NEW.village, NEW.localite);
  NEW.localite := COALESCE(NEW.localite, NEW.village_nom, NEW.village);
  NEW.localisation_gps_lat := COALESCE(NEW.localisation_gps_lat, NEW.latitude);
  NEW.localisation_gps_lng := COALESCE(NEW.localisation_gps_lng, NEW.longitude);
  NEW.latitude := COALESCE(NEW.latitude, NEW.localisation_gps_lat);
  NEW.longitude := COALESCE(NEW.longitude, NEW.localisation_gps_lng);
  NEW.notes := COALESCE(NEW.notes, NEW.notes_internes);
  NEW.notes_internes := COALESCE(NEW.notes_internes, NEW.notes);
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_paiement_aliases()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.preuve_paiement_url := COALESCE(NEW.preuve_paiement_url, NEW.fichier_preuve_url);
  NEW.fichier_preuve_url := COALESCE(NEW.fichier_preuve_url, NEW.preuve_paiement_url);
  NEW.reference := COALESCE(NEW.reference, NEW.id_transaction);
  NEW.notes := COALESCE(NEW.notes, NEW.observations);
  NEW.observations := COALESCE(NEW.observations, NEW.notes);
  NEW.montant := COALESCE(NULLIF(NEW.montant, 0), NEW.montant_paye, NEW.montant_theorique, 0);
  NEW.montant_paye := COALESCE(NULLIF(NEW.montant_paye, 0), NEW.montant, NEW.montant_theorique, 0);
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_generated_ids()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_TABLE_NAME = 'souscripteurs' AND (NEW.id_unique IS NULL OR NEW.id_unique = '') THEN
    NEW.id_unique := public.generate_souscripteur_id();
  ELSIF TG_TABLE_NAME = 'plantations' AND (NEW.id_unique IS NULL OR NEW.id_unique = '') THEN
    NEW.id_unique := public.generate_plantation_id();
  ELSIF TG_TABLE_NAME = 'parcelles' AND (NEW.id_unique IS NULL OR NEW.id_unique = '') THEN
    NEW.id_unique := public.generate_parcelle_id();
  ELSIF TG_TABLE_NAME = 'proprietaires_terres' AND (NEW.id_unique IS NULL OR NEW.id_unique = '') THEN
    NEW.id_unique := public.generate_proprietaire_id();
  END IF;
  RETURN NEW;
END;
$$;

-- 5) Triggers manquants (la base actuelle en a 0)
DROP TRIGGER IF EXISTS trg_plantations_sync_aliases ON public.plantations;
CREATE TRIGGER trg_plantations_sync_aliases
BEFORE INSERT OR UPDATE ON public.plantations
FOR EACH ROW EXECUTE FUNCTION public.sync_plantation_aliases();

DROP TRIGGER IF EXISTS trg_paiements_sync_aliases ON public.paiements;
CREATE TRIGGER trg_paiements_sync_aliases
BEFORE INSERT OR UPDATE ON public.paiements
FOR EACH ROW EXECUTE FUNCTION public.sync_paiement_aliases();

DROP TRIGGER IF EXISTS trg_paiements_validate ON public.paiements;
CREATE TRIGGER trg_paiements_validate
BEFORE INSERT OR UPDATE ON public.paiements
FOR EACH ROW EXECUTE FUNCTION public.validate_paiement();

DROP TRIGGER IF EXISTS trg_plantations_validate ON public.plantations;
CREATE TRIGGER trg_plantations_validate
BEFORE INSERT OR UPDATE ON public.plantations
FOR EACH ROW EXECUTE FUNCTION public.validate_plantation();

DROP TRIGGER IF EXISTS trg_souscripteurs_generated_id ON public.souscripteurs;
CREATE TRIGGER trg_souscripteurs_generated_id
BEFORE INSERT ON public.souscripteurs
FOR EACH ROW EXECUTE FUNCTION public.set_generated_ids();

DROP TRIGGER IF EXISTS trg_plantations_generated_id ON public.plantations;
CREATE TRIGGER trg_plantations_generated_id
BEFORE INSERT ON public.plantations
FOR EACH ROW EXECUTE FUNCTION public.set_generated_ids();

DROP TRIGGER IF EXISTS trg_parcelles_generated_id ON public.parcelles;
CREATE TRIGGER trg_parcelles_generated_id
BEFORE INSERT ON public.parcelles
FOR EACH ROW EXECUTE FUNCTION public.set_generated_ids();

DROP TRIGGER IF EXISTS trg_proprietaires_generated_id ON public.proprietaires_terres;
CREATE TRIGGER trg_proprietaires_generated_id
BEFORE INSERT ON public.proprietaires_terres
FOR EACH ROW EXECUTE FUNCTION public.set_generated_ids();

DROP TRIGGER IF EXISTS trg_parcelles_calculate_surfaces ON public.parcelles;
CREATE TRIGGER trg_parcelles_calculate_surfaces
BEFORE INSERT OR UPDATE OF surface_totale_ha, surface_attribuee_ha ON public.parcelles
FOR EACH ROW EXECUTE FUNCTION public.calculate_parcelle_surfaces();

DROP TRIGGER IF EXISTS trg_plantations_update_souscripteur_stats ON public.plantations;
CREATE TRIGGER trg_plantations_update_souscripteur_stats
AFTER INSERT OR UPDATE OR DELETE ON public.plantations
FOR EACH ROW EXECUTE FUNCTION public.update_souscripteur_stats();

DROP TRIGGER IF EXISTS trg_plantations_update_parcelle_attribution ON public.plantations;
CREATE TRIGGER trg_plantations_update_parcelle_attribution
AFTER INSERT OR UPDATE OR DELETE ON public.plantations
FOR EACH ROW EXECUTE FUNCTION public.update_parcelle_attribution();

DROP TRIGGER IF EXISTS trg_parcelles_update_proprietaire_stats ON public.parcelles;
CREATE TRIGGER trg_parcelles_update_proprietaire_stats
AFTER INSERT OR UPDATE OR DELETE ON public.parcelles
FOR EACH ROW EXECUTE FUNCTION public.update_proprietaire_stats();

DROP TRIGGER IF EXISTS trg_paiements_reverse_refund ON public.paiements;
CREATE TRIGGER trg_paiements_reverse_refund
BEFORE UPDATE OF statut ON public.paiements
FOR EACH ROW EXECUTE FUNCTION public.reverse_plantation_on_refund();

-- Updated_at générique sur tables critiques
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT unnest(ARRAY[
    'profiles','equipes','paiements','plantations','parcelles','proprietaires_terres','promotions','souscripteurs','documents_souscription'
  ]) AS table_name LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%I_updated_at ON public.%I', r.table_name, r.table_name);
    EXECUTE format('CREATE TRIGGER trg_%I_updated_at BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column()', r.table_name, r.table_name);
  END LOOP;
END $$;

-- Cascades géographiques
DROP TRIGGER IF EXISTS trg_districts_cascade_activation ON public.districts;
CREATE TRIGGER trg_districts_cascade_activation
AFTER UPDATE OF est_actif ON public.districts
FOR EACH ROW EXECUTE FUNCTION public.cascade_district_activation();

DROP TRIGGER IF EXISTS trg_regions_cascade_activation ON public.regions;
CREATE TRIGGER trg_regions_cascade_activation
AFTER UPDATE OF est_active ON public.regions
FOR EACH ROW EXECUTE FUNCTION public.cascade_region_activation();

DROP TRIGGER IF EXISTS trg_departements_cascade_activation ON public.departements;
CREATE TRIGGER trg_departements_cascade_activation
AFTER UPDATE OF est_actif ON public.departements
FOR EACH ROW EXECUTE FUNCTION public.cascade_departement_activation();

DROP TRIGGER IF EXISTS trg_sous_prefectures_cascade_activation ON public.sous_prefectures;
CREATE TRIGGER trg_sous_prefectures_cascade_activation
AFTER UPDATE OF est_active ON public.sous_prefectures
FOR EACH ROW EXECUTE FUNCTION public.cascade_sous_prefecture_activation();

-- 6) Relations FK idempotentes pour requêtes imbriquées et intégrité
DO $$
DECLARE fk text[];
BEGIN
  FOREACH fk SLICE 1 IN ARRAY ARRAY[
    ARRAY['regions','regions_district_id_fkey','district_id','districts','id','SET NULL'],
    ARRAY['departements','departements_region_id_fkey','region_id','regions','id','SET NULL'],
    ARRAY['sous_prefectures','sous_prefectures_departement_id_fkey','departement_id','departements','id','SET NULL'],
    ARRAY['villages','villages_sous_prefecture_id_fkey','sous_prefecture_id','sous_prefectures','id','SET NULL'],
    ARRAY['equipes','equipes_responsable_id_fkey','responsable_id','profiles','id','SET NULL'],
    ARRAY['equipes','equipes_superviseur_id_fkey','superviseur_id','profiles','id','SET NULL'],
    ARRAY['equipes','equipes_region_id_fkey','region_id','regions','id','SET NULL'],
    ARRAY['profiles','profiles_equipe_id_fkey','equipe_id','equipes','id','SET NULL'],
    ARRAY['souscripteurs','souscripteurs_offre_id_fkey','offre_id','offres','id','SET NULL'],
    ARRAY['souscripteurs','souscripteurs_parcelle_id_fkey','parcelle_id','parcelles','id','SET NULL'],
    ARRAY['souscripteurs','souscripteurs_district_id_fkey','district_id','districts','id','SET NULL'],
    ARRAY['souscripteurs','souscripteurs_region_id_fkey','region_id','regions','id','SET NULL'],
    ARRAY['souscripteurs','souscripteurs_departement_id_fkey','departement_id','departements','id','SET NULL'],
    ARRAY['souscripteurs','souscripteurs_sous_prefecture_id_fkey','sous_prefecture_id','sous_prefectures','id','SET NULL'],
    ARRAY['proprietaires_terres','proprietaires_terres_district_id_fkey','district_id','districts','id','SET NULL'],
    ARRAY['proprietaires_terres','proprietaires_terres_region_id_fkey','region_id','regions','id','SET NULL'],
    ARRAY['proprietaires_terres','proprietaires_terres_departement_id_fkey','departement_id','departements','id','SET NULL'],
    ARRAY['proprietaires_terres','proprietaires_terres_sous_prefecture_id_fkey','sous_prefecture_id','sous_prefectures','id','SET NULL'],
    ARRAY['parcelles','parcelles_proprietaire_id_fkey','proprietaire_id','proprietaires_terres','id','SET NULL'],
    ARRAY['parcelles','parcelles_district_id_fkey','district_id','districts','id','SET NULL'],
    ARRAY['parcelles','parcelles_region_id_fkey','region_id','regions','id','SET NULL'],
    ARRAY['parcelles','parcelles_departement_id_fkey','departement_id','departements','id','SET NULL'],
    ARRAY['parcelles','parcelles_sous_prefecture_id_fkey','sous_prefecture_id','sous_prefectures','id','SET NULL'],
    ARRAY['plantations','plantations_souscripteur_id_fkey','souscripteur_id','souscripteurs','id','CASCADE'],
    ARRAY['plantations','plantations_parcelle_id_fkey','parcelle_id','parcelles','id','SET NULL'],
    ARRAY['plantations','plantations_district_id_fkey','district_id','districts','id','SET NULL'],
    ARRAY['plantations','plantations_region_id_fkey','region_id','regions','id','SET NULL'],
    ARRAY['plantations','plantations_departement_id_fkey','departement_id','departements','id','SET NULL'],
    ARRAY['plantations','plantations_sous_prefecture_id_fkey','sous_prefecture_id','sous_prefectures','id','SET NULL'],
    ARRAY['paiements','paiements_souscripteur_id_fkey','souscripteur_id','souscripteurs','id','CASCADE'],
    ARRAY['paiements','paiements_plantation_id_fkey','plantation_id','plantations','id','SET NULL'],
    ARRAY['documents_souscription','documents_souscription_souscripteur_id_fkey','souscripteur_id','souscripteurs','id','CASCADE'],
    ARRAY['documents_convention','documents_convention_parcelle_id_fkey','parcelle_id','parcelles','id','CASCADE'],
    ARRAY['documents_convention','documents_convention_proprietaire_id_fkey','proprietaire_id','proprietaires_terres','id','CASCADE'],
    ARRAY['tickets_techniques','tickets_techniques_plantation_id_fkey','plantation_id','plantations','id','SET NULL'],
    ARRAY['remboursements','remboursements_souscripteur_id_fkey','souscripteur_id','souscripteurs','id','CASCADE'],
    ARRAY['remboursements','remboursements_paiement_id_fkey','paiement_id','paiements','id','SET NULL'],
    ARRAY['transferts_paiements','transferts_source_id_fkey','souscripteur_source_id','souscripteurs','id','SET NULL'],
    ARRAY['transferts_paiements','transferts_dest_id_fkey','souscripteur_dest_id','souscripteurs','id','SET NULL']
  ] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = fk[2]) THEN
      EXECUTE format('ALTER TABLE public.%I ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES public.%I(%I) ON DELETE %s', fk[1], fk[2], fk[3], fk[4], fk[5], fk[6]);
    END IF;
  END LOOP;
END $$;

-- 7) Index de performance
CREATE INDEX IF NOT EXISTS idx_paiements_souscripteur_id ON public.paiements(souscripteur_id);
CREATE INDEX IF NOT EXISTS idx_paiements_plantation_id ON public.paiements(plantation_id);
CREATE INDEX IF NOT EXISTS idx_paiements_statut ON public.paiements(statut);
CREATE INDEX IF NOT EXISTS idx_plantations_souscripteur_id ON public.plantations(souscripteur_id);
CREATE INDEX IF NOT EXISTS idx_plantations_parcelle_id ON public.plantations(parcelle_id);
CREATE INDEX IF NOT EXISTS idx_parcelles_proprietaire_id ON public.parcelles(proprietaire_id);
CREATE INDEX IF NOT EXISTS idx_souscripteurs_user_id ON public.souscripteurs(user_id);
CREATE INDEX IF NOT EXISTS idx_souscripteurs_offre_id ON public.souscripteurs(offre_id);
CREATE INDEX IF NOT EXISTS idx_documents_souscription_souscripteur_id ON public.documents_souscription(souscripteur_id);
CREATE INDEX IF NOT EXISTS idx_zone_assignments_user_id ON public.zone_assignments(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_sous_prefectures_dept_nom_unique ON public.sous_prefectures(departement_id, lower(nom));

-- 8) Haut-Sassandra : compléter sans doublons, avec normalisations d’accents/orthographe
WITH dept AS (
  SELECT id, nom FROM public.departements WHERE nom IN ('Daloa','Issia','Vavoua','Zoukougbeu')
), expected(departement, nom) AS (
  VALUES
  ('Daloa','Bédiala'),('Daloa','Daloa'),('Daloa','Gadouan'),('Daloa','Gboguhé'),('Daloa','Gonaté'),('Daloa','Zaïbo'),
  ('Issia','Boguédia'),('Issia','Iboguhé'),('Issia','Issia'),('Issia','Saïoua'),('Issia','Tapéguia'),
  ('Vavoua','Bazra-Nattis'),('Vavoua','Dananon'),('Vavoua','Dania'),('Vavoua','Kétro-Bassam'),('Vavoua','Séitifla'),('Vavoua','Vavoua'),
  ('Zoukougbeu','Zoukougbeu'),('Zoukougbeu','Guessabo')
)
INSERT INTO public.sous_prefectures (nom, departement_id, est_active)
SELECT e.nom, d.id, true
FROM expected e JOIN dept d ON d.nom = e.departement
ON CONFLICT DO NOTHING;

-- 9) Permissions manquantes mais nécessaires aux écrans existants
DROP POLICY IF EXISTS "Admins delete promotions" ON public.promotions;
CREATE POLICY "Admins delete promotions"
ON public.promotions
FOR DELETE
TO authenticated
USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Staff create retraits" ON public.retraits_portefeuille;
CREATE POLICY "Staff create retraits"
ON public.retraits_portefeuille
FOR INSERT
TO authenticated
WITH CHECK (public.is_staff(auth.uid()) AND (user_id IS NULL OR user_id = auth.uid() OR public.is_admin(auth.uid())));

DROP POLICY IF EXISTS "Staff update own retraits or admins" ON public.retraits_portefeuille;
CREATE POLICY "Staff update own retraits or admins"
ON public.retraits_portefeuille
FOR UPDATE
TO authenticated
USING (public.is_admin(auth.uid()) OR user_id = auth.uid());