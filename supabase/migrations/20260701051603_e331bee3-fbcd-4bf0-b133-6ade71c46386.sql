
REVOKE EXECUTE ON FUNCTION public.compute_commission_for_paiement(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_paiement_commission() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.validate_promotion_cible() FROM PUBLIC, anon, authenticated;
