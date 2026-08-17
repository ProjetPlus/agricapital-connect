-- 1. configurations_systeme : lecture réservée au personnel authentifié
DROP POLICY IF EXISTS "config_read_all" ON public.configurations_systeme;
CREATE POLICY "config_read_staff" ON public.configurations_systeme
  FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()));
REVOKE SELECT ON public.configurations_systeme FROM anon;

-- 2. profiles : empêcher l'auto-modification des champs sensibles
CREATE OR REPLACE FUNCTION public.prevent_profile_privilege_escalation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.is_admin(auth.uid()) THEN
    RETURN NEW;
  END IF;

  NEW.taux_commission := OLD.taux_commission;
  NEW.actif           := OLD.actif;
  NEW.equipe_id       := OLD.equipe_id;
  NEW.poste           := OLD.poste;
  NEW.district_id     := OLD.district_id;
  NEW.region_id       := OLD.region_id;
  NEW.user_id         := OLD.user_id;
  NEW.username        := OLD.username;
  NEW.relation_rh     := OLD.relation_rh;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_profile_privilege_escalation ON public.profiles;
CREATE TRIGGER trg_prevent_profile_privilege_escalation
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.prevent_profile_privilege_escalation();

DROP POLICY IF EXISTS "Users update own profile" ON public.profiles;
CREATE POLICY "Users update own profile" ON public.profiles
  FOR UPDATE TO authenticated
  USING ((auth.uid() = user_id) OR public.is_admin(auth.uid()))
  WITH CHECK ((auth.uid() = user_id) OR public.is_admin(auth.uid()));

-- 3. Le compte démo n'est plus du "staff" (plus d'accès aux données internes)
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
        'chef_equipe_commercial','chef_equipe_technique'
      )
  )
$$;

-- 4. Fonctions sensibles : retirer l'exécution aux rôles non authentifiés
DO $$
DECLARE
  fn record;
BEGIN
  FOR fn IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prosecdef
      AND p.proname NOT IN ('username_available', 'resolve_username_email')
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon', fn.sig);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role', fn.sig);
  END LOOP;
END $$;
