DROP POLICY IF EXISTS "Anyone can read offres" ON public.offres;
CREATE POLICY "Authenticated users can read offres"
ON public.offres FOR SELECT
TO authenticated
USING (true);
REVOKE SELECT ON public.offres FROM anon;