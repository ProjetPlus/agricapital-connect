-- 1. admin_audit_logs : seul le staff peut insérer
DROP POLICY IF EXISTS "authenticated write audit" ON public.admin_audit_logs;
CREATE POLICY "staff write audit"
  ON public.admin_audit_logs FOR INSERT TO authenticated
  WITH CHECK (
    public.is_staff(auth.uid())
    AND (acteur_user_id IS NULL OR acteur_user_id = auth.uid())
  );

-- 2. agriplan_offre : lecture réservée aux utilisateurs connectés
DROP POLICY IF EXISTS "agriplan_offre_read" ON public.agriplan_offre;
REVOKE SELECT ON public.agriplan_offre FROM anon;
GRANT SELECT ON public.agriplan_offre TO authenticated;
CREATE POLICY "agriplan_offre_read"
  ON public.agriplan_offre FOR SELECT TO authenticated
  USING (true);

-- 3. Fonctions SECURITY DEFINER : retirer l'accès anon
REVOKE EXECUTE ON FUNCTION public.resolve_username_email(text) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.username_available(text) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.agriplan_mon_client_id() FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.offre_prix_effectif() FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.agriplan_recompute_vente(uuid) FROM anon, authenticated, PUBLIC;

GRANT EXECUTE ON FUNCTION public.resolve_username_email(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.username_available(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.offre_prix_effectif() TO service_role;
GRANT EXECUTE ON FUNCTION public.agriplan_recompute_vente(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.agriplan_mon_client_id() TO authenticated, service_role;