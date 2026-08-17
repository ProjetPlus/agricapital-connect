
-- 1. Create zone_assignments table for RCom/Chef/Commercial zone mapping
CREATE TABLE IF NOT EXISTS public.zone_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  zone_type TEXT NOT NULL CHECK (zone_type IN ('district', 'region', 'departement', 'sous_prefecture')),
  zone_id UUID NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  created_by UUID,
  UNIQUE(user_id, zone_type, zone_id)
);

ALTER TABLE public.zone_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins manage zone_assignments" ON public.zone_assignments FOR ALL USING (public.is_admin(auth.uid()));
CREATE POLICY "Staff read zone_assignments" ON public.zone_assignments FOR SELECT USING (public.is_staff(auth.uid()));

-- 2. Restrict INSERT policies: historique_activites, paiements, notifications, profiles
-- Drop old permissive INSERT policies and recreate with auth check
DROP POLICY IF EXISTS "Insert history" ON public.historique_activites;
CREATE POLICY "Authenticated insert history" ON public.historique_activites FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Can insert paiements" ON public.paiements;
CREATE POLICY "Authenticated insert paiements" ON public.paiements FOR INSERT TO authenticated WITH CHECK (public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "System insert notifications" ON public.notifications;
CREATE POLICY "Authenticated insert notifications" ON public.notifications FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Admins can insert profiles" ON public.profiles;
CREATE POLICY "Authenticated insert profiles" ON public.profiles FOR INSERT TO authenticated WITH CHECK (true);

-- 3. Create triggers for cascade activation (ensure they exist)
DROP TRIGGER IF EXISTS trigger_cascade_district ON public.districts;
CREATE TRIGGER trigger_cascade_district AFTER UPDATE OF est_actif ON public.districts
  FOR EACH ROW EXECUTE FUNCTION public.cascade_district_activation();

DROP TRIGGER IF EXISTS trigger_cascade_region ON public.regions;
CREATE TRIGGER trigger_cascade_region AFTER UPDATE OF est_active ON public.regions
  FOR EACH ROW EXECUTE FUNCTION public.cascade_region_activation();

DROP TRIGGER IF EXISTS trigger_cascade_departement ON public.departements;
CREATE TRIGGER trigger_cascade_departement AFTER UPDATE OF est_actif ON public.departements
  FOR EACH ROW EXECUTE FUNCTION public.cascade_departement_activation();

DROP TRIGGER IF EXISTS trigger_cascade_sous_prefecture ON public.sous_prefectures;
CREATE TRIGGER trigger_cascade_sous_prefecture AFTER UPDATE OF est_active ON public.sous_prefectures
  FOR EACH ROW EXECUTE FUNCTION public.cascade_sous_prefecture_activation();

-- 4. Triggers for validation and stats
DROP TRIGGER IF EXISTS trigger_validate_paiement ON public.paiements;
CREATE TRIGGER trigger_validate_paiement BEFORE INSERT OR UPDATE ON public.paiements
  FOR EACH ROW EXECUTE FUNCTION public.validate_paiement();

DROP TRIGGER IF EXISTS trigger_validate_plantation ON public.plantations;
CREATE TRIGGER trigger_validate_plantation BEFORE INSERT OR UPDATE ON public.plantations
  FOR EACH ROW EXECUTE FUNCTION public.validate_plantation();

DROP TRIGGER IF EXISTS trigger_update_souscripteur_stats ON public.plantations;
CREATE TRIGGER trigger_update_souscripteur_stats AFTER INSERT OR UPDATE OR DELETE ON public.plantations
  FOR EACH ROW EXECUTE FUNCTION public.update_souscripteur_stats();

-- 5. Updated_at triggers
DROP TRIGGER IF EXISTS trigger_updated_at_profiles ON public.profiles;
CREATE TRIGGER trigger_updated_at_profiles BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_updated_at_souscripteurs ON public.souscripteurs;
CREATE TRIGGER trigger_updated_at_souscripteurs BEFORE UPDATE ON public.souscripteurs
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_updated_at_plantations ON public.plantations;
CREATE TRIGGER trigger_updated_at_plantations BEFORE UPDATE ON public.plantations
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_updated_at_paiements ON public.paiements;
CREATE TRIGGER trigger_updated_at_paiements BEFORE UPDATE ON public.paiements
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_updated_at_equipes ON public.equipes;
CREATE TRIGGER trigger_updated_at_equipes BEFORE UPDATE ON public.equipes
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
