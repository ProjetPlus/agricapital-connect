
-- ====================================================================
-- MIGRATION COMPLÈTE AGRICAPITAL CRM - PHASE 1: Tables de base
-- ====================================================================

-- 1. TABLE: user_roles (doit être créée EN PREMIER)
CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, role)
);

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
CREATE INDEX idx_user_roles_user_id ON public.user_roles(user_id);
CREATE INDEX idx_user_roles_role ON public.user_roles(role);

-- Politique temporaire permissive (sera affinée plus tard)
CREATE POLICY "Authenticated can read roles" ON public.user_roles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Service role can manage roles" ON public.user_roles FOR ALL USING (true);

-- 2. FONCTIONS DE VÉRIFICATION DE RÔLE
CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role)
$$;

CREATE OR REPLACE FUNCTION public.is_admin(_user_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role IN ('super_admin', 'directeur_technico_commercial'))
$$;

CREATE OR REPLACE FUNCTION public.is_staff(_user_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role != 'souscripteur')
$$;

-- 3. TABLE: profiles
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  nom_complet TEXT NOT NULL,
  email TEXT,
  telephone TEXT,
  photo_url TEXT,
  username TEXT UNIQUE,
  equipe_id UUID,
  actif BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated can read profiles" ON public.profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users update own profile" ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = user_id OR public.is_admin(auth.uid()));
CREATE POLICY "Admins can insert profiles" ON public.profiles FOR INSERT WITH CHECK (true);
CREATE INDEX idx_profiles_user_id ON public.profiles(user_id);
CREATE INDEX idx_profiles_email ON public.profiles(email);
CREATE INDEX idx_profiles_equipe ON public.profiles(equipe_id);

-- 4. TABLES GÉOGRAPHIQUES
CREATE TABLE public.districts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nom TEXT NOT NULL UNIQUE,
  code TEXT UNIQUE,
  est_actif BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.districts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read districts" ON public.districts FOR SELECT USING (true);
CREATE POLICY "Admins manage districts" ON public.districts FOR ALL TO authenticated USING (public.is_admin(auth.uid()));

CREATE TABLE public.regions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nom TEXT NOT NULL,
  code TEXT,
  district_id UUID REFERENCES public.districts(id) ON DELETE SET NULL,
  est_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(nom, district_id)
);
ALTER TABLE public.regions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read regions" ON public.regions FOR SELECT USING (true);
CREATE POLICY "Admins manage regions" ON public.regions FOR ALL TO authenticated USING (public.is_admin(auth.uid()));
CREATE INDEX idx_regions_district ON public.regions(district_id);

CREATE TABLE public.departements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nom TEXT NOT NULL,
  code TEXT,
  region_id UUID REFERENCES public.regions(id) ON DELETE SET NULL,
  est_actif BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(nom, region_id)
);
ALTER TABLE public.departements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read departements" ON public.departements FOR SELECT USING (true);
CREATE POLICY "Admins manage departements" ON public.departements FOR ALL TO authenticated USING (public.is_admin(auth.uid()));
CREATE INDEX idx_departements_region ON public.departements(region_id);

CREATE TABLE public.sous_prefectures (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nom TEXT NOT NULL,
  code TEXT,
  departement_id UUID REFERENCES public.departements(id) ON DELETE SET NULL,
  est_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(nom, departement_id)
);
ALTER TABLE public.sous_prefectures ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read sous_prefectures" ON public.sous_prefectures FOR SELECT USING (true);
CREATE POLICY "Admins manage sous_prefectures" ON public.sous_prefectures FOR ALL TO authenticated USING (public.is_admin(auth.uid()));
CREATE INDEX idx_sous_prefectures_dept ON public.sous_prefectures(departement_id);

-- 5. TABLE: equipes
CREATE TABLE public.equipes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nom TEXT NOT NULL,
  responsable_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  region_id UUID REFERENCES public.regions(id) ON DELETE SET NULL,
  actif BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.equipes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can view equipes" ON public.equipes FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins manage equipes" ON public.equipes FOR ALL TO authenticated USING (public.is_admin(auth.uid()));
CREATE INDEX idx_equipes_responsable ON public.equipes(responsable_id);
CREATE INDEX idx_equipes_region ON public.equipes(region_id);

ALTER TABLE public.profiles ADD CONSTRAINT fk_profiles_equipe FOREIGN KEY (equipe_id) REFERENCES public.equipes(id) ON DELETE SET NULL;

-- 6. TABLE: offres
CREATE TABLE public.offres (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  nom TEXT NOT NULL,
  description TEXT,
  montant_da_par_ha NUMERIC NOT NULL DEFAULT 0,
  contribution_mensuelle_par_ha NUMERIC NOT NULL DEFAULT 0,
  couleur TEXT,
  avantages JSONB DEFAULT '[]'::jsonb,
  actif BOOLEAN DEFAULT true,
  ordre INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.offres ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read offres" ON public.offres FOR SELECT USING (true);
CREATE POLICY "Admins manage offres" ON public.offres FOR ALL TO authenticated USING (public.is_admin(auth.uid()));

-- 7. TABLE: promotions
CREATE TABLE public.promotions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nom TEXT NOT NULL,
  description TEXT,
  pourcentage_reduction INTEGER NOT NULL DEFAULT 0,
  date_debut TIMESTAMPTZ NOT NULL,
  date_fin TIMESTAMPTZ NOT NULL,
  active BOOLEAN DEFAULT true,
  applique_toutes_offres BOOLEAN DEFAULT true,
  offre_ids JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read promotions" ON public.promotions FOR SELECT USING (true);
CREATE POLICY "Admins manage promotions" ON public.promotions FOR ALL TO authenticated USING (public.is_admin(auth.uid()));

-- 8. TABLE: souscripteurs
CREATE TABLE public.souscripteurs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  id_unique TEXT UNIQUE,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  civilite TEXT,
  nom_famille TEXT,
  prenoms TEXT,
  nom_complet TEXT,
  nom TEXT,
  date_naissance DATE,
  lieu_naissance TEXT,
  statut_marital TEXT,
  type_piece TEXT,
  numero_piece TEXT,
  date_delivrance_piece DATE,
  telephone TEXT NOT NULL,
  whatsapp TEXT,
  email TEXT,
  domicile TEXT,
  domicile_residence TEXT,
  district_id UUID REFERENCES public.districts(id),
  region_id UUID REFERENCES public.regions(id),
  departement_id UUID REFERENCES public.departements(id),
  sous_prefecture_id UUID REFERENCES public.sous_prefectures(id),
  offre_id UUID REFERENCES public.offres(id),
  type_compte TEXT,
  banque_operateur TEXT,
  numero_compte TEXT,
  nom_titulaire_compte TEXT,
  photo_profil_url TEXT,
  fichier_piece_url TEXT,
  fichier_piece_recto_url TEXT,
  fichier_piece_verso_url TEXT,
  nombre_plantations INTEGER DEFAULT 0,
  total_hectares NUMERIC DEFAULT 0,
  statut TEXT DEFAULT 'actif',
  statut_global TEXT DEFAULT 'actif',
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.souscripteurs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can view souscripteurs" ON public.souscripteurs FOR SELECT TO authenticated USING (public.is_staff(auth.uid()) OR auth.uid() = user_id);
CREATE POLICY "Staff can insert souscripteurs" ON public.souscripteurs FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Staff can update souscripteurs" ON public.souscripteurs FOR UPDATE TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Admins can delete souscripteurs" ON public.souscripteurs FOR DELETE TO authenticated USING (public.is_admin(auth.uid()));
CREATE INDEX idx_souscripteurs_telephone ON public.souscripteurs(telephone);
CREATE INDEX idx_souscripteurs_id_unique ON public.souscripteurs(id_unique);
CREATE INDEX idx_souscripteurs_offre ON public.souscripteurs(offre_id);
CREATE INDEX idx_souscripteurs_region ON public.souscripteurs(region_id);
CREATE INDEX idx_souscripteurs_statut ON public.souscripteurs(statut);
CREATE INDEX idx_souscripteurs_created ON public.souscripteurs(created_at DESC);
CREATE INDEX idx_souscripteurs_user ON public.souscripteurs(user_id);

-- 9. TABLE: plantations
CREATE TABLE public.plantations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  id_unique TEXT UNIQUE,
  souscripteur_id UUID REFERENCES public.souscripteurs(id) ON DELETE CASCADE,
  nom TEXT,
  nom_plantation TEXT,
  superficie_ha NUMERIC DEFAULT 0,
  nombre_plants INTEGER DEFAULT 0,
  densite_plants INTEGER DEFAULT 0,
  district_id UUID REFERENCES public.districts(id),
  region_id UUID REFERENCES public.regions(id),
  departement_id UUID REFERENCES public.departements(id),
  sous_prefecture_id UUID REFERENCES public.sous_prefectures(id),
  village TEXT,
  localisation_gps_lat NUMERIC,
  localisation_gps_lng NUMERIC,
  polygone_gps JSONB,
  date_plantation DATE,
  date_activation DATE,
  variete TEXT,
  age_plants INTEGER,
  statut TEXT DEFAULT 'en_attente_da',
  statut_global TEXT DEFAULT 'en_attente_da',
  superficie_activee NUMERIC DEFAULT 0,
  montant_da NUMERIC DEFAULT 0,
  montant_da_paye NUMERIC DEFAULT 0,
  montant_contribution_mensuelle NUMERIC DEFAULT 0,
  alerte_non_paiement BOOLEAN DEFAULT false,
  alerte_visite_retard BOOLEAN DEFAULT false,
  derniere_visite DATE,
  prochaine_visite DATE,
  notes TEXT,
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.plantations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can view plantations" ON public.plantations FOR SELECT TO authenticated USING (public.is_staff(auth.uid()) OR EXISTS (SELECT 1 FROM public.souscripteurs s WHERE s.id = souscripteur_id AND s.user_id = auth.uid()));
CREATE POLICY "Staff can insert plantations" ON public.plantations FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Staff can update plantations" ON public.plantations FOR UPDATE TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Admins can delete plantations" ON public.plantations FOR DELETE TO authenticated USING (public.is_admin(auth.uid()));
CREATE INDEX idx_plantations_souscripteur ON public.plantations(souscripteur_id);
CREATE INDEX idx_plantations_region ON public.plantations(region_id);
CREATE INDEX idx_plantations_statut ON public.plantations(statut_global);
CREATE INDEX idx_plantations_created ON public.plantations(created_at DESC);
CREATE INDEX idx_plantations_id_unique ON public.plantations(id_unique);

-- 10. TABLE: paiements
CREATE TABLE public.paiements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  souscripteur_id UUID REFERENCES public.souscripteurs(id) ON DELETE CASCADE,
  plantation_id UUID REFERENCES public.plantations(id) ON DELETE SET NULL,
  montant NUMERIC NOT NULL DEFAULT 0,
  montant_paye NUMERIC DEFAULT 0,
  type_paiement TEXT DEFAULT 'REDEVANCE',
  mode_paiement TEXT,
  statut TEXT DEFAULT 'en_attente',
  reference TEXT,
  date_paiement TIMESTAMPTZ,
  date_echeance DATE,
  preuve_paiement_url TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  notes TEXT,
  valide_par UUID REFERENCES auth.users(id),
  date_validation TIMESTAMPTZ,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.paiements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can view paiements" ON public.paiements FOR SELECT TO authenticated USING (public.is_staff(auth.uid()) OR EXISTS (SELECT 1 FROM public.souscripteurs s WHERE s.id = souscripteur_id AND s.user_id = auth.uid()));
CREATE POLICY "Can insert paiements" ON public.paiements FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Staff can update paiements" ON public.paiements FOR UPDATE TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Admins can delete paiements" ON public.paiements FOR DELETE TO authenticated USING (public.is_admin(auth.uid()));
CREATE INDEX idx_paiements_souscripteur ON public.paiements(souscripteur_id);
CREATE INDEX idx_paiements_plantation ON public.paiements(plantation_id);
CREATE INDEX idx_paiements_statut ON public.paiements(statut);
CREATE INDEX idx_paiements_created ON public.paiements(created_at DESC);
CREATE INDEX idx_paiements_reference ON public.paiements(reference);

-- 11. TABLE: transferts_paiements
CREATE TABLE public.transferts_paiements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  souscripteur_source_id UUID REFERENCES public.souscripteurs(id),
  souscripteur_dest_id UUID REFERENCES public.souscripteurs(id),
  montant NUMERIC NOT NULL,
  motif TEXT,
  statut TEXT DEFAULT 'effectue',
  effectue_par UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.transferts_paiements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff manage transferts" ON public.transferts_paiements FOR ALL TO authenticated USING (public.is_staff(auth.uid()));

-- 12. TABLE: remboursements
CREATE TABLE public.remboursements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  paiement_id UUID REFERENCES public.paiements(id),
  souscripteur_id UUID REFERENCES public.souscripteurs(id),
  montant NUMERIC NOT NULL,
  motif TEXT,
  mode_remboursement TEXT,
  numero_compte TEXT,
  statut TEXT DEFAULT 'en_attente',
  traite_par UUID REFERENCES auth.users(id),
  date_traitement TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.remboursements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff manage remboursements" ON public.remboursements FOR ALL TO authenticated USING (public.is_staff(auth.uid()));

-- 13. TABLE: commissions
CREATE TABLE public.commissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  plantation_id UUID REFERENCES public.plantations(id) ON DELETE SET NULL,
  type_commission TEXT NOT NULL,
  montant_base NUMERIC DEFAULT 0,
  taux_commission NUMERIC DEFAULT 0,
  montant_commission NUMERIC DEFAULT 0,
  periode DATE,
  date_calcul TIMESTAMPTZ DEFAULT now(),
  statut TEXT DEFAULT 'en_attente',
  valide_par UUID REFERENCES auth.users(id),
  date_validation TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.commissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can view commissions" ON public.commissions FOR SELECT TO authenticated USING (public.is_staff(auth.uid()) OR profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()));
CREATE POLICY "Admins manage commissions" ON public.commissions FOR ALL TO authenticated USING (public.is_admin(auth.uid()));
CREATE INDEX idx_commissions_profile ON public.commissions(profile_id);
CREATE INDEX idx_commissions_plantation ON public.commissions(plantation_id);
CREATE INDEX idx_commissions_statut ON public.commissions(statut);

-- 14. TABLE: portefeuilles
CREATE TABLE public.portefeuilles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  solde_commissions NUMERIC DEFAULT 0,
  total_gagne NUMERIC DEFAULT 0,
  total_retire NUMERIC DEFAULT 0,
  dernier_versement_montant NUMERIC DEFAULT 0,
  dernier_versement_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.portefeuilles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff view portefeuilles" ON public.portefeuilles FOR SELECT TO authenticated USING (public.is_staff(auth.uid()) OR auth.uid() = user_id);
CREATE POLICY "Admins manage portefeuilles" ON public.portefeuilles FOR ALL TO authenticated USING (public.is_admin(auth.uid()));

-- 15. TABLE: retraits_portefeuille
CREATE TABLE public.retraits_portefeuille (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  portefeuille_id UUID REFERENCES public.portefeuilles(id),
  user_id UUID REFERENCES auth.users(id),
  montant NUMERIC NOT NULL,
  mode_paiement TEXT,
  numero_compte TEXT,
  statut TEXT DEFAULT 'en_attente',
  date_demande TIMESTAMPTZ DEFAULT now(),
  date_traitement TIMESTAMPTZ,
  traite_par UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.retraits_portefeuille ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff view retraits" ON public.retraits_portefeuille FOR SELECT TO authenticated USING (public.is_staff(auth.uid()) OR auth.uid() = user_id);
CREATE POLICY "Admins manage retraits" ON public.retraits_portefeuille FOR ALL TO authenticated USING (public.is_admin(auth.uid()));

-- 16. TABLE: tickets_techniques
CREATE TABLE public.tickets_techniques (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  titre TEXT NOT NULL,
  description TEXT,
  plantation_id UUID REFERENCES public.plantations(id) ON DELETE SET NULL,
  priorite TEXT DEFAULT 'moyenne',
  statut TEXT DEFAULT 'ouvert',
  cree_par UUID REFERENCES auth.users(id),
  assigne_a UUID REFERENCES auth.users(id),
  date_resolution TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.tickets_techniques ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff manage tickets" ON public.tickets_techniques FOR ALL TO authenticated USING (public.is_staff(auth.uid()));
CREATE INDEX idx_tickets_statut ON public.tickets_techniques(statut);
CREATE INDEX idx_tickets_plantation ON public.tickets_techniques(plantation_id);

-- 17. TABLE: notifications
CREATE TABLE public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  data JSONB,
  read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users see own notifications" ON public.notifications FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users update own notifications" ON public.notifications FOR UPDATE TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "System insert notifications" ON public.notifications FOR INSERT WITH CHECK (true);
CREATE INDEX idx_notifications_user ON public.notifications(user_id);
CREATE INDEX idx_notifications_read ON public.notifications(read);
CREATE INDEX idx_notifications_created ON public.notifications(created_at DESC);

-- 18. TABLE: account_requests
CREATE TABLE public.account_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nom_complet TEXT NOT NULL,
  email TEXT NOT NULL,
  telephone TEXT NOT NULL,
  poste_souhaite TEXT,
  role_souhaite TEXT NOT NULL,
  departement TEXT,
  justification TEXT,
  cv_url TEXT,
  photo_url TEXT,
  district_id UUID REFERENCES public.districts(id),
  region_id UUID REFERENCES public.regions(id),
  departement_geo_id UUID REFERENCES public.departements(id),
  statut TEXT DEFAULT 'en_attente',
  motif_rejet TEXT,
  traite_par UUID REFERENCES auth.users(id),
  traite_le TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.account_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can create account request" ON public.account_requests FOR INSERT WITH CHECK (true);
CREATE POLICY "Admins view account requests" ON public.account_requests FOR SELECT TO authenticated USING (public.is_admin(auth.uid()));
CREATE POLICY "Admins update account requests" ON public.account_requests FOR UPDATE TO authenticated USING (public.is_admin(auth.uid()));
CREATE INDEX idx_account_requests_statut ON public.account_requests(statut);

-- 19. TABLE: historique_activites (traçabilité avancée)
CREATE TABLE public.historique_activites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL DEFAULT auth.uid(),
  table_name TEXT NOT NULL,
  record_id TEXT,
  action TEXT NOT NULL,
  details TEXT,
  ip_address TEXT,
  user_agent TEXT,
  ancien_valeurs JSONB,
  nouvelles_valeurs JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.historique_activites ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff view history" ON public.historique_activites FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Insert history" ON public.historique_activites FOR INSERT TO authenticated WITH CHECK (true);
CREATE INDEX idx_historique_table ON public.historique_activites(table_name);
CREATE INDEX idx_historique_record ON public.historique_activites(record_id);
CREATE INDEX idx_historique_created ON public.historique_activites(created_at DESC);

-- 20. TABLE: activity_notes
CREATE TABLE public.activity_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  action TEXT NOT NULL,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.activity_notes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff view notes" ON public.activity_notes FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff create notes" ON public.activity_notes FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE INDEX idx_activity_notes_entity ON public.activity_notes(entity_type, entity_id);

-- 21. TRIGGERS: updated_at automatique
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql SET search_path = public;

CREATE TRIGGER tr_profiles_updated BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER tr_equipes_updated BEFORE UPDATE ON public.equipes FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER tr_offres_updated BEFORE UPDATE ON public.offres FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER tr_promotions_updated BEFORE UPDATE ON public.promotions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER tr_souscripteurs_updated BEFORE UPDATE ON public.souscripteurs FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER tr_plantations_updated BEFORE UPDATE ON public.plantations FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER tr_paiements_updated BEFORE UPDATE ON public.paiements FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER tr_tickets_updated BEFORE UPDATE ON public.tickets_techniques FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 22. TRIGGER: Auto-sync souscripteur stats
CREATE OR REPLACE FUNCTION public.update_souscripteur_stats()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_sid UUID; v_count INTEGER; v_total NUMERIC;
BEGIN
  v_sid := COALESCE(NEW.souscripteur_id, OLD.souscripteur_id);
  IF v_sid IS NULL THEN RETURN COALESCE(NEW, OLD); END IF;
  SELECT COUNT(*), COALESCE(SUM(superficie_ha), 0) INTO v_count, v_total FROM public.plantations WHERE souscripteur_id = v_sid;
  UPDATE public.souscripteurs SET nombre_plantations = v_count, total_hectares = v_total WHERE id = v_sid;
  RETURN COALESCE(NEW, OLD);
END;
$$;
CREATE TRIGGER tr_sync_souscripteur_stats AFTER INSERT OR UPDATE OR DELETE ON public.plantations FOR EACH ROW EXECUTE FUNCTION public.update_souscripteur_stats();

-- 23. TRIGGER: Notifications automatiques
CREATE OR REPLACE FUNCTION public.notify_hierarchy(p_type TEXT, p_title TEXT, p_message TEXT, p_data JSONB DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_user RECORD;
BEGIN
  FOR v_user IN SELECT DISTINCT ur.user_id FROM public.user_roles ur WHERE ur.role IN ('super_admin', 'directeur_technico_commercial', 'responsable_zone', 'chef_equipe')
  LOOP
    INSERT INTO public.notifications (user_id, type, title, message, data) VALUES (v_user.user_id, p_type, p_title, p_message, p_data);
  END LOOP;
END;
$$;

-- 24. FONCTION: Generate IDs
CREATE OR REPLACE FUNCTION public.generate_souscripteur_id()
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE new_id TEXT; seq INTEGER;
BEGIN
  SELECT COALESCE(MAX(CAST(SUBSTRING(id_unique FROM 5) AS INTEGER)), 0) + 1 INTO seq FROM public.souscripteurs WHERE id_unique LIKE 'AGC-%';
  new_id := 'AGC-' || LPAD(seq::TEXT, 6, '0');
  RETURN new_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.generate_plantation_id()
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE new_id TEXT; seq INTEGER;
BEGIN
  SELECT COALESCE(MAX(CAST(SUBSTRING(id_unique FROM 5) AS INTEGER)), 0) + 1 INTO seq FROM public.plantations WHERE id_unique LIKE 'PLT-%';
  new_id := 'PLT-' || LPAD(seq::TEXT, 6, '0');
  RETURN new_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.current_profile_id()
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT id FROM public.profiles WHERE user_id = auth.uid() LIMIT 1
$$;

-- 25. REALTIME
ALTER PUBLICATION supabase_realtime ADD TABLE public.souscripteurs;
ALTER PUBLICATION supabase_realtime ADD TABLE public.plantations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.paiements;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_roles;
ALTER PUBLICATION supabase_realtime ADD TABLE public.equipes;
ALTER PUBLICATION supabase_realtime ADD TABLE public.commissions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.offres;
ALTER PUBLICATION supabase_realtime ADD TABLE public.promotions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.portefeuilles;
ALTER PUBLICATION supabase_realtime ADD TABLE public.retraits_portefeuille;
ALTER PUBLICATION supabase_realtime ADD TABLE public.tickets_techniques;
ALTER PUBLICATION supabase_realtime ADD TABLE public.districts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.regions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.account_requests;

-- 26. STORAGE BUCKETS
INSERT INTO storage.buckets (id, name, public) VALUES ('documents', 'documents', true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('photos-profils', 'photos-profils', true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('pieces-identite', 'pieces-identite', false) ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Auth upload docs" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id IN ('documents', 'photos-profils', 'pieces-identite'));
CREATE POLICY "Public read docs" ON storage.objects FOR SELECT USING (bucket_id IN ('documents', 'photos-profils'));
CREATE POLICY "Staff read pieces" ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'pieces-identite');

-- 27. SEED: Offres par défaut
INSERT INTO public.offres (code, nom, description, montant_da_par_ha, contribution_mensuelle_par_ha, couleur, avantages, actif, ordre)
VALUES
  ('PALMELITE', 'PalmÉlite', 'Offre Premium avec accompagnement VIP', 350000, 1900, '#D4AF37', '["Accompagnement VIP personnalisé", "Suivi technique mensuel", "Rapports détaillés trimestriels", "Priorité sur les nouvelles parcelles", "Assurance récolte incluse"]'::jsonb, true, 1),
  ('PALMINVEST', 'PalmInvest', 'Offre Investisseur avec rendements optimisés', 250000, 1900, '#1b3a2e', '["Rendements optimisés garantis", "Suivi technique bimensuel", "Rapports mensuels", "Accès tableau de bord en ligne"]'::jsonb, true, 2),
  ('TERRAPALM', 'TerraPalm', 'Offre Accessible pour tous', 150000, 1900, '#2E8B57', '["Accompagnement standard", "Suivi technique trimestriel", "Rapports semestriels", "Support technique"]'::jsonb, true, 3)
ON CONFLICT (code) DO NOTHING;

-- 28. SEED: Districts de Côte d'Ivoire
INSERT INTO public.districts (nom, code, est_actif) VALUES
  ('District Autonome d''Abidjan', 'ABJ', true),
  ('District Autonome de Yamoussoukro', 'YAM', true),
  ('District des Montagnes', 'MTG', false),
  ('District de la Sassandra-Marahoué', 'SSM', false),
  ('District du Bas-Sassandra', 'BSS', true),
  ('District de la Comoé', 'CME', false),
  ('District du Gôh-Djiboua', 'GDJ', true),
  ('District des Lacs', 'LAC', false),
  ('District des Lagunes', 'LAG', true),
  ('District du Bandama', 'BDM', false),
  ('District du Denguélé', 'DGL', false),
  ('District du Woroba', 'WRB', false),
  ('District de la Vallée du Bandama', 'VBD', false),
  ('District du Zanzan', 'ZZN', false)
ON CONFLICT (nom) DO NOTHING;
