
-- Fix historique_activites INSERT
DROP POLICY IF EXISTS "Authenticated insert history" ON public.historique_activites;
CREATE POLICY "Authenticated insert history" ON public.historique_activites
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

-- Fix notifications INSERT  
DROP POLICY IF EXISTS "Authenticated insert notifications" ON public.notifications;
CREATE POLICY "Authenticated insert notifications" ON public.notifications
  FOR INSERT TO authenticated WITH CHECK (is_staff(auth.uid()) OR auth.uid() = user_id);

-- Fix profiles INSERT
DROP POLICY IF EXISTS "Authenticated insert profiles" ON public.profiles;
CREATE POLICY "Authenticated insert profiles" ON public.profiles
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id OR is_admin(auth.uid()));

-- Fix otp_codes - restrict to service_role only
DROP POLICY IF EXISTS "Service role manages OTP" ON public.otp_codes;
CREATE POLICY "Service role manages OTP" ON public.otp_codes
  FOR ALL TO service_role USING (true) WITH CHECK (true);
