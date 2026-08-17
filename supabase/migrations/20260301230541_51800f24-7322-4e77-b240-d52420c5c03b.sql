
-- Create triggers for cascade activation/deactivation
-- These triggers were missing - functions existed but weren't attached

-- 1. District -> Regions cascade
CREATE OR REPLACE TRIGGER trigger_cascade_district_activation
  AFTER UPDATE OF est_actif ON public.districts
  FOR EACH ROW
  WHEN (OLD.est_actif IS DISTINCT FROM NEW.est_actif)
  EXECUTE FUNCTION public.cascade_district_activation();

-- 2. Region -> Departements cascade
CREATE OR REPLACE TRIGGER trigger_cascade_region_activation
  AFTER UPDATE OF est_active ON public.regions
  FOR EACH ROW
  WHEN (OLD.est_active IS DISTINCT FROM NEW.est_active)
  EXECUTE FUNCTION public.cascade_region_activation();

-- 3. Departement -> Sous-prefectures cascade
CREATE OR REPLACE TRIGGER trigger_cascade_departement_activation
  AFTER UPDATE OF est_actif ON public.departements
  FOR EACH ROW
  WHEN (OLD.est_actif IS DISTINCT FROM NEW.est_actif)
  EXECUTE FUNCTION public.cascade_departement_activation();

-- 4. Sous-prefecture -> Villages cascade
CREATE OR REPLACE TRIGGER trigger_cascade_sous_prefecture_activation
  AFTER UPDATE OF est_active ON public.sous_prefectures
  FOR EACH ROW
  WHEN (OLD.est_active IS DISTINCT FROM NEW.est_active)
  EXECUTE FUNCTION public.cascade_sous_prefecture_activation();
