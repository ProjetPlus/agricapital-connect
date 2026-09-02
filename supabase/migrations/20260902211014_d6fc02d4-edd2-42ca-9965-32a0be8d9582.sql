-- 1) historique_actions
CREATE TABLE public.historique_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  souscripteur_id uuid REFERENCES public.souscripteurs(id) ON DELETE CASCADE,
  entity_type text,
  entity_id uuid,
  action text NOT NULL,
  details jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_hist_actions_entity ON public.historique_actions(entity_type, entity_id);
CREATE INDEX idx_hist_actions_sous ON public.historique_actions(souscripteur_id);
GRANT SELECT, INSERT ON public.historique_actions TO authenticated;
GRANT ALL ON public.historique_actions TO service_role;
ALTER TABLE public.historique_actions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "hist_actions_select_staff" ON public.historique_actions FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "hist_actions_insert_staff" ON public.historique_actions FOR INSERT TO authenticated WITH CHECK (public.is_staff(auth.uid()));

-- 2) app_roles
CREATE TABLE public.app_roles (
  code text PRIMARY KEY,
  nom text NOT NULL,
  court text,
  description text DEFAULT '',
  niveau integer NOT NULL DEFAULT 5,
  niveau_label text DEFAULT 'Opérationnel',
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.app_roles TO authenticated;
GRANT ALL ON public.app_roles TO service_role;
ALTER TABLE public.app_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "app_roles_select_auth" ON public.app_roles FOR SELECT TO authenticated USING (true);
CREATE POLICY "app_roles_write_admin" ON public.app_roles FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

INSERT INTO public.app_roles (code, nom, court, description, niveau, niveau_label) VALUES
 ('super_admin','Super Admin','Admin','Accès complet à toutes les fonctionnalités',1,'Direction Suprême'),
 ('responsable_operations','Responsable des Opérations','ROps','Pilotage des opérations, offres et paramétrage métier',2,'Direction'),
 ('directeur_tc','Directeur TC','DTC','Direction de l''activité technico-commerciale',2,'Direction'),
 ('responsable_commercial','Responsable Commercial','RCom','Pilotage commercial et gestion d''une zone',3,'Management'),
 ('comptable','Comptable','Compta','Gestion financière, paiements et comptabilité',3,'Management'),
 ('chef_equipe_commercial','Chef d''Equipe Commercial','CEC','Encadrement d''une équipe commerciale terrain',4,'Encadrement'),
 ('chef_equipe_technique','Chef d''Equipe Technique','CET','Encadrement d''une équipe technique terrain',4,'Encadrement'),
 ('chef_equipe_service_client','Chef d''Equipe Service Client','CESC','Encadrement de l''équipe service client',4,'Encadrement'),
 ('commercial','Commercial','Comm','Prospection, leads et souscriptions',5,'Opérationnel'),
 ('service_client','Service Client','SC','Support, tickets et assistance client',5,'Opérationnel'),
 ('assistant_administratif','Assistant(e) Administratif(ve)','AA','Appui administratif et gestion documentaire',5,'Opérationnel');

-- 3) role_permissions
CREATE TABLE public.role_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role_code text NOT NULL,
  permission_code text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (role_code, permission_code)
);
GRANT SELECT ON public.role_permissions TO authenticated;
GRANT ALL ON public.role_permissions TO service_role;
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "role_perms_select_auth" ON public.role_permissions FOR SELECT TO authenticated USING (true);
CREATE POLICY "role_perms_write_admin" ON public.role_permissions FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

-- 4) departements_entreprise
CREATE TABLE public.departements_entreprise (
  id text PRIMARY KEY,
  code text NOT NULL UNIQUE,
  nom text NOT NULL,
  requiert_couverture boolean NOT NULL DEFAULT false,
  ordre integer NOT NULL DEFAULT 0,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.departements_entreprise TO authenticated;
GRANT ALL ON public.departements_entreprise TO service_role;
ALTER TABLE public.departements_entreprise ENABLE ROW LEVEL SECURITY;
CREATE POLICY "dept_ent_select_auth" ON public.departements_entreprise FOR SELECT TO authenticated USING (true);
CREATE POLICY "dept_ent_write_admin" ON public.departements_entreprise FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

INSERT INTO public.departements_entreprise (id, code, nom, requiert_couverture, ordre) VALUES
 ('direction_generale','direction_generale','Direction Générale',false,1),
 ('commercial','commercial','Commercial',true,2),
 ('technique','technique','Technique',true,3),
 ('finance_comptabilite','finance_comptabilite','Finance & Comptabilité',false,4),
 ('operations','operations','Opérations',false,5),
 ('service_client','service_client','Service Client',false,6),
 ('ressources_humaines','ressources_humaines','Ressources Humaines',false,7);

-- 5) interventions_techniques
CREATE TABLE public.interventions_techniques (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plantation_id uuid REFERENCES public.plantations(id) ON DELETE CASCADE,
  technicien_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  type_intervention text NOT NULL DEFAULT 'suivi_mensuel',
  date_intervention date NOT NULL DEFAULT CURRENT_DATE,
  observations text,
  recommandations text,
  cout numeric DEFAULT 0,
  statut text NOT NULL DEFAULT 'realisee',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_interv_plantation ON public.interventions_techniques(plantation_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.interventions_techniques TO authenticated;
GRANT ALL ON public.interventions_techniques TO service_role;
ALTER TABLE public.interventions_techniques ENABLE ROW LEVEL SECURITY;
CREATE POLICY "interv_select_staff" ON public.interventions_techniques FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "interv_write_staff" ON public.interventions_techniques FOR ALL TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));

-- 6) photos_plantation
CREATE TABLE public.photos_plantation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plantation_id uuid REFERENCES public.plantations(id) ON DELETE CASCADE,
  url text NOT NULL,
  type_photo text NOT NULL DEFAULT 'generale',
  phase text,
  description text,
  date_prise date NOT NULL DEFAULT CURRENT_DATE,
  uploaded_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_photos_plantation ON public.photos_plantation(plantation_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.photos_plantation TO authenticated;
GRANT ALL ON public.photos_plantation TO service_role;
ALTER TABLE public.photos_plantation ENABLE ROW LEVEL SECURITY;
CREATE POLICY "photos_select_staff" ON public.photos_plantation FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "photos_write_staff" ON public.photos_plantation FOR ALL TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));

-- Triggers updated_at
CREATE TRIGGER trg_hist_actions_updated BEFORE UPDATE ON public.historique_actions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trg_app_roles_updated BEFORE UPDATE ON public.app_roles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trg_dept_ent_updated BEFORE UPDATE ON public.departements_entreprise FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trg_interv_updated BEFORE UPDATE ON public.interventions_techniques FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trg_photos_updated BEFORE UPDATE ON public.photos_plantation FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();