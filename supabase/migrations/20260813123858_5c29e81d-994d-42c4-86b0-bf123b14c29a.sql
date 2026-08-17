-- 1) Domaines: lecture réservée au personnel
DROP POLICY IF EXISTS "Anyone authenticated reads domaines" ON public.domaines;
CREATE POLICY "Staff read domaines" ON public.domaines
  FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()));

-- 2) zone_assignments: policies limitées au rôle authenticated
DROP POLICY IF EXISTS "Admins manage zone_assignments" ON public.zone_assignments;
DROP POLICY IF EXISTS "Staff read zone_assignments" ON public.zone_assignments;
CREATE POLICY "Admins manage zone_assignments" ON public.zone_assignments
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));
CREATE POLICY "Staff read zone_assignments" ON public.zone_assignments
  FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()));

-- 3) Fonctions SECURITY DEFINER: plus aucune exécution par les visiteurs anonymes
REVOKE EXECUTE ON FUNCTION public.resolve_username_email(TEXT) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.username_available(TEXT) FROM anon, authenticated, PUBLIC;
GRANT EXECUTE ON FUNCTION public.resolve_username_email(TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.username_available(TEXT) TO service_role;