REVOKE EXECUTE ON FUNCTION public.verifier_carte(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.verifier_carte(text) TO service_role;