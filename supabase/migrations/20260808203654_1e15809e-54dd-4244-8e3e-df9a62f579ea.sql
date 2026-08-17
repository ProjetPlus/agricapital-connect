CREATE TABLE IF NOT EXISTS public.configurations_systeme (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cle text NOT NULL UNIQUE,
  valeur text NOT NULL DEFAULT '',
  description text,
  categorie text NOT NULL DEFAULT 'general',
  type_valeur text NOT NULL DEFAULT 'text',
  modifiable boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT ON public.configurations_systeme TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.configurations_systeme TO authenticated;
GRANT ALL ON public.configurations_systeme TO service_role;

ALTER TABLE public.configurations_systeme ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "config_read_all" ON public.configurations_systeme;
CREATE POLICY "config_read_all" ON public.configurations_systeme FOR SELECT USING (true);

DROP POLICY IF EXISTS "config_write_admin" ON public.configurations_systeme;
CREATE POLICY "config_write_admin" ON public.configurations_systeme FOR ALL TO authenticated
  USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

DROP TRIGGER IF EXISTS trg_config_updated_at ON public.configurations_systeme;
CREATE TRIGGER trg_config_updated_at BEFORE UPDATE ON public.configurations_systeme
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

INSERT INTO public.configurations_systeme (cle, valeur, description, categorie, type_valeur) VALUES
  ('societe_nom','AgriCapital','Nom de la société','general','text'),
  ('societe_sigle','AGC','Sigle affiché','general','text'),
  ('societe_adresse','Abidjan, Côte d''Ivoire','Adresse du siège','general','text'),
  ('societe_rccm','','Numéro RCCM','general','text'),
  ('devise','FCFA','Devise utilisée','general','text'),
  ('contact_email','contact@agricapital.ci','Email de contact principal','contact','email'),
  ('contact_telephone','','Téléphone principal','contact','text'),
  ('contact_whatsapp','','Numéro WhatsApp support','contact','text'),
  ('site_web','https://agricapital.ci','Site web officiel','contact','url'),
  ('paiement_mobile_money_actif','true','Activer le paiement Mobile Money','paiements','boolean'),
  ('paiement_delai_relance_jours','7','Délai avant relance de paiement (jours)','paiements','number'),
  ('paiement_tolerance_retard_jours','5','Tolérance de retard avant alerte (jours)','paiements','number'),
  ('commission_commercial_pct','5','Commission commerciale par défaut (%)','commissions','number'),
  ('commission_chef_equipe_pct','2','Commission chef d''équipe (%)','commissions','number'),
  ('notifications_email_actives','true','Envoyer les notifications par email','notifications','boolean'),
  ('notifications_push_actives','true','Envoyer les notifications push','notifications','boolean'),
  ('alerte_visite_retard_jours','30','Alerte si aucune visite depuis X jours','alertes','number'),
  ('alerte_impaye_jours','15','Alerte impayé après X jours','alertes','number'),
  ('souscription_duree_contrat_mois','35','Durée du contrat (mois)','souscriptions','number'),
  ('souscription_superficie_min_ha','1','Superficie minimale par souscription (ha)','souscriptions','number'),
  ('souscription_validation_documents_obligatoire','true','Documents obligatoires avant activation','souscriptions','boolean'),
  ('securite_session_duree_heures','12','Durée de session (heures)','securite','number'),
  ('securite_mdp_longueur_min','8','Longueur minimale du mot de passe','securite','number'),
  ('securite_2fa_obligatoire','false','Authentification à deux facteurs obligatoire','securite','boolean')
ON CONFLICT (cle) DO NOTHING;