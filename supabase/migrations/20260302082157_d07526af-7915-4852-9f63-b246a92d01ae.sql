
-- Drop and recreate all triggers to ensure they're correct

DROP TRIGGER IF EXISTS trigger_cascade_district_activation ON public.districts;
DROP TRIGGER IF EXISTS trigger_cascade_region_activation ON public.regions;
DROP TRIGGER IF EXISTS trigger_cascade_departement_activation ON public.departements;
DROP TRIGGER IF EXISTS trigger_cascade_sous_prefecture_activation ON public.sous_prefectures;
DROP TRIGGER IF EXISTS trigger_update_souscripteur_stats ON public.plantations;
DROP TRIGGER IF EXISTS update_souscripteurs_updated_at ON public.souscripteurs;
DROP TRIGGER IF EXISTS update_plantations_updated_at ON public.plantations;
DROP TRIGGER IF EXISTS update_paiements_updated_at ON public.paiements;
DROP TRIGGER IF EXISTS update_offres_updated_at ON public.offres;
DROP TRIGGER IF EXISTS update_equipes_updated_at ON public.equipes;
DROP TRIGGER IF EXISTS update_notifications_updated_at ON public.notifications;

-- CASCADE TRIGGERS
CREATE TRIGGER trigger_cascade_district_activation
  AFTER UPDATE OF est_actif ON public.districts
  FOR EACH ROW
  WHEN (OLD.est_actif IS DISTINCT FROM NEW.est_actif)
  EXECUTE FUNCTION public.cascade_district_activation();

CREATE TRIGGER trigger_cascade_region_activation
  AFTER UPDATE OF est_active ON public.regions
  FOR EACH ROW
  WHEN (OLD.est_active IS DISTINCT FROM NEW.est_active)
  EXECUTE FUNCTION public.cascade_region_activation();

CREATE TRIGGER trigger_cascade_departement_activation
  AFTER UPDATE OF est_actif ON public.departements
  FOR EACH ROW
  WHEN (OLD.est_actif IS DISTINCT FROM NEW.est_actif)
  EXECUTE FUNCTION public.cascade_departement_activation();

CREATE TRIGGER trigger_cascade_sous_prefecture_activation
  AFTER UPDATE OF est_active ON public.sous_prefectures
  FOR EACH ROW
  WHEN (OLD.est_active IS DISTINCT FROM NEW.est_active)
  EXECUTE FUNCTION public.cascade_sous_prefecture_activation();

-- STATS TRIGGER
CREATE TRIGGER trigger_update_souscripteur_stats
  AFTER INSERT OR UPDATE OR DELETE ON public.plantations
  FOR EACH ROW
  EXECUTE FUNCTION public.update_souscripteur_stats();

-- UPDATED_AT TRIGGERS
CREATE TRIGGER update_souscripteurs_updated_at
  BEFORE UPDATE ON public.souscripteurs
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_plantations_updated_at
  BEFORE UPDATE ON public.plantations
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_paiements_updated_at
  BEFORE UPDATE ON public.paiements
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_offres_updated_at
  BEFORE UPDATE ON public.offres
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_equipes_updated_at
  BEFORE UPDATE ON public.equipes
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_notifications_updated_at
  BEFORE UPDATE ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Enable pg_cron and pg_net
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
