-- 1. Grants manquants sur les tables AgriPlant (RLS déjà en place)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.agriplant_suivis TO authenticated;
GRANT ALL ON public.agriplant_suivis TO service_role;

GRANT SELECT, INSERT ON public.agriplant_suivi_historique TO authenticated;
GRANT ALL ON public.agriplant_suivi_historique TO service_role;

-- 2. Politiques d'upload / mise à jour sur le bucket agriplant
DROP POLICY IF EXISTS agriplant_files_insert ON storage.objects;
CREATE POLICY agriplant_files_insert
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'agriplant' AND public.is_staff(auth.uid()));

DROP POLICY IF EXISTS agriplant_files_update ON storage.objects;
CREATE POLICY agriplant_files_update
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'agriplant' AND public.is_staff(auth.uid()))
WITH CHECK (bucket_id = 'agriplant' AND public.is_staff(auth.uid()));