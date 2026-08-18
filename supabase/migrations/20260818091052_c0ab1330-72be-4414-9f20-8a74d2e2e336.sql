REVOKE ALL ON FUNCTION public.agriplan_set_numero_client() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.agriplan_set_vente_reference() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.agriplan_set_plantation_numero() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.agriplan_set_visite_numero() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.agriplan_sync_plantation_visites() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.trg_agriplan_paiement() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.agriplan_recompute_vente(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.agriplan_client_owner(uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.agriplan_set_numero_client() TO service_role;
GRANT EXECUTE ON FUNCTION public.agriplan_set_vente_reference() TO service_role;
GRANT EXECUTE ON FUNCTION public.agriplan_set_plantation_numero() TO service_role;
GRANT EXECUTE ON FUNCTION public.agriplan_set_visite_numero() TO service_role;
GRANT EXECUTE ON FUNCTION public.agriplan_sync_plantation_visites() TO service_role;
GRANT EXECUTE ON FUNCTION public.trg_agriplan_paiement() TO service_role;
GRANT EXECUTE ON FUNCTION public.agriplan_recompute_vente(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.agriplan_client_owner(uuid) TO authenticated, service_role;
