
REVOKE ALL ON FUNCTION public.recompute_contrat_totaux(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.recompute_contrat_totaux(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.compute_paiement_jours_couverts() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.compute_paiement_jours_couverts() TO service_role;

REVOKE ALL ON FUNCTION public.mark_overdue_payments() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.mark_overdue_payments() TO service_role;
