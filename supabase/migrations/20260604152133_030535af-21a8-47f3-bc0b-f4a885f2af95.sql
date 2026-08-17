-- Generate IDs automatically from database triggers instead of exposing RPC helpers
DROP TRIGGER IF EXISTS trg_set_generated_ids_souscripteurs ON public.souscripteurs;
CREATE TRIGGER trg_set_generated_ids_souscripteurs
BEFORE INSERT ON public.souscripteurs
FOR EACH ROW EXECUTE FUNCTION public.set_generated_ids();

DROP TRIGGER IF EXISTS trg_set_generated_ids_proprietaires ON public.proprietaires_terres;
CREATE TRIGGER trg_set_generated_ids_proprietaires
BEFORE INSERT ON public.proprietaires_terres
FOR EACH ROW EXECUTE FUNCTION public.set_generated_ids();

DROP TRIGGER IF EXISTS trg_set_generated_ids_parcelles ON public.parcelles;
CREATE TRIGGER trg_set_generated_ids_parcelles
BEFORE INSERT ON public.parcelles
FOR EACH ROW EXECUTE FUNCTION public.set_generated_ids();

DROP TRIGGER IF EXISTS trg_set_generated_ids_plantations ON public.plantations;
CREATE TRIGGER trg_set_generated_ids_plantations
BEFORE INSERT ON public.plantations
FOR EACH ROW EXECUTE FUNCTION public.set_generated_ids();

-- Keep update timestamps consistent on V3 tables
DROP TRIGGER IF EXISTS trg_update_proprietaires_terres_updated_at ON public.proprietaires_terres;
CREATE TRIGGER trg_update_proprietaires_terres_updated_at
BEFORE UPDATE ON public.proprietaires_terres
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trg_update_parcelles_updated_at ON public.parcelles;
CREATE TRIGGER trg_update_parcelles_updated_at
BEFORE UPDATE ON public.parcelles
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trg_update_conventions_foncieres_updated_at ON public.conventions_foncieres;
CREATE TRIGGER trg_update_conventions_foncieres_updated_at
BEFORE UPDATE ON public.conventions_foncieres
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trg_update_documents_convention_updated_at ON public.documents_convention;
CREATE TRIGGER trg_update_documents_convention_updated_at
BEFORE UPDATE ON public.documents_convention
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trg_update_lots_hectares_updated_at ON public.lots_hectares;
CREATE TRIGGER trg_update_lots_hectares_updated_at
BEFORE UPDATE ON public.lots_hectares
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Remove direct API execution on internal SECURITY DEFINER functions.
-- Triggers can still execute them internally.
REVOKE EXECUTE ON FUNCTION public.assign_sp_code(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.current_profile_id() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.enforce_souscripteur_refund_update() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.generate_convention_reference() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.generate_numero_contrat_souscripteur() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.generate_parcelle_id() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.generate_plantation_id() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.generate_proprietaire_id() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.generate_souscripteur_id() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.rate_limit_account_requests() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.set_domaine_code() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.set_generated_ids() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.set_lot_reference() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.set_parcelle_code() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.validate_documents_convention_file() FROM PUBLIC, anon, authenticated;

-- Role-checking functions remain unavailable to anon; authenticated access is required by RLS policy evaluation.
REVOKE EXECUTE ON FUNCTION public.has_role(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.is_admin(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.is_staff(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_staff(uuid) TO authenticated;