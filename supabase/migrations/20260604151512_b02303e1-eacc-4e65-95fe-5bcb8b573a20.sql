-- 1) Tighten public account request creation and table grants
DROP POLICY IF EXISTS "Anyone can create account request" ON public.account_requests;
CREATE POLICY "Public can submit pending account requests"
ON public.account_requests
FOR INSERT
TO anon, authenticated
WITH CHECK (
  statut = 'en_attente'
  AND traite_par IS NULL
  AND traite_le IS NULL
  AND motif_rejet IS NULL
  AND nom_complet IS NOT NULL
  AND length(trim(nom_complet)) BETWEEN 2 AND 120
  AND email IS NOT NULL
  AND email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'
  AND telephone IS NOT NULL
  AND length(trim(telephone)) >= 8
  AND role_souhaite IN ('super_admin','directeur_tc','responsable_zone','superviseur_tc','chef_equipe','comptable','commercial','service_client','operations','agent_terrain','technicien','user')
  AND (photo_url IS NULL OR photo_url LIKE '%/storage/v1/object/%/documents/account-requests/%')
  AND (cv_url IS NULL OR cv_url LIKE '%/storage/v1/object/%/documents/account-requests/%')
);

REVOKE ALL ON public.proprietaires_terres, public.parcelles, public.conventions_foncieres, public.documents_convention, public.lots_hectares, public.souscripteurs, public.souscriptions_brouillon FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.proprietaires_terres, public.parcelles, public.conventions_foncieres, public.documents_convention, public.lots_hectares, public.souscripteurs, public.souscriptions_brouillon TO authenticated;
GRANT ALL ON public.proprietaires_terres, public.parcelles, public.conventions_foncieres, public.documents_convention, public.lots_hectares, public.souscripteurs, public.souscriptions_brouillon TO service_role;

-- 2) Lock internal SECURITY DEFINER helpers away from anonymous direct calls
REVOKE EXECUTE ON FUNCTION public.assign_sp_code(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.current_profile_id() FROM anon;
REVOKE EXECUTE ON FUNCTION public.enforce_souscripteur_refund_update() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.generate_convention_reference() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.generate_numero_contrat_souscripteur() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.has_role(uuid, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.is_admin(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.is_staff(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.rate_limit_account_requests() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.set_domaine_code() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.set_lot_reference() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.set_parcelle_code() FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.current_profile_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_staff(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_sp_code(uuid) TO authenticated;

-- 3) Complete Convention PP V1 data model without creating new public tables
ALTER TABLE public.proprietaires_terres
  ADD COLUMN IF NOT EXISTS coordonnees_gps text,
  ADD COLUMN IF NOT EXISTS surface_totale_declaree_ha numeric,
  ADD COLUMN IF NOT EXISTS part_proprietaire_pct numeric DEFAULT 50,
  ADD COLUMN IF NOT EXISTS part_agricapital_pct numeric DEFAULT 50,
  ADD COLUMN IF NOT EXISTS part_proprietaire_ha numeric,
  ADD COLUMN IF NOT EXISTS part_agricapital_ha numeric,
  ADD COLUMN IF NOT EXISTS caution_par_ha numeric DEFAULT 50000,
  ADD COLUMN IF NOT EXISTS caution_totale numeric,
  ADD COLUMN IF NOT EXISTS co_titulaire_nom text,
  ADD COLUMN IF NOT EXISTS co_titulaire_lien text,
  ADD COLUMN IF NOT EXISTS co_titulaire_piece text,
  ADD COLUMN IF NOT EXISTS co_titulaire_telephone text,
  ADD COLUMN IF NOT EXISTS temoin_proprietaire_nom text,
  ADD COLUMN IF NOT EXISTS temoin_proprietaire_qualite text,
  ADD COLUMN IF NOT EXISTS representant_agricapital_nom text,
  ADD COLUMN IF NOT EXISTS representant_agricapital_qualite text,
  ADD COLUMN IF NOT EXISTS leader_communautaire_nom text,
  ADD COLUMN IF NOT EXISTS leader_communautaire_qualite text,
  ADD COLUMN IF NOT EXISTS voisin_1_nom text,
  ADD COLUMN IF NOT EXISTS voisin_1_cote text,
  ADD COLUMN IF NOT EXISTS voisin_2_nom text,
  ADD COLUMN IF NOT EXISTS voisin_2_cote text;

ALTER TABLE public.conventions_foncieres
  ADD COLUMN IF NOT EXISTS part_proprietaire_pct numeric DEFAULT 50,
  ADD COLUMN IF NOT EXISTS part_agricapital_pct numeric DEFAULT 50,
  ADD COLUMN IF NOT EXISTS part_proprietaire_ha numeric,
  ADD COLUMN IF NOT EXISTS part_agricapital_ha numeric,
  ADD COLUMN IF NOT EXISTS caution_par_ha numeric DEFAULT 50000,
  ADD COLUMN IF NOT EXISTS caution_totale numeric;

ALTER TABLE public.documents_convention DROP CONSTRAINT IF EXISTS documents_convention_type_document_check;
ALTER TABLE public.documents_convention
  ADD CONSTRAINT documents_convention_type_document_check
  CHECK (type_document = ANY (ARRAY[
    'annexe_1_pv_delimitation_croquis',
    'annexe_2_pv_consentement_familial',
    'annexe_3_acte_reconnaissance_parts',
    'annexe_4_acte_remise_jouissance',
    'annexe_5_procuration_mandataire',
    'annexe_6_copies_cni_signataires',
    'annexe_7_acte_mariage',
    'annexe_8_guide_villageois_attestation',
    'piece_identite_recto',
    'piece_identite_verso',
    'photo_profil',
    'autre',
    'pv_delimitation',
    'acte_reconnaissance_parts',
    'pv_consentement_familial',
    'acte_remise_plantation',
    'procuration_mandataire',
    'cni_recto',
    'cni_verso',
    'croquis_parcellaire',
    'attestation_villageoise',
    'certificat_foncier'
  ]));

CREATE OR REPLACE FUNCTION public.validate_documents_convention_file()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
  IF NEW.statut IN ('joint','valide') AND (NEW.fichier_url IS NULL OR trim(NEW.fichier_url) = '') THEN
    RAISE EXCEPTION 'Un fichier est obligatoire pour une annexe marquée jointe ou validée';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_documents_convention_file ON public.documents_convention;
CREATE TRIGGER trg_validate_documents_convention_file
BEFORE INSERT OR UPDATE ON public.documents_convention
FOR EACH ROW EXECUTE FUNCTION public.validate_documents_convention_file();

-- 4) Storage policies: keep anon only for account requests, staff on private buckets, own-folder option for authenticated users
DROP POLICY IF EXISTS "Staff upload pieces-identite" ON storage.objects;
DROP POLICY IF EXISTS "Staff read pieces-identite" ON storage.objects;
DROP POLICY IF EXISTS "Staff manage pieces-identite" ON storage.objects;
DROP POLICY IF EXISTS "Staff delete pieces-identite" ON storage.objects;
DROP POLICY IF EXISTS "Staff upload documents-fonciers" ON storage.objects;
DROP POLICY IF EXISTS "Staff read documents-fonciers" ON storage.objects;
DROP POLICY IF EXISTS "Staff update documents-fonciers" ON storage.objects;
DROP POLICY IF EXISTS "Staff delete documents-fonciers" ON storage.objects;
DROP POLICY IF EXISTS "Staff upload documents bucket" ON storage.objects;
DROP POLICY IF EXISTS "Staff read documents bucket" ON storage.objects;
DROP POLICY IF EXISTS "Auth upload own folder documents" ON storage.objects;
DROP POLICY IF EXISTS "Owner read own folder documents" ON storage.objects;
DROP POLICY IF EXISTS "Staff upload private identity docs" ON storage.objects;
DROP POLICY IF EXISTS "Staff read private identity docs" ON storage.objects;
DROP POLICY IF EXISTS "Staff update private identity docs" ON storage.objects;
DROP POLICY IF EXISTS "Staff delete private identity docs" ON storage.objects;
DROP POLICY IF EXISTS "Staff upload private land docs" ON storage.objects;
DROP POLICY IF EXISTS "Staff read private land docs" ON storage.objects;
DROP POLICY IF EXISTS "Staff update private land docs" ON storage.objects;
DROP POLICY IF EXISTS "Staff delete private land docs" ON storage.objects;
DROP POLICY IF EXISTS "Staff manage documents bucket" ON storage.objects;
DROP POLICY IF EXISTS "Owner manage own documents folder" ON storage.objects;
DROP POLICY IF EXISTS "Owner read own documents folder" ON storage.objects;

CREATE POLICY "Staff upload private identity docs"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'pieces-identite' AND public.is_staff(auth.uid()));
CREATE POLICY "Staff read private identity docs"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'pieces-identite' AND public.is_staff(auth.uid()));
CREATE POLICY "Staff update private identity docs"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'pieces-identite' AND public.is_staff(auth.uid()))
WITH CHECK (bucket_id = 'pieces-identite' AND public.is_staff(auth.uid()));
CREATE POLICY "Staff delete private identity docs"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'pieces-identite' AND public.is_staff(auth.uid()));

CREATE POLICY "Staff upload private land docs"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'documents-fonciers' AND public.is_staff(auth.uid()));
CREATE POLICY "Staff read private land docs"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'documents-fonciers' AND public.is_staff(auth.uid()));
CREATE POLICY "Staff update private land docs"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'documents-fonciers' AND public.is_staff(auth.uid()))
WITH CHECK (bucket_id = 'documents-fonciers' AND public.is_staff(auth.uid()));
CREATE POLICY "Staff delete private land docs"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'documents-fonciers' AND public.is_staff(auth.uid()));

CREATE POLICY "Staff manage documents bucket"
ON storage.objects FOR ALL TO authenticated
USING (bucket_id = 'documents' AND public.is_staff(auth.uid()))
WITH CHECK (bucket_id = 'documents' AND public.is_staff(auth.uid()));
CREATE POLICY "Owner manage own documents folder"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'documents' AND auth.uid() IS NOT NULL AND (storage.foldername(name))[1] = auth.uid()::text);
CREATE POLICY "Owner read own documents folder"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'documents' AND auth.uid() IS NOT NULL AND (storage.foldername(name))[1] = auth.uid()::text);

-- 5) Validate account request rate-limit trigger exists
DROP TRIGGER IF EXISTS trg_rate_limit_account_requests ON public.account_requests;
CREATE TRIGGER trg_rate_limit_account_requests
BEFORE INSERT ON public.account_requests
FOR EACH ROW EXECUTE FUNCTION public.rate_limit_account_requests();