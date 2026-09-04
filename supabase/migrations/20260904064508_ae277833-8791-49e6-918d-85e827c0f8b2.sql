DROP POLICY IF EXISTS "Authenticated users create owned leads" ON public.leads;
CREATE POLICY "Staff create owned leads"
  ON public.leads FOR INSERT TO authenticated
  WITH CHECK (public.is_staff(auth.uid()) AND created_by = auth.uid() AND assigned_to = auth.uid());

REVOKE EXECUTE ON FUNCTION public.guard_profiles_sensitive_insert() FROM PUBLIC, anon, authenticated;