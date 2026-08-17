
-- 1. Sous-préfectures exhaustives du Haut-Sassandra
INSERT INTO public.sous_prefectures (nom, departement_id, est_active)
SELECT * FROM (VALUES
  -- Daloa
  ('Daloa', 'f6903743-4dc4-4554-8be5-c751ab2ffb28'::uuid, true),
  ('Babre', 'f6903743-4dc4-4554-8be5-c751ab2ffb28'::uuid, true),
  ('Gadouan', 'f6903743-4dc4-4554-8be5-c751ab2ffb28'::uuid, true),
  ('Gboguhé', 'f6903743-4dc4-4554-8be5-c751ab2ffb28'::uuid, true),
  ('Gonaté', 'f6903743-4dc4-4554-8be5-c751ab2ffb28'::uuid, true),
  ('Namoué', 'f6903743-4dc4-4554-8be5-c751ab2ffb28'::uuid, true),
  ('Zaïpobly', 'f6903743-4dc4-4554-8be5-c751ab2ffb28'::uuid, true),
  -- Issia
  ('Issia', 'e226f9ca-3eeb-4c11-a966-824a839736af'::uuid, true),
  ('Saïoua', 'e226f9ca-3eeb-4c11-a966-824a839736af'::uuid, true),
  ('Iboguhé', 'e226f9ca-3eeb-4c11-a966-824a839736af'::uuid, true),
  ('Boguédia', 'e226f9ca-3eeb-4c11-a966-824a839736af'::uuid, true),
  ('Namané', 'e226f9ca-3eeb-4c11-a966-824a839736af'::uuid, true),
  ('Grand Nahio', 'e226f9ca-3eeb-4c11-a966-824a839736af'::uuid, true),
  ('Tapéguia', 'e226f9ca-3eeb-4c11-a966-824a839736af'::uuid, true),
  -- Vavoua
  ('Vavoua', 'c39d3bb3-46a5-41b7-9c0b-b525dd01687d'::uuid, true),
  ('Bazra-Nattis', 'c39d3bb3-46a5-41b7-9c0b-b525dd01687d'::uuid, true),
  ('Dania', 'c39d3bb3-46a5-41b7-9c0b-b525dd01687d'::uuid, true),
  ('Diba', 'c39d3bb3-46a5-41b7-9c0b-b525dd01687d'::uuid, true),
  ('Kamalo', 'c39d3bb3-46a5-41b7-9c0b-b525dd01687d'::uuid, true),
  ('Kétro-Bassam', 'c39d3bb3-46a5-41b7-9c0b-b525dd01687d'::uuid, true),
  ('Koukouba', 'c39d3bb3-46a5-41b7-9c0b-b525dd01687d'::uuid, true),
  ('Séïta-Sénoufla', 'c39d3bb3-46a5-41b7-9c0b-b525dd01687d'::uuid, true),
  -- Zoukougbeu
  ('Zoukougbeu', 'a575d61e-df99-4215-9b92-ce8d0a6d38db'::uuid, true),
  ('Domangbeu', 'a575d61e-df99-4215-9b92-ce8d0a6d38db'::uuid, true),
  ('Guessabo', 'a575d61e-df99-4215-9b92-ce8d0a6d38db'::uuid, true),
  ('Dégbézéré', 'a575d61e-df99-4215-9b92-ce8d0a6d38db'::uuid, true)
) AS t(nom, departement_id, est_active)
WHERE NOT EXISTS (
  SELECT 1 FROM public.sous_prefectures sp
  WHERE sp.nom = t.nom AND sp.departement_id = t.departement_id
);

-- 2. Storage policy : permettre upload anonyme dans account-requests/
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
    AND policyname = 'Public can upload account-request files'
  ) THEN
    CREATE POLICY "Public can upload account-request files" ON storage.objects
    FOR INSERT TO anon, authenticated
    WITH CHECK (
      bucket_id = 'documents'
      AND (storage.foldername(name))[1] = 'account-requests'
    );
  END IF;
END $$;

-- 3. Storage policy : lecture publique du bucket documents
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
    AND policyname = 'Public read documents bucket'
  ) THEN
    CREATE POLICY "Public read documents bucket" ON storage.objects
    FOR SELECT TO anon, authenticated
    USING (bucket_id = 'documents');
  END IF;
END $$;
