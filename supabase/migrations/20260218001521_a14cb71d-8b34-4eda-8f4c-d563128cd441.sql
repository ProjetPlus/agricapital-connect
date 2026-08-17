
-- Update cascade functions to support bidirectional cascade (activate AND deactivate)

-- District: activate → activate all children, deactivate → deactivate all children
CREATE OR REPLACE FUNCTION public.cascade_district_activation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.est_actif = false AND OLD.est_actif = true THEN
    -- Deactivate all child regions
    UPDATE public.regions SET est_active = false WHERE district_id = NEW.id AND est_active = true;
  END IF;
  IF NEW.est_actif = true AND OLD.est_actif = false THEN
    -- Activate all child regions
    UPDATE public.regions SET est_active = true WHERE district_id = NEW.id AND est_active = false;
  END IF;
  RETURN NEW;
END;
$function$;

-- Region: activate → activate children (if district parent is active), deactivate → deactivate children
CREATE OR REPLACE FUNCTION public.cascade_region_activation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.est_active = false AND OLD.est_active = true THEN
    UPDATE public.departements SET est_actif = false WHERE region_id = NEW.id AND est_actif = true;
  END IF;
  IF NEW.est_active = true AND OLD.est_active = false THEN
    -- Check parent district is active
    IF EXISTS (SELECT 1 FROM public.districts WHERE id = NEW.district_id AND est_actif = false) THEN
      RAISE EXCEPTION 'Impossible d''activer cette région : le district parent est désactivé';
    END IF;
    -- Activate all child departements
    UPDATE public.departements SET est_actif = true WHERE region_id = NEW.id AND est_actif = false;
  END IF;
  RETURN NEW;
END;
$function$;

-- Departement: activate → activate children (if region parent is active), deactivate → deactivate children
CREATE OR REPLACE FUNCTION public.cascade_departement_activation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.est_actif = false AND OLD.est_actif = true THEN
    UPDATE public.sous_prefectures SET est_active = false WHERE departement_id = NEW.id AND est_active = true;
  END IF;
  IF NEW.est_actif = true AND OLD.est_actif = false THEN
    IF EXISTS (SELECT 1 FROM public.regions WHERE id = NEW.region_id AND est_active = false) THEN
      RAISE EXCEPTION 'Impossible d''activer ce département : la région parente est désactivée';
    END IF;
    UPDATE public.sous_prefectures SET est_active = true WHERE departement_id = NEW.id AND est_active = false;
  END IF;
  RETURN NEW;
END;
$function$;

-- Sous-prefecture: activate → activate children (if dept parent is active), deactivate → deactivate children
CREATE OR REPLACE FUNCTION public.cascade_sous_prefecture_activation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.est_active = false AND OLD.est_active = true THEN
    UPDATE public.villages SET est_actif = false WHERE sous_prefecture_id = NEW.id AND est_actif = true;
  END IF;
  IF NEW.est_active = true AND OLD.est_active = false THEN
    IF EXISTS (SELECT 1 FROM public.departements WHERE id = NEW.departement_id AND est_actif = false) THEN
      RAISE EXCEPTION 'Impossible d''activer cette sous-préfecture : le département parent est désactivé';
    END IF;
    UPDATE public.villages SET est_actif = true WHERE sous_prefecture_id = NEW.id AND est_actif = false;
  END IF;
  RETURN NEW;
END;
$function$;

-- Ensure triggers exist (drop and recreate to be safe)
DROP TRIGGER IF EXISTS trigger_cascade_district ON public.districts;
CREATE TRIGGER trigger_cascade_district
  AFTER UPDATE OF est_actif ON public.districts
  FOR EACH ROW
  EXECUTE FUNCTION public.cascade_district_activation();

DROP TRIGGER IF EXISTS trigger_cascade_region ON public.regions;
CREATE TRIGGER trigger_cascade_region
  AFTER UPDATE OF est_active ON public.regions
  FOR EACH ROW
  EXECUTE FUNCTION public.cascade_region_activation();

DROP TRIGGER IF EXISTS trigger_cascade_departement ON public.departements;
CREATE TRIGGER trigger_cascade_departement
  AFTER UPDATE OF est_actif ON public.departements
  FOR EACH ROW
  EXECUTE FUNCTION public.cascade_departement_activation();

DROP TRIGGER IF EXISTS trigger_cascade_sous_prefecture ON public.sous_prefectures;
CREATE TRIGGER trigger_cascade_sous_prefecture
  AFTER UPDATE OF est_active ON public.sous_prefectures
  FOR EACH ROW
  EXECUTE FUNCTION public.cascade_sous_prefecture_activation();
