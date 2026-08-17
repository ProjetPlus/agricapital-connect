
-- Permettre aux admins de gérer les rôles utilisateurs depuis le CRM (admin policies)
DROP POLICY IF EXISTS "Admins insert user_roles" ON public.user_roles;
DROP POLICY IF EXISTS "Admins update user_roles" ON public.user_roles;
DROP POLICY IF EXISTS "Admins delete user_roles" ON public.user_roles;
DROP POLICY IF EXISTS "Admins view all user_roles" ON public.user_roles;

CREATE POLICY "Admins view all user_roles" ON public.user_roles
  FOR SELECT TO authenticated USING (public.is_admin(auth.uid()));
CREATE POLICY "Admins insert user_roles" ON public.user_roles
  FOR INSERT TO authenticated WITH CHECK (public.is_admin(auth.uid()));
CREATE POLICY "Admins update user_roles" ON public.user_roles
  FOR UPDATE TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));
CREATE POLICY "Admins delete user_roles" ON public.user_roles
  FOR DELETE TO authenticated USING (public.is_admin(auth.uid()));

-- Les anciennes policies "Deny authenticated ..." bloquent les admins. On les supprime
-- car les policies admin ci-dessus sont permissives et chacun voit ses propres rôles via la policy existante.
DROP POLICY IF EXISTS "Deny authenticated delete user_roles" ON public.user_roles;
DROP POLICY IF EXISTS "Deny authenticated insert user_roles" ON public.user_roles;
DROP POLICY IF EXISTS "Deny authenticated update user_roles" ON public.user_roles;

-- Corriger is_admin / is_staff / has_role : retirer la contrainte _user_id = auth.uid()
-- qui empêche de vérifier le rôle d'un autre utilisateur (ex: dans triggers / vues).
CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role text)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role)
$$;

CREATE OR REPLACE FUNCTION public.is_admin(_user_id uuid)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id
      AND role IN ('super_admin', 'directeur_tc', 'directeur_technico_commercial')
  )
$$;

CREATE OR REPLACE FUNCTION public.is_staff(_user_id uuid)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id
      AND role IN (
        'super_admin','directeur_tc','directeur_technico_commercial',
        'responsable_zone','superviseur_tc','chef_equipe','comptable',
        'commercial','service_client','operations','agent_terrain','technicien','admin'
      )
  )
$$;

-- Trigger pour auto-création de profil à l'inscription
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
BEGIN
  INSERT INTO public.profiles (id, user_id, email, nom_complet, username, actif)
  VALUES (
    NEW.id, NEW.id, NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'nom_complet', split_part(NEW.email,'@',1)),
    split_part(NEW.email,'@',1), true
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
