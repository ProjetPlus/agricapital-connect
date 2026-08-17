
-- 1. Table leads
CREATE TABLE IF NOT EXISTS public.leads (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  id_unique TEXT UNIQUE,
  nom TEXT NOT NULL,
  prenoms TEXT NOT NULL,
  telephone TEXT NOT NULL,
  whatsapp TEXT,
  email TEXT,
  region_residence TEXT NOT NULL,
  est_diaspora BOOLEAN NOT NULL DEFAULT false,
  pays_diaspora TEXT,
  dispose_terrain BOOLEAN NOT NULL DEFAULT false,
  superficie_disponible_ha NUMERIC,
  superficie_a_valoriser_ha NUMERIC,
  superficie_souhaitee_ha NUMERIC,
  delai_demarrage TEXT CHECK (delai_demarrage IN ('immediat','3_mois','6_mois','12_mois','plus_tard','rappel')),
  date_contact_souhaitee DATE,
  creneau_prefere TEXT CHECK (creneau_prefere IN ('08_10','10_12','12_14','14_16','16_18')),
  mode_contact_prefere TEXT CHECK (mode_contact_prefere IN ('appel','whatsapp','peu_importe')),
  commentaire TEXT,
  statut TEXT NOT NULL DEFAULT 'nouveau' CHECK (statut IN ('nouveau','contacte','qualifie','en_discussion','preparation_dossier','pret_souscrire','converti','abandonne')),
  source TEXT NOT NULL DEFAULT 'formulaire_public' CHECK (source IN ('formulaire_public','reseaux_sociaux','site_web','commercial_terrain','reference','autre')),
  assigned_to UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  souscripteur_id UUID REFERENCES public.souscripteurs(id) ON DELETE SET NULL,
  converti_at TIMESTAMPTZ,
  prochaine_relance_at DATE,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT ON public.leads TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.leads TO authenticated;
GRANT ALL ON public.leads TO service_role;

ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anon can insert leads" ON public.leads FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Staff view leads" ON public.leads FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()) OR assigned_to = auth.uid() OR created_by = auth.uid());
CREATE POLICY "Auth insert leads" ON public.leads FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Staff update leads" ON public.leads FOR UPDATE TO authenticated
  USING (public.is_staff(auth.uid()) OR assigned_to = auth.uid())
  WITH CHECK (public.is_staff(auth.uid()) OR assigned_to = auth.uid());
CREATE POLICY "Admins delete leads" ON public.leads FOR DELETE TO authenticated
  USING (public.is_admin(auth.uid()));

CREATE TRIGGER trg_leads_updated_at BEFORE UPDATE ON public.leads
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE OR REPLACE FUNCTION public.generate_lead_id()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE seq INTEGER;
BEGIN
  IF NEW.id_unique IS NULL OR NEW.id_unique = '' THEN
    SELECT COALESCE(MAX(CAST(SUBSTRING(id_unique FROM 5) AS INTEGER)), 0) + 1
      INTO seq FROM public.leads WHERE id_unique LIKE 'LEAD%';
    NEW.id_unique := 'LEAD' || LPAD(seq::TEXT, 6, '0');
  END IF;
  RETURN NEW;
END; $$;

CREATE TRIGGER trg_leads_generate_id BEFORE INSERT ON public.leads
  FOR EACH ROW EXECUTE FUNCTION public.generate_lead_id();

-- 2. Table lead_relances
CREATE TABLE IF NOT EXISTS public.lead_relances (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  lead_id UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  commercial_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  date_relance TIMESTAMPTZ NOT NULL DEFAULT now(),
  canal TEXT NOT NULL CHECK (canal IN ('appel','whatsapp','physique','email')),
  resultat TEXT NOT NULL CHECK (resultat IN ('non_joignable','rappel_demande','interesse','tres_interesse','en_reflexion','non_interesse')),
  commentaire TEXT,
  prochaine_relance DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.lead_relances TO authenticated;
GRANT ALL ON public.lead_relances TO service_role;

ALTER TABLE public.lead_relances ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Staff view relances" ON public.lead_relances FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff manage relances" ON public.lead_relances FOR ALL TO authenticated
  USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));

-- 3. Étendre is_staff aux nouveaux rôles
CREATE OR REPLACE FUNCTION public.is_staff(_user_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
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

-- 4. DELETE offres
DROP POLICY IF EXISTS "Admins can delete offres" ON public.offres;
CREATE POLICY "Admins can delete offres" ON public.offres FOR DELETE TO authenticated
  USING (public.is_admin(auth.uid()));

-- 5. Vue prix effectif (utilise 'active', 'offre_ids' jsonb)
CREATE OR REPLACE VIEW public.v_prix_effectif_offres
WITH (security_invoker=on) AS
SELECT
  o.id AS offre_id,
  o.code, o.nom,
  o.montant_depot_initial_par_ha AS di_base,
  o.montant_total_par_ha AS total_base,
  GREATEST(0,
    o.montant_depot_initial_par_ha
    - COALESCE((
        SELECT SUM(COALESCE(p.montant_fixe_reduction,0)
                 + o.montant_depot_initial_par_ha * COALESCE(p.pourcentage_reduction,0) / 100.0)
        FROM public.promotions p
        WHERE p.active = true
          AND p.cible = 'depot_initial'
          AND (p.date_debut IS NULL OR p.date_debut <= now())
          AND (p.date_fin IS NULL OR p.date_fin >= now())
          AND (p.applique_toutes_offres = true OR p.offre_ids ? o.id::text)
      ), 0)
  ) AS di_effectif,
  GREATEST(0,
    o.montant_total_par_ha
    - COALESCE((
        SELECT SUM(COALESCE(p.montant_fixe_reduction,0)
                 + o.montant_total_par_ha * COALESCE(p.pourcentage_reduction,0) / 100.0)
        FROM public.promotions p
        WHERE p.active = true
          AND p.cible IN ('total_contrat','special')
          AND (p.date_debut IS NULL OR p.date_debut <= now())
          AND (p.date_fin IS NULL OR p.date_fin >= now())
          AND (p.applique_toutes_offres = true OR p.offre_ids ? o.id::text)
      ), 0)
  ) AS total_effectif
FROM public.offres o
WHERE o.actif = true;

GRANT SELECT ON public.v_prix_effectif_offres TO anon, authenticated;

-- 6. Recalcul DI en attente
CREATE OR REPLACE FUNCTION public.recompute_pending_di()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r RECORD; v_prix numeric;
BEGIN
  FOR r IN
    SELECT p.id, s.offre_id, s.total_hectares
      FROM public.paiements p
      JOIN public.souscripteurs s ON s.id = p.souscripteur_id
     WHERE p.est_depot_initial = true
       AND p.statut = 'en_attente'
       AND COALESCE(s.compte_actif,false) = false
  LOOP
    SELECT di_effectif INTO v_prix FROM public.v_prix_effectif_offres WHERE offre_id = r.offre_id;
    IF v_prix IS NOT NULL AND COALESCE(r.total_hectares,0) > 0 THEN
      UPDATE public.paiements
         SET montant = v_prix * r.total_hectares,
             montant_theorique = v_prix * r.total_hectares,
             updated_at = now()
       WHERE id = r.id;
    END IF;
  END LOOP;
END; $$;

CREATE OR REPLACE FUNCTION public.trg_recompute_di_on_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM public.recompute_pending_di();
  RETURN NULL;
END; $$;

DROP TRIGGER IF EXISTS trg_offres_recompute ON public.offres;
CREATE TRIGGER trg_offres_recompute
  AFTER UPDATE OF montant_depot_initial_par_ha, montant_total_par_ha ON public.offres
  FOR EACH STATEMENT EXECUTE FUNCTION public.trg_recompute_di_on_change();

DROP TRIGGER IF EXISTS trg_promotions_recompute ON public.promotions;
CREATE TRIGGER trg_promotions_recompute
  AFTER INSERT OR UPDATE OR DELETE ON public.promotions
  FOR EACH STATEMENT EXECUTE FUNCTION public.trg_recompute_di_on_change();

-- 7. Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.leads;
ALTER PUBLICATION supabase_realtime ADD TABLE public.lead_relances;
