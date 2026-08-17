
-- ============================================================
-- V3 finalization: add missing foreign keys so PostgREST embedded
-- selects work across the app. Idempotent via DO blocks.
-- ============================================================

DO $$
DECLARE
  fk RECORD;
  fks TEXT[][] := ARRAY[
    -- proprietaires_terres
    ['proprietaires_terres','district_id','districts','id'],
    ['proprietaires_terres','region_id','regions','id'],
    ['proprietaires_terres','departement_id','departements','id'],
    ['proprietaires_terres','sous_prefecture_id','sous_prefectures','id'],
    -- souscripteurs
    ['souscripteurs','district_id','districts','id'],
    ['souscripteurs','region_id','regions','id'],
    ['souscripteurs','departement_id','departements','id'],
    ['souscripteurs','sous_prefecture_id','sous_prefectures','id'],
    ['souscripteurs','offre_id','offres','id'],
    ['souscripteurs','parcelle_id','parcelles','id'],
    -- parcelles
    ['parcelles','proprietaire_id','proprietaires_terres','id'],
    ['parcelles','district_id','districts','id'],
    ['parcelles','region_id','regions','id'],
    ['parcelles','departement_id','departements','id'],
    ['parcelles','sous_prefecture_id','sous_prefectures','id'],
    ['parcelles','convention_id','conventions_foncieres','id'],
    ['parcelles','domaine_id','domaines','id'],
    -- plantations
    ['plantations','souscripteur_id','souscripteurs','id'],
    ['plantations','parcelle_id','parcelles','id'],
    ['plantations','district_id','districts','id'],
    ['plantations','region_id','regions','id'],
    ['plantations','departement_id','departements','id'],
    ['plantations','sous_prefecture_id','sous_prefectures','id'],
    -- paiements
    ['paiements','souscripteur_id','souscripteurs','id'],
    ['paiements','plantation_id','plantations','id'],
    -- documents_souscription
    ['documents_souscription','souscripteur_id','souscripteurs','id'],
    -- conventions / lots
    ['conventions_foncieres','proprietaire_id','proprietaires_terres','id'],
    ['conventions_foncieres','parcelle_id','parcelles','id'],
    ['conventions_foncieres','domaine_id','domaines','id'],
    ['conventions_foncieres','sous_prefecture_id','sous_prefectures','id'],
    ['lots_hectares','parcelle_id','parcelles','id'],
    ['lots_hectares','convention_id','conventions_foncieres','id'],
    ['lots_hectares','souscripteur_id','souscripteurs','id'],
    ['cotitulaires_mandataires','proprietaire_id','proprietaires_terres','id'],
    ['documents_convention','proprietaire_id','proprietaires_terres','id'],
    ['documents_convention','parcelle_id','parcelles','id'],
    ['domaines','sous_prefecture_id','sous_prefectures','id'],
    -- commissions / portefeuille
    ['commissions','plantation_id','plantations','id'],
    ['commissions','profile_id','profiles','id'],
    ['remboursements','souscripteur_id','souscripteurs','id'],
    ['remboursements','paiement_id','paiements','id']
  ];
  i INT;
  tbl TEXT; col TEXT; ftbl TEXT; fcol TEXT; cname TEXT;
BEGIN
  FOR i IN 1..array_length(fks,1) LOOP
    tbl := fks[i][1]; col := fks[i][2]; ftbl := fks[i][3]; fcol := fks[i][4];
    cname := tbl || '_' || col || '_fkey';
    -- skip if column doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema='public' AND table_name=tbl AND column_name=col) THEN
      CONTINUE;
    END IF;
    -- skip if FK already exists
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints
               WHERE table_schema='public' AND table_name=tbl AND constraint_name=cname) THEN
      CONTINUE;
    END IF;
    EXECUTE format('ALTER TABLE public.%I ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES public.%I(%I) ON DELETE SET NULL',
                   tbl, cname, col, ftbl, fcol);
  END LOOP;
END $$;

-- ============================================================
-- Ensure storage buckets used by the app exist
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('photos-plantations', 'photos-plantations', false),
  ('preuves-paiement', 'preuves-paiement', false)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for new buckets (staff full access, owners read own)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='Staff manage photos-plantations') THEN
    CREATE POLICY "Staff manage photos-plantations" ON storage.objects FOR ALL TO authenticated
      USING (bucket_id='photos-plantations' AND public.is_staff(auth.uid()))
      WITH CHECK (bucket_id='photos-plantations' AND public.is_staff(auth.uid()));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='Staff manage preuves-paiement') THEN
    CREATE POLICY "Staff manage preuves-paiement" ON storage.objects FOR ALL TO authenticated
      USING (bucket_id='preuves-paiement' AND public.is_staff(auth.uid()))
      WITH CHECK (bucket_id='preuves-paiement' AND public.is_staff(auth.uid()));
  END IF;
END $$;
