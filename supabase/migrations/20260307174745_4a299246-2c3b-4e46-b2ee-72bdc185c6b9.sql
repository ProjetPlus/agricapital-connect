
-- =============================================
-- FIX ALL RLS POLICIES: DROP RESTRICTIVE → RECREATE AS PERMISSIVE
-- =============================================

-- 1. historique_activites: restrict INSERT to authenticated users
DROP POLICY IF EXISTS "Insert history" ON public.historique_activites;
CREATE POLICY "Insert history" ON public.historique_activites
  FOR INSERT TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Staff view history" ON public.historique_activites;
CREATE POLICY "Staff view history" ON public.historique_activites
  FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()));

-- 2. paiements: restrict INSERT to authenticated users
DROP POLICY IF EXISTS "Can insert paiements" ON public.paiements;
CREATE POLICY "Can insert paiements" ON public.paiements
  FOR INSERT TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Staff can view paiements" ON public.paiements;
CREATE POLICY "Staff can view paiements" ON public.paiements
  FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()) OR EXISTS (SELECT 1 FROM public.souscripteurs s WHERE s.id = paiements.souscripteur_id AND s.user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff can update paiements" ON public.paiements;
CREATE POLICY "Staff can update paiements" ON public.paiements
  FOR UPDATE TO authenticated
  USING (public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "Admins can delete paiements" ON public.paiements;
CREATE POLICY "Admins can delete paiements" ON public.paiements
  FOR DELETE TO authenticated
  USING (public.is_admin(auth.uid()));

-- 3. notifications: restrict INSERT to authenticated
DROP POLICY IF EXISTS "System insert notifications" ON public.notifications;
CREATE POLICY "System insert notifications" ON public.notifications
  FOR INSERT TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Users see own notifications" ON public.notifications;
CREATE POLICY "Users see own notifications" ON public.notifications
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users update own notifications" ON public.notifications;
CREATE POLICY "Users update own notifications" ON public.notifications
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id);

-- 4. profiles: restrict INSERT to authenticated
DROP POLICY IF EXISTS "Admins can insert profiles" ON public.profiles;
CREATE POLICY "Admins can insert profiles" ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Authenticated can read profiles" ON public.profiles;
CREATE POLICY "Authenticated can read profiles" ON public.profiles
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Users update own profile" ON public.profiles;
CREATE POLICY "Users update own profile" ON public.profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id OR public.is_admin(auth.uid()));

-- 5. account_requests: keep public INSERT but restrict to anon+authenticated
DROP POLICY IF EXISTS "Anyone can create account request" ON public.account_requests;
CREATE POLICY "Anyone can create account request" ON public.account_requests
  FOR INSERT TO anon, authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Admins view account requests" ON public.account_requests;
CREATE POLICY "Admins view account requests" ON public.account_requests
  FOR SELECT TO authenticated
  USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Admins update account requests" ON public.account_requests;
CREATE POLICY "Admins update account requests" ON public.account_requests
  FOR UPDATE TO authenticated
  USING (public.is_admin(auth.uid()));

-- 6. activity_notes
DROP POLICY IF EXISTS "Staff create notes" ON public.activity_notes;
CREATE POLICY "Staff create notes" ON public.activity_notes
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Staff view notes" ON public.activity_notes;
CREATE POLICY "Staff view notes" ON public.activity_notes
  FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()));

-- 7. commissions
DROP POLICY IF EXISTS "Admins manage commissions" ON public.commissions;
CREATE POLICY "Admins manage commissions" ON public.commissions
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Staff can view own commissions" ON public.commissions;
CREATE POLICY "Staff can view own commissions" ON public.commissions
  FOR SELECT TO authenticated
  USING (public.is_admin(auth.uid()) OR profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()));

-- 8. departements
DROP POLICY IF EXISTS "Admins manage departements" ON public.departements;
CREATE POLICY "Admins manage departements" ON public.departements
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Anyone can read departements" ON public.departements;
CREATE POLICY "Anyone can read departements" ON public.departements
  FOR SELECT TO anon, authenticated
  USING (true);

-- 9. districts
DROP POLICY IF EXISTS "Admins manage districts" ON public.districts;
CREATE POLICY "Admins manage districts" ON public.districts
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Anyone can read districts" ON public.districts;
CREATE POLICY "Anyone can read districts" ON public.districts
  FOR SELECT TO anon, authenticated
  USING (true);

-- 10. equipes
DROP POLICY IF EXISTS "Admins manage equipes" ON public.equipes;
CREATE POLICY "Admins manage equipes" ON public.equipes
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Staff can view equipes" ON public.equipes;
CREATE POLICY "Staff can view equipes" ON public.equipes
  FOR SELECT TO authenticated
  USING (true);

-- 11. offres
DROP POLICY IF EXISTS "Admins manage offres" ON public.offres;
CREATE POLICY "Admins manage offres" ON public.offres
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Anyone can read offres" ON public.offres;
CREATE POLICY "Anyone can read offres" ON public.offres
  FOR SELECT TO anon, authenticated
  USING (true);

-- 12. plantations
DROP POLICY IF EXISTS "Staff can insert plantations" ON public.plantations;
CREATE POLICY "Staff can insert plantations" ON public.plantations
  FOR INSERT TO authenticated
  WITH CHECK (public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "Staff can view plantations" ON public.plantations;
CREATE POLICY "Staff can view plantations" ON public.plantations
  FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()) OR EXISTS (SELECT 1 FROM public.souscripteurs s WHERE s.id = plantations.souscripteur_id AND s.user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff can update plantations" ON public.plantations;
CREATE POLICY "Staff can update plantations" ON public.plantations
  FOR UPDATE TO authenticated
  USING (public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "Admins can delete plantations" ON public.plantations;
CREATE POLICY "Admins can delete plantations" ON public.plantations
  FOR DELETE TO authenticated
  USING (public.is_admin(auth.uid()));

-- 13. portefeuilles
DROP POLICY IF EXISTS "Admins manage portefeuilles" ON public.portefeuilles;
CREATE POLICY "Admins manage portefeuilles" ON public.portefeuilles
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Staff view portefeuilles" ON public.portefeuilles;
CREATE POLICY "Staff view portefeuilles" ON public.portefeuilles
  FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()) OR auth.uid() = user_id);

-- 14. promotions
DROP POLICY IF EXISTS "Admins manage promotions" ON public.promotions;
CREATE POLICY "Admins manage promotions" ON public.promotions
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Anyone can read promotions" ON public.promotions;
CREATE POLICY "Anyone can read promotions" ON public.promotions
  FOR SELECT TO anon, authenticated
  USING (true);

-- 15. rate_limits
DROP POLICY IF EXISTS "Service role manages rate limits" ON public.rate_limits;
CREATE POLICY "Service role manages rate limits" ON public.rate_limits
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

-- 16. regions
DROP POLICY IF EXISTS "Admins manage regions" ON public.regions;
CREATE POLICY "Admins manage regions" ON public.regions
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Anyone can read regions" ON public.regions;
CREATE POLICY "Anyone can read regions" ON public.regions
  FOR SELECT TO anon, authenticated
  USING (true);

-- 17. remboursements
DROP POLICY IF EXISTS "Staff manage remboursements" ON public.remboursements;
CREATE POLICY "Staff manage remboursements" ON public.remboursements
  FOR ALL TO authenticated
  USING (public.is_staff(auth.uid()));

-- 18. retraits_portefeuille
DROP POLICY IF EXISTS "Admins manage retraits" ON public.retraits_portefeuille;
CREATE POLICY "Admins manage retraits" ON public.retraits_portefeuille
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Staff view retraits" ON public.retraits_portefeuille;
CREATE POLICY "Staff view retraits" ON public.retraits_portefeuille
  FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()) OR auth.uid() = user_id);

-- 19. sous_prefectures
DROP POLICY IF EXISTS "Admins manage sous_prefectures" ON public.sous_prefectures;
CREATE POLICY "Admins manage sous_prefectures" ON public.sous_prefectures
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Anyone can read sous_prefectures" ON public.sous_prefectures;
CREATE POLICY "Anyone can read sous_prefectures" ON public.sous_prefectures
  FOR SELECT TO anon, authenticated
  USING (true);

-- 20. souscripteurs
DROP POLICY IF EXISTS "Staff can insert souscripteurs" ON public.souscripteurs;
CREATE POLICY "Staff can insert souscripteurs" ON public.souscripteurs
  FOR INSERT TO authenticated
  WITH CHECK (public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "Staff can view souscripteurs" ON public.souscripteurs;
CREATE POLICY "Staff can view souscripteurs" ON public.souscripteurs
  FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()) OR auth.uid() = user_id);

DROP POLICY IF EXISTS "Staff can update souscripteurs" ON public.souscripteurs;
CREATE POLICY "Staff can update souscripteurs" ON public.souscripteurs
  FOR UPDATE TO authenticated
  USING (public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "Admins can delete souscripteurs" ON public.souscripteurs;
CREATE POLICY "Admins can delete souscripteurs" ON public.souscripteurs
  FOR DELETE TO authenticated
  USING (public.is_admin(auth.uid()));

-- 21. tickets_techniques
DROP POLICY IF EXISTS "Staff manage tickets" ON public.tickets_techniques;
CREATE POLICY "Staff manage tickets" ON public.tickets_techniques
  FOR ALL TO authenticated
  USING (public.is_staff(auth.uid()));

-- 22. transferts_paiements
DROP POLICY IF EXISTS "Staff manage transferts" ON public.transferts_paiements;
CREATE POLICY "Staff manage transferts" ON public.transferts_paiements
  FOR ALL TO authenticated
  USING (public.is_staff(auth.uid()));

-- 23. user_roles
DROP POLICY IF EXISTS "Authenticated can read roles" ON public.user_roles;
CREATE POLICY "Authenticated can read roles" ON public.user_roles
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Service role can manage roles" ON public.user_roles;
CREATE POLICY "Service role can manage roles" ON public.user_roles
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

-- 24. villages
DROP POLICY IF EXISTS "Admins manage villages" ON public.villages;
CREATE POLICY "Admins manage villages" ON public.villages
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Anyone can read villages" ON public.villages;
CREATE POLICY "Anyone can read villages" ON public.villages
  FOR SELECT TO anon, authenticated
  USING (true);

-- =============================================
-- ENSURE ALL TRIGGERS EXIST for cascade activation
-- =============================================
DROP TRIGGER IF EXISTS trigger_cascade_district ON public.districts;
CREATE TRIGGER trigger_cascade_district
  AFTER UPDATE OF est_actif ON public.districts
  FOR EACH ROW
  WHEN (OLD.est_actif IS DISTINCT FROM NEW.est_actif)
  EXECUTE FUNCTION public.cascade_district_activation();

DROP TRIGGER IF EXISTS trigger_cascade_region ON public.regions;
CREATE TRIGGER trigger_cascade_region
  AFTER UPDATE OF est_active ON public.regions
  FOR EACH ROW
  WHEN (OLD.est_active IS DISTINCT FROM NEW.est_active)
  EXECUTE FUNCTION public.cascade_region_activation();

DROP TRIGGER IF EXISTS trigger_cascade_departement ON public.departements;
CREATE TRIGGER trigger_cascade_departement
  AFTER UPDATE OF est_actif ON public.departements
  FOR EACH ROW
  WHEN (OLD.est_actif IS DISTINCT FROM NEW.est_actif)
  EXECUTE FUNCTION public.cascade_departement_activation();

DROP TRIGGER IF EXISTS trigger_cascade_sous_prefecture ON public.sous_prefectures;
CREATE TRIGGER trigger_cascade_sous_prefecture
  AFTER UPDATE OF est_active ON public.sous_prefectures
  FOR EACH ROW
  WHEN (OLD.est_active IS DISTINCT FROM NEW.est_active)
  EXECUTE FUNCTION public.cascade_sous_prefecture_activation();

-- Ensure update_souscripteur_stats trigger exists
DROP TRIGGER IF EXISTS trigger_update_souscripteur_stats ON public.plantations;
CREATE TRIGGER trigger_update_souscripteur_stats
  AFTER INSERT OR UPDATE OR DELETE ON public.plantations
  FOR EACH ROW
  EXECUTE FUNCTION public.update_souscripteur_stats();

-- Ensure validate_paiement trigger exists
DROP TRIGGER IF EXISTS trigger_validate_paiement ON public.paiements;
CREATE TRIGGER trigger_validate_paiement
  BEFORE INSERT OR UPDATE ON public.paiements
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_paiement();

-- Ensure validate_plantation trigger exists
DROP TRIGGER IF EXISTS trigger_validate_plantation ON public.plantations;
CREATE TRIGGER trigger_validate_plantation
  BEFORE INSERT OR UPDATE ON public.plantations
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_plantation();

-- Ensure updated_at triggers exist on all relevant tables
DROP TRIGGER IF EXISTS trigger_updated_at_profiles ON public.profiles;
CREATE TRIGGER trigger_updated_at_profiles BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_updated_at_souscripteurs ON public.souscripteurs;
CREATE TRIGGER trigger_updated_at_souscripteurs BEFORE UPDATE ON public.souscripteurs FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_updated_at_plantations ON public.plantations;
CREATE TRIGGER trigger_updated_at_plantations BEFORE UPDATE ON public.plantations FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_updated_at_paiements ON public.paiements;
CREATE TRIGGER trigger_updated_at_paiements BEFORE UPDATE ON public.paiements FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_updated_at_offres ON public.offres;
CREATE TRIGGER trigger_updated_at_offres BEFORE UPDATE ON public.offres FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_updated_at_equipes ON public.equipes;
CREATE TRIGGER trigger_updated_at_equipes BEFORE UPDATE ON public.equipes FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_updated_at_notifications ON public.notifications;
CREATE TRIGGER trigger_updated_at_notifications BEFORE UPDATE ON public.notifications FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_updated_at_promotions ON public.promotions;
CREATE TRIGGER trigger_updated_at_promotions BEFORE UPDATE ON public.promotions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_updated_at_tickets ON public.tickets_techniques;
CREATE TRIGGER trigger_updated_at_tickets BEFORE UPDATE ON public.tickets_techniques FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_updated_at_account_requests ON public.account_requests;
CREATE TRIGGER trigger_updated_at_account_requests BEFORE UPDATE ON public.account_requests FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
