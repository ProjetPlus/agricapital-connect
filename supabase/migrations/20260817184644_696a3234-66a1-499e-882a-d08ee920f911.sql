-- 1) Harden is_staff: explicit staff-only role list, never the generic 'user' role
CREATE OR REPLACE FUNCTION public.is_staff(_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id
      AND role <> 'user'
      AND role IN (
        'super_admin','directeur_tc','directeur_technico_commercial',
        'responsable_operations','responsable_zone','superviseur_tc','chef_equipe','comptable',
        'commercial','service_client','operations','agent_terrain','technicien','admin',
        'responsable_commercial','responsable_technique_agronomique',
        'assistant_administratif','assistant','assistante','secretaire','raf',
        'chef_equipe_commercial','chef_equipe_technique','chef_equipe_service_client'
      )
  )
$function$;

-- 2) Revoke blanket EXECUTE on every SECURITY DEFINER function in public
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.prosecdef
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', r.sig);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', r.sig);
  END LOOP;
END $$;

-- 3) Narrow allow-list of functions the client/RLS legitimately needs
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig, p.proname
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'has_role','is_admin','is_staff','is_demo','can_supervise_leads','current_profile_id',
        'reassign_lead','username_available','simuler_paiement_fractionne','get_subscriber_effective_di'
      )
  LOOP
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', r.sig);
  END LOOP;

  -- login flow (username -> email) happens before authentication
  FOR r IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname IN ('resolve_username_email','username_available')
  LOOP
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO anon, authenticated', r.sig);
  END LOOP;
END $$;

-- 4) notify_hierarchy: service_role / triggers only, with a type allow-list guard
CREATE OR REPLACE FUNCTION public.notify_hierarchy(p_type text, p_title text, p_message text, p_data jsonb DEFAULT NULL::jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE v_user RECORD;
BEGIN
  IF p_type IS NULL OR p_type NOT IN (
    'nouvelle_souscription','nouveau_paiement','paiement_valide','paiement_retard',
    'rappel_paiement','nouveau_lead','lead_assigne','nouveau_ticket','ticket_resolu',
    'demande_compte','compte_approuve','suivi_agriplant','systeme'
  ) THEN
    RAISE EXCEPTION 'Type de notification non autorisé';
  END IF;

  IF auth.uid() IS NOT NULL AND NOT public.is_staff(auth.uid()) THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;

  FOR v_user IN
    SELECT DISTINCT ur.user_id FROM public.user_roles ur
    WHERE ur.role IN ('super_admin','directeur_tc','superviseur_tc','chef_equipe','responsable_commercial','chef_equipe_commercial')
  LOOP
    INSERT INTO public.notifications (user_id, type, title, message, data)
    VALUES (v_user.user_id, p_type, p_title, left(p_message, 1000), p_data);
  END LOOP;
END;
$function$;

REVOKE ALL ON FUNCTION public.notify_hierarchy(text,text,text,jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notify_hierarchy(text,text,text,jsonb) TO service_role;