-- Politiques de stockage pour le bucket privé "agriplan"
-- Convention de chemin : agriplan/<client_id>/<categorie>/<fichier>

CREATE POLICY "agriplan_files_staff_select" ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'agriplan' AND public.is_staff(auth.uid()));

CREATE POLICY "agriplan_files_staff_insert" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'agriplan' AND public.is_staff(auth.uid()));

CREATE POLICY "agriplan_files_staff_update" ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'agriplan' AND public.is_staff(auth.uid()))
  WITH CHECK (bucket_id = 'agriplan' AND public.is_staff(auth.uid()));

CREATE POLICY "agriplan_files_staff_delete" ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'agriplan' AND public.has_role(auth.uid(),'super_admin'));

CREATE POLICY "agriplan_files_client_select" ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'agriplan'
    AND EXISTS (
      SELECT 1 FROM public.agriplan_clients c
      WHERE c.user_id = auth.uid()
        AND (storage.foldername(name))[1] = c.id::text
    )
  );
