-- Consolidation des privilèges Data API
GRANT SELECT, INSERT, UPDATE, DELETE ON public.account_requests TO authenticated;
GRANT INSERT ON public.account_requests TO anon;
GRANT ALL ON public.account_requests TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.leads TO authenticated;
GRANT INSERT ON public.leads TO anon;
GRANT ALL ON public.leads TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.lead_relances TO authenticated;
GRANT ALL ON public.lead_relances TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.activity_notes TO authenticated;
GRANT ALL ON public.activity_notes TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.historique_activites TO authenticated;
GRANT ALL ON public.historique_activites TO service_role;
GRANT SELECT ON public.commissions TO authenticated;
GRANT ALL ON public.commissions TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.souscriptions_brouillon TO authenticated;
GRANT ALL ON public.souscriptions_brouillon TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.documents_souscription TO authenticated;
GRANT ALL ON public.documents_souscription TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.promotions TO authenticated;
GRANT SELECT ON public.promotions TO anon;
GRANT ALL ON public.promotions TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
GRANT SELECT ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;

-- Le rôle ne doit vivre que dans user_roles
ALTER TABLE public.profiles DROP COLUMN IF EXISTS role;

-- Le trigger Auth respecte les identifiants demandés et garde les comptes demandés inactifs
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_username text;
  v_pending boolean;
BEGIN
  v_username := lower(trim(COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1))));
  v_pending := NULLIF(NEW.raw_user_meta_data->>'pending_role', '') IS NOT NULL;

  INSERT INTO public.profiles (id, user_id, email, nom_complet, username, actif)
  VALUES (
    NEW.id,
    NEW.id,
    NEW.email,
    COALESCE(NULLIF(NEW.raw_user_meta_data->>'nom_complet', ''), split_part(NEW.email, '@', 1)),
    v_username,
    NOT v_pending
  )
  ON CONFLICT (id) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    email = EXCLUDED.email,
    nom_complet = EXCLUDED.nom_complet,
    username = EXCLUDED.username,
    actif = CASE WHEN v_pending THEN false ELSE public.profiles.actif END;
  RETURN NEW;
END;
$$;

-- Hiérarchie autorisée à superviser les leads
CREATE OR REPLACE FUNCTION public.can_supervise_leads(_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id
      AND role IN (
        'super_admin','directeur_tc','directeur_technico_commercial',
        'responsable_zone','superviseur_tc','responsable_commercial',
        'chef_equipe','chef_equipe_commercial','service_client'
      )
  )
$$;

-- Attribution serveur immuable à la création dans le CRM
CREATE OR REPLACE FUNCTION public.set_internal_lead_owner()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NOT NULL THEN
    NEW.created_by := auth.uid();
    IF NEW.assigned_to IS NULL OR NOT public.can_supervise_leads(auth.uid()) THEN
      NEW.assigned_to := auth.uid();
    END IF;
    IF NEW.source IS NULL OR NEW.source IN ('formulaire_public','site_web') THEN
      NEW.source := 'commercial_terrain';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_set_internal_lead_owner ON public.leads;
CREATE TRIGGER trg_set_internal_lead_owner
BEFORE INSERT ON public.leads
FOR EACH ROW EXECUTE FUNCTION public.set_internal_lead_owner();

DROP POLICY IF EXISTS "Auth insert leads" ON public.leads;
DROP POLICY IF EXISTS "Staff can manage all leads" ON public.leads;
DROP POLICY IF EXISTS "Staff update leads" ON public.leads;
DROP POLICY IF EXISTS "Staff view leads" ON public.leads;
CREATE POLICY "Authenticated users create owned leads"
ON public.leads FOR INSERT TO authenticated
WITH CHECK (created_by = auth.uid() AND assigned_to = auth.uid());
CREATE POLICY "Owners and supervisors view leads"
ON public.leads FOR SELECT TO authenticated
USING (created_by = auth.uid() OR assigned_to = auth.uid() OR public.can_supervise_leads(auth.uid()));
CREATE POLICY "Owners and supervisors update leads"
ON public.leads FOR UPDATE TO authenticated
USING (assigned_to = auth.uid() OR public.can_supervise_leads(auth.uid()))
WITH CHECK (assigned_to = auth.uid() OR public.can_supervise_leads(auth.uid()));
CREATE POLICY "Supervisors delete leads"
ON public.leads FOR DELETE TO authenticated
USING (public.can_supervise_leads(auth.uid()));

DROP POLICY IF EXISTS "Staff manage relances" ON public.lead_relances;
DROP POLICY IF EXISTS "Staff view relances" ON public.lead_relances;
CREATE POLICY "Lead actors view relances"
ON public.lead_relances FOR SELECT TO authenticated
USING (EXISTS (
  SELECT 1 FROM public.leads l
  WHERE l.id = lead_relances.lead_id
    AND (l.created_by = auth.uid() OR l.assigned_to = auth.uid() OR public.can_supervise_leads(auth.uid()))
));
CREATE POLICY "Lead actors create relances"
ON public.lead_relances FOR INSERT TO authenticated
WITH CHECK (
  commercial_id = auth.uid() AND EXISTS (
    SELECT 1 FROM public.leads l
    WHERE l.id = lead_relances.lead_id
      AND (l.assigned_to = auth.uid() OR public.can_supervise_leads(auth.uid()))
  )
);
CREATE POLICY "Authors and supervisors update relances"
ON public.lead_relances FOR UPDATE TO authenticated
USING (commercial_id = auth.uid() OR public.can_supervise_leads(auth.uid()))
WITH CHECK (commercial_id = auth.uid() OR public.can_supervise_leads(auth.uid()));

-- Notes : tous les comptes métier reconnus par is_staff, avec auteur imposé
DROP POLICY IF EXISTS "Staff create notes" ON public.activity_notes;
CREATE POLICY "Staff create notes"
ON public.activity_notes FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id AND public.is_staff(auth.uid()));

-- Storage privé : chemins historiques acceptés si l'UID est au niveau 1 ou 2
GRANT SELECT, INSERT, UPDATE, DELETE ON storage.objects TO authenticated;
DROP POLICY IF EXISTS "Authenticated upload own business files" ON storage.objects;
DROP POLICY IF EXISTS "Staff read business files" ON storage.objects;
DROP POLICY IF EXISTS "Owners update business files" ON storage.objects;
DROP POLICY IF EXISTS "Owners delete business files" ON storage.objects;
CREATE POLICY "Authenticated upload own business files"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id IN ('documents','documents-fonciers','photos-plantations','photos-profils','pieces-identite','preuves-paiement')
  AND public.is_staff(auth.uid())
  AND (
    (storage.foldername(name))[1] = auth.uid()::text
    OR (storage.foldername(name))[2] = auth.uid()::text
  )
);
CREATE POLICY "Staff read business files"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id IN ('documents','documents-fonciers','photos-plantations','photos-profils','pieces-identite','preuves-paiement')
  AND public.is_staff(auth.uid())
);
CREATE POLICY "Owners update business files"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id IN ('documents','documents-fonciers','photos-plantations','photos-profils','pieces-identite','preuves-paiement')
  AND ((storage.foldername(name))[1] = auth.uid()::text OR (storage.foldername(name))[2] = auth.uid()::text OR public.is_admin(auth.uid()))
)
WITH CHECK (
  bucket_id IN ('documents','documents-fonciers','photos-plantations','photos-profils','pieces-identite','preuves-paiement')
  AND ((storage.foldername(name))[1] = auth.uid()::text OR (storage.foldername(name))[2] = auth.uid()::text OR public.is_admin(auth.uid()))
);
CREATE POLICY "Owners delete business files"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id IN ('documents','documents-fonciers','photos-plantations','photos-profils','pieces-identite','preuves-paiement')
  AND ((storage.foldername(name))[1] = auth.uid()::text OR (storage.foldername(name))[2] = auth.uid()::text OR public.is_admin(auth.uid()))
);