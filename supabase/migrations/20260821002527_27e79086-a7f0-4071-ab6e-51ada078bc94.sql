REVOKE EXECUTE ON FUNCTION public.get_subscriber_effective_di(uuid) FROM anon, authenticated, PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_subscriber_effective_di(uuid) TO service_role;