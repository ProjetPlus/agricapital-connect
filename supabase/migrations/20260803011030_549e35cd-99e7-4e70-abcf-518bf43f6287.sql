-- 1. Promotions: autoriser la cible "special"
ALTER TABLE public.promotions DROP CONSTRAINT IF EXISTS promotions_cible_check;
ALTER TABLE public.promotions
  ADD CONSTRAINT promotions_cible_check
  CHECK (cible = ANY (ARRAY['depot_initial'::text, 'total_contrat'::text, 'special'::text]));
ALTER TABLE public.promotions ALTER COLUMN pourcentage_reduction SET DEFAULT 0;
ALTER TABLE public.promotions ALTER COLUMN pourcentage_reduction DROP NOT NULL;

-- 2. account_requests: username + compte auth pré-créé
ALTER TABLE public.account_requests ADD COLUMN IF NOT EXISTS username TEXT;
ALTER TABLE public.account_requests ADD COLUMN IF NOT EXISTS auth_user_id UUID;
CREATE UNIQUE INDEX IF NOT EXISTS account_requests_username_uidx
  ON public.account_requests (lower(username)) WHERE username IS NOT NULL;

DROP POLICY IF EXISTS "Admins delete account requests" ON public.account_requests;
CREATE POLICY "Admins delete account requests"
  ON public.account_requests FOR DELETE TO authenticated
  USING (public.is_admin(auth.uid()));

-- 3. Unicité des usernames de profils
CREATE UNIQUE INDEX IF NOT EXISTS profiles_username_uidx
  ON public.profiles (lower(username)) WHERE username IS NOT NULL AND username <> '';

-- 4. Résolution username -> email avant connexion (accessible anon)
CREATE OR REPLACE FUNCTION public.resolve_username_email(_username TEXT)
RETURNS TEXT
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT email FROM public.profiles
   WHERE lower(username) = lower(trim(_username))
     AND email IS NOT NULL
   LIMIT 1
$$;
REVOKE ALL ON FUNCTION public.resolve_username_email(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.resolve_username_email(TEXT) TO anon, authenticated;

-- Vérifier la disponibilité d'un username (formulaire de demande)
CREATE OR REPLACE FUNCTION public.username_available(_username TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE lower(username) = lower(trim(_username))
    UNION ALL
    SELECT 1 FROM public.account_requests
     WHERE lower(username) = lower(trim(_username)) AND statut <> 'rejete'
  )
$$;
REVOKE ALL ON FUNCTION public.username_available(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.username_available(TEXT) TO anon, authenticated;

-- 5. Username "admin" pour le super admin existant
UPDATE public.profiles p
   SET username = 'admin'
 WHERE lower(p.email) = 'admin@agricapital.ci'
   AND NOT EXISTS (SELECT 1 FROM public.profiles x WHERE lower(x.username) = 'admin' AND x.id <> p.id);

-- 6. Compte démo lecture seule
CREATE OR REPLACE FUNCTION public.is_demo(_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = 'demo')
$$;

CREATE OR REPLACE FUNCTION public.is_staff(_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id
      AND role IN (
        'super_admin','directeur_tc','directeur_technico_commercial',
        'responsable_zone','superviseur_tc','chef_equipe','comptable',
        'commercial','service_client','operations','agent_terrain','technicien','admin',
        'responsable_commercial','responsable_technique_agronomique',
        'chef_equipe_commercial','chef_equipe_technique','demo'
      )
  )
$$;

CREATE OR REPLACE FUNCTION public.block_demo_writes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND public.is_demo(auth.uid()) THEN
    RAISE EXCEPTION 'Compte démonstration : accès en lecture seule' USING ERRCODE = '42501';
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'souscripteurs','proprietaires_terres','parcelles','plantations','paiements',
    'leads','lead_relances','offres','promotions','profiles','user_roles','equipes',
    'zone_assignments','documents_souscription','documents_convention',
    'conventions_foncieres','lots_hectares','commissions','tickets_techniques',
    'account_requests','remboursements','retraits_portefeuille','grille_remuneration'
  ]
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_block_demo_writes ON public.%I', t);
    EXECUTE format(
      'CREATE TRIGGER trg_block_demo_writes BEFORE INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.block_demo_writes()', t);
  END LOOP;
END $$;