
-- 1. Recreate the view with security_invoker (respect RLS of caller)
DROP VIEW IF EXISTS public.v_souscripteur_synthese;
CREATE VIEW public.v_souscripteur_synthese
WITH (security_invoker = true) AS
SELECT
  s.id, s.id_unique, s.nom_complet, s.user_id,
  s.compte_actif, s.contrat_debut_at, s.contrat_fin_at,
  s.mensualite_montant, s.prochaine_echeance,
  COALESCE((SELECT SUM(montant_paye) FROM public.paiements
            WHERE souscripteur_id = s.id AND statut = 'valide'), 0) AS total_paye,
  COALESCE((SELECT SUM(montant_theorique) FROM public.paiements
            WHERE souscripteur_id = s.id AND statut <> 'valide'), 0) AS restant_du,
  (SELECT COUNT(*) FROM public.paiements
   WHERE souscripteur_id = s.id AND type_paiement = 'REDEVANCE' AND statut = 'valide') AS echeances_payees,
  CASE WHEN s.contrat_debut_at IS NOT NULL
       THEN GREATEST(0, (s.contrat_fin_at - current_date)) END AS jours_restants,
  CASE WHEN s.contrat_debut_at IS NOT NULL
       THEN ROUND(((current_date - s.contrat_debut_at)::numeric
                  / NULLIF((s.contrat_fin_at - s.contrat_debut_at), 0)::numeric) * 100, 2)
       ELSE 0 END AS avancement_pct
FROM public.souscripteurs s;

GRANT SELECT ON public.v_souscripteur_synthese TO authenticated, service_role;

-- 2. Lock down EXECUTE on the new SECURITY DEFINER functions
REVOKE ALL ON FUNCTION public.create_depot_initial(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_depot_initial(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.check_docs_and_create_depot() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_docs_and_create_depot() TO service_role;

REVOKE ALL ON FUNCTION public.handle_paiement_valide() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.handle_paiement_valide() TO service_role;
