-- Grant EXECUTE on security definer functions to authenticated and anon
-- This fixes "permission denied for function is_staff" errors blocking all RLS-protected reads/writes

GRANT EXECUTE ON FUNCTION public.is_staff(uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.is_admin(uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.current_profile_id() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.generate_souscripteur_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_plantation_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_parcelle_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_proprietaire_id() TO authenticated;