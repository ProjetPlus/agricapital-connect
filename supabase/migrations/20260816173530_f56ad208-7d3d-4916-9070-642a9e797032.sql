
REVOKE EXECUTE ON FUNCTION public.resolve_username_email(text) FROM anon, authenticated, PUBLIC;
GRANT EXECUTE ON FUNCTION public.resolve_username_email(text) TO service_role;

REVOKE EXECUTE ON FUNCTION public.guard_paiements_self_update() FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.guard_profiles_sensitive_update() FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.guard_retraits_self_approval() FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.trace_agriplant_suivi() FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.agriplant_fill_souscripteur() FROM anon, authenticated, PUBLIC;

DROP POLICY IF EXISTS agriplant_files_read ON storage.objects;
CREATE POLICY agriplant_files_read ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'agriplant' AND public.is_staff(auth.uid()));

DROP POLICY IF EXISTS agriplant_files_write ON storage.objects;
CREATE POLICY agriplant_files_write ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'agriplant' AND public.is_staff(auth.uid()));
