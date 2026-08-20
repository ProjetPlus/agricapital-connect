-- =========================================================
-- 1. RELANCES AGRIPLAN
-- =========================================================
ALTER TABLE public.agriplan_leads
  ADD COLUMN IF NOT EXISTS prochaine_relance_at timestamptz,
  ADD COLUMN IF NOT EXISTS nb_relances integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS derniere_relance_at timestamptz;

CREATE TABLE IF NOT EXISTS public.agriplan_lead_relances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id uuid NOT NULL REFERENCES public.agriplan_leads(id) ON DELETE CASCADE,
  commercial_id uuid,
  date_relance timestamptz NOT NULL DEFAULT now(),
  canal text NOT NULL DEFAULT 'appel',
  resultat text NOT NULL DEFAULT 'interesse',
  commentaire text,
  prochaine_relance date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.agriplan_lead_relances TO authenticated;
GRANT ALL ON public.agriplan_lead_relances TO service_role;
ALTER TABLE public.agriplan_lead_relances ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "staff read agriplan relances" ON public.agriplan_lead_relances;
CREATE POLICY "staff read agriplan relances" ON public.agriplan_lead_relances
  FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
DROP POLICY IF EXISTS "staff write agriplan relances" ON public.agriplan_lead_relances;
CREATE POLICY "staff write agriplan relances" ON public.agriplan_lead_relances
  FOR INSERT TO authenticated WITH CHECK (public.is_staff(auth.uid()));
DROP POLICY IF EXISTS "staff update agriplan relances" ON public.agriplan_lead_relances;
CREATE POLICY "staff update agriplan relances" ON public.agriplan_lead_relances
  FOR UPDATE TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));

CREATE OR REPLACE FUNCTION public.agriplan_sync_lead_relance()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.agriplan_leads
     SET prochaine_relance_at = NEW.prochaine_relance,
         derniere_relance_at  = NEW.date_relance,
         nb_relances          = COALESCE(nb_relances, 0) + 1,
         updated_at           = now()
   WHERE id = NEW.lead_id;
  RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION public.agriplan_sync_lead_relance() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.agriplan_sync_lead_relance() TO service_role;

DROP TRIGGER IF EXISTS trg_agriplan_lead_relance ON public.agriplan_lead_relances;
CREATE TRIGGER trg_agriplan_lead_relance AFTER INSERT ON public.agriplan_lead_relances
  FOR EACH ROW EXECUTE FUNCTION public.agriplan_sync_lead_relance();

CREATE INDEX IF NOT EXISTS idx_ap_relances_lead ON public.agriplan_lead_relances(lead_id);

-- =========================================================
-- 2. GESTION DU COMPTE CLIENT AGRIPLAN (archiver/suspendre/reactiver)
-- =========================================================
ALTER TABLE public.agriplan_clients
  ADD COLUMN IF NOT EXISTS suspended_at timestamptz,
  ADD COLUMN IF NOT EXISTS suspended_by uuid,
  ADD COLUMN IF NOT EXISTS motif_statut text,
  ADD COLUMN IF NOT EXISTS portail_actif boolean NOT NULL DEFAULT false;

-- =========================================================
-- 3. TEMPLATES DE NOTIFICATION
-- =========================================================
CREATE TABLE IF NOT EXISTS public.notification_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  nom text NOT NULL,
  canal text NOT NULL DEFAULT 'email',
  evenement text NOT NULL,
  sujet text,
  contenu text NOT NULL,
  variables jsonb NOT NULL DEFAULT '[]'::jsonb,
  parcours text NOT NULL DEFAULT 'commun',
  actif boolean NOT NULL DEFAULT true,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.notification_templates TO authenticated;
GRANT ALL ON public.notification_templates TO service_role;
ALTER TABLE public.notification_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "staff read templates" ON public.notification_templates;
CREATE POLICY "staff read templates" ON public.notification_templates
  FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
DROP POLICY IF EXISTS "admins manage templates" ON public.notification_templates;
CREATE POLICY "admins manage templates" ON public.notification_templates
  FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

DROP TRIGGER IF EXISTS trg_notification_templates_updated ON public.notification_templates;
CREATE TRIGGER trg_notification_templates_updated BEFORE UPDATE ON public.notification_templates
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

INSERT INTO public.notification_templates (code, nom, canal, evenement, sujet, contenu, variables, parcours) VALUES
('souscription_nouvelle','Nouvelle souscription','email','souscription_nouvelle','Votre souscription AgriCapital est enregistrée',
 'Bonjour {nom}, votre souscription {numero_contrat} pour {superficie} ha ({offre}) a bien été enregistrée le {date}. Notre équipe vous accompagne pour la suite de votre projet agricole.',
 '["nom","numero_contrat","offre","superficie","date"]','commun'),
('souscription_confirmee','Souscription confirmée','whatsapp','souscription_confirmee',NULL,
 'Bonjour {nom}, bienvenue chez AgriCapital. Votre souscription est confirmée. Merci pour votre confiance. Nous vous accompagnons dans votre projet agricole.',
 '["nom","numero_contrat","offre"]','commun'),
('paiement_recu','Paiement reçu','sms','paiement_recu',NULL,
 'Bonjour {nom}, nous avons reçu votre paiement de {montant} FCFA le {date}. Référence : {reference}. Merci de votre confiance. AgriCapital.',
 '["nom","montant","date","reference"]','commun'),
('paiement_valide','Paiement validé','email','paiement_valide','Paiement validé — {montant} FCFA',
 'Bonjour {nom}, votre paiement de {montant} FCFA a été validé. Nouveau solde de votre contrat {numero_contrat} : {solde} FCFA. Votre reçu est disponible dans votre espace client.',
 '["nom","montant","numero_contrat","solde","reference"]','commun'),
('paiement_rappel','Rappel de paiement','whatsapp','paiement_rappel',NULL,
 'Bonjour {nom}, nous vous rappelons que votre échéance de {montant} FCFA est due le {date_echeance}. Merci de régulariser afin de poursuivre sereinement votre projet. AgriCapital.',
 '["nom","montant","date_echeance","numero_contrat"]','commun'),
('paiement_retard','Retard de paiement','sms','paiement_retard',NULL,
 'Bonjour {nom}, votre échéance de {montant} FCFA du {date_echeance} est en retard de {jours_retard} jour(s). Merci de contacter votre conseiller {conseiller}. AgriCapital.',
 '["nom","montant","date_echeance","jours_retard","conseiller"]','commun'),
('echeance_proche','Échéance proche','sms','echeance_proche',NULL,
 'Bonjour {nom}, votre prochaine échéance de {montant} FCFA arrive le {date_echeance}. AgriCapital vous remercie.',
 '["nom","montant","date_echeance"]','commun'),
('solde_contrat','Solde du contrat','email','solde_contrat','Situation de votre contrat {numero_contrat}',
 'Bonjour {nom}, à ce jour votre contrat {numero_contrat} affiche un total payé de {total_paye} FCFA sur {montant_total} FCFA, soit un solde restant de {solde} FCFA. Merci de votre confiance.',
 '["nom","numero_contrat","total_paye","montant_total","solde"]','commun'),
('solde_palminvest','Solde PalmInvest','email','solde_palminvest','Situation de votre contrat PalmInvest',
 'Bonjour {nom}, votre contrat PalmInvest {numero_contrat} ({superficie} ha) présente un solde de {solde} FCFA sur un total de {montant_total} FCFA. Dépôt initial : {depot_initial} FCFA. Merci de votre confiance.',
 '["nom","numero_contrat","superficie","solde","montant_total","depot_initial"]','palminvest'),
('solde_terrapalm','Solde TerraPalm','email','solde_terrapalm','Situation de votre contrat TerraPalm',
 'Bonjour {nom}, votre contrat TerraPalm {numero_contrat} ({superficie} ha) présente un solde de {solde} FCFA sur un total de {montant_total} FCFA. Merci de votre confiance.',
 '["nom","numero_contrat","superficie","solde","montant_total"]','terrapalm'),
('visite_technique_rdv','Rendez-vous de visite technique','whatsapp','visite_technique_rdv',NULL,
 'Bonjour {nom}, une visite technique est prévue le {date_visite} sur votre plantation {plantation}. Le technicien {technicien} vous contactera. AgriCapital.',
 '["nom","date_visite","plantation","technicien"]','commun'),
('visite_technique_realisee','Visite technique réalisée','email','visite_technique_realisee','Compte rendu de visite — {plantation}',
 'Bonjour {nom}, la visite technique du {date_visite} sur {plantation} a été réalisée par {technicien}. État de la plantation : {etat}. Recommandations : {recommandations}. Le rapport complet est disponible dans votre espace client.',
 '["nom","date_visite","plantation","technicien","etat","recommandations"]','commun'),
('plantation_nouvelle','Nouvelle plantation','email','plantation_nouvelle','Votre plantation {plantation} est enregistrée',
 'Bonjour {nom}, votre plantation {plantation} de {superficie} ha à {localite} a été enregistrée le {date}. Le suivi technique démarre dès maintenant.',
 '["nom","plantation","superficie","localite","date"]','commun'),
('recolte_nouvelle','Nouvelle récolte','email','recolte_nouvelle','Nouvelle récolte enregistrée — {plantation}',
 'Bonjour {nom}, une récolte de {quantite} kg a été enregistrée le {date} sur votre plantation {plantation}. Revenu estimé : {montant} FCFA. Détails dans votre espace client.',
 '["nom","plantation","quantite","date","montant"]','commun'),
('agriplan_vente_nouvelle','Nouvelle vente AgriPlan','email','agriplan_vente_nouvelle','Votre dossier AgriPlan {numero_client}',
 'Bonjour {nom}, bienvenue dans AgriPlan. Votre dossier {numero_client} pour {superficie} ha est ouvert. Montant total : {montant_total} FCFA, dont mise en place {mise_en_place} FCFA. Merci de votre confiance.',
 '["nom","numero_client","superficie","montant_total","mise_en_place"]','agriplan'),
('agriplan_paiement','Paiement AgriPlan','sms','agriplan_paiement',NULL,
 'Bonjour {nom}, votre paiement AgriPlan de {montant} FCFA est enregistré ({libelle}). Solde restant : {solde} FCFA. AgriCapital.',
 '["nom","montant","libelle","solde"]','agriplan'),
('agriplan_solde','Solde AgriPlan','email','agriplan_solde','Situation de votre dossier AgriPlan {numero_client}',
 'Bonjour {nom}, votre dossier AgriPlan {numero_client} affiche {total_paye} FCFA payés sur {montant_total} FCFA, soit un solde de {solde} FCFA. Prochaine échéance : {date_echeance}.',
 '["nom","numero_client","total_paye","montant_total","solde","date_echeance"]','agriplan'),
('agriplan_relance_lead','Relance prospect AgriPlan','whatsapp','agriplan_relance_lead',NULL,
 'Bonjour {nom}, suite à notre échange concernant AgriPlan, je reste disponible pour finaliser votre projet de {superficie} ha. Votre conseiller {conseiller}, AgriCapital.',
 '["nom","superficie","conseiller"]','agriplan'),
('compte_cree','Compte utilisateur créé','email','compte_cree','Votre compte AgriCapital CRM',
 'Bonjour {nom}, votre compte AgriCapital a été créé avec l''identifiant {identifiant} et le rôle {role}. Connectez-vous puis modifiez votre mot de passe.',
 '["nom","identifiant","role"]','commun'),
('compte_approuve','Demande de compte approuvée','email','compte_approuve','Votre demande de compte est approuvée',
 'Bonjour {nom}, votre demande de compte AgriCapital pour le poste {poste} a été approuvée. Vous pouvez désormais vous connecter au CRM.',
 '["nom","poste","role"]','commun'),
('document_valide','Documents validés','whatsapp','document_valide',NULL,
 'Bonjour {nom}, vos documents ont été validés. Votre dossier {numero_contrat} passe à l''étape suivante. AgriCapital.',
 '["nom","numero_contrat"]','commun')
ON CONFLICT (code) DO NOTHING;

-- =========================================================
-- 4. TRAÇABILITÉ COMPLÈTE (qui, quoi, quand)
-- =========================================================
CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  acteur_user_id uuid,
  acteur_libelle text,
  cible_user_id uuid,
  cible_libelle text,
  action text NOT NULL,
  entite text NOT NULL,
  entite_id text,
  ancienne_valeur jsonb,
  nouvelle_valeur jsonb,
  statut text NOT NULL DEFAULT 'succes',
  details text,
  ip_address text,
  user_agent text,
  source text NOT NULL DEFAULT 'app',
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT ON public.admin_audit_logs TO authenticated;
GRANT ALL ON public.admin_audit_logs TO service_role;
ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "staff read audit" ON public.admin_audit_logs;
CREATE POLICY "staff read audit" ON public.admin_audit_logs
  FOR SELECT TO authenticated USING (public.is_staff(auth.uid()) OR acteur_user_id = auth.uid());
DROP POLICY IF EXISTS "authenticated write audit" ON public.admin_audit_logs;
CREATE POLICY "authenticated write audit" ON public.admin_audit_logs
  FOR INSERT TO authenticated WITH CHECK (acteur_user_id IS NULL OR acteur_user_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_audit_created ON public.admin_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_entite ON public.admin_audit_logs(entite, entite_id);
CREATE INDEX IF NOT EXISTS idx_audit_acteur ON public.admin_audit_logs(acteur_user_id);

CREATE OR REPLACE FUNCTION public.audit_row_change()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_old jsonb;
  v_new jsonb;
  v_id text;
  v_acteur uuid := auth.uid();
  v_nom text;
  v_libelle text;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_old := to_jsonb(OLD); v_id := (v_old->>'id');
  ELSIF TG_OP = 'INSERT' THEN
    v_new := to_jsonb(NEW); v_id := (v_new->>'id');
  ELSE
    v_old := to_jsonb(OLD); v_new := to_jsonb(NEW); v_id := (v_new->>'id');
    IF v_old = v_new THEN RETURN NEW; END IF;
  END IF;

  SELECT nom_complet INTO v_nom FROM public.profiles WHERE user_id = v_acteur LIMIT 1;
  v_libelle := COALESCE(
    COALESCE(v_new, v_old)->>'nom_complet',
    COALESCE(v_new, v_old)->>'nom',
    COALESCE(v_new, v_old)->>'numero_client',
    COALESCE(v_new, v_old)->>'reference',
    v_id
  );

  INSERT INTO public.admin_audit_logs (
    acteur_user_id, acteur_libelle, action, entite, entite_id,
    ancienne_valeur, nouvelle_valeur, cible_libelle, details, source
  ) VALUES (
    v_acteur, v_nom, lower(TG_OP), TG_TABLE_NAME, v_id,
    v_old, v_new, v_libelle,
    CASE TG_OP WHEN 'INSERT' THEN 'Création' WHEN 'UPDATE' THEN 'Modification' ELSE 'Suppression' END
      || ' — ' || TG_TABLE_NAME || ' ' || COALESCE(v_libelle, ''),
    'trigger'
  );

  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION public.audit_row_change() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.audit_row_change() TO service_role;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'souscripteurs','paiements','plantations','parcelles','proprietaires_terres',
    'leads','commissions','retraits_portefeuille','offres','promotions','user_roles',
    'agriplan_clients','agriplan_ventes','agriplan_leads','agriplan_plantations',
    'agriplan_visites','agriplan_echeances','agriplan_documents','agriplan_offre',
    'conventions_foncieres','notification_templates'
  ] LOOP
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name=t) THEN
      EXECUTE format('DROP TRIGGER IF EXISTS trg_audit_%1$s ON public.%1$I', t);
      EXECUTE format('CREATE TRIGGER trg_audit_%1$s AFTER INSERT OR UPDATE OR DELETE ON public.%1$I FOR EACH ROW EXECUTE FUNCTION public.audit_row_change()', t);
    END IF;
  END LOOP;
END $$;

-- =========================================================
-- 5. PROMOTIONS SUR LE PRIX GLOBAL — PROPAGATION AUTOMATIQUE
-- =========================================================
CREATE OR REPLACE FUNCTION public.offre_prix_effectif()
RETURNS TABLE (
  offre_id uuid,
  code text,
  nom text,
  montant_total_base numeric,
  depot_initial_base numeric,
  mensualite_base numeric,
  montant_total_effectif numeric,
  depot_initial_effectif numeric,
  mensualite_effective numeric,
  promotion_id uuid,
  promotion_nom text,
  promotion_cible text,
  reduction_pct numeric,
  reduction_montant numeric
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH promo AS (
    SELECT o.id AS oid, p.id AS pid, p.nom AS pnom, p.cible,
           COALESCE(p.pourcentage_reduction, 0) AS pct,
           COALESCE(p.montant_fixe_reduction, 0) AS fixe,
           row_number() OVER (
             PARTITION BY o.id
             ORDER BY COALESCE(p.pourcentage_reduction,0) DESC, COALESCE(p.montant_fixe_reduction,0) DESC
           ) AS rn
      FROM public.offres o
      JOIN public.promotions p
        ON p.active = true
       AND (p.date_debut IS NULL OR p.date_debut <= now())
       AND (p.date_fin IS NULL OR p.date_fin >= now())
       AND (p.applique_toutes_offres = true OR p.offre_ids @> to_jsonb(o.id::text))
  ), best AS (
    SELECT * FROM promo WHERE rn = 1
  )
  SELECT o.id,
         o.code,
         o.nom,
         COALESCE(o.montant_total_par_ha, 0) AS montant_total_base,
         COALESCE(o.montant_depot_initial_par_ha, o.montant_da_par_ha, 0) AS depot_initial_base,
         COALESCE(o.contribution_mensuelle_par_ha, 0) AS mensualite_base,
         t.total_eff,
         t.di_eff,
         CASE WHEN COALESCE(o.duree_paiement_mois, 0) > 0
              THEN round(GREATEST(t.total_eff - t.di_eff, 0) / o.duree_paiement_mois)
              ELSE COALESCE(o.contribution_mensuelle_par_ha, 0) END AS mensualite_effective,
         b.pid, b.pnom, b.cible,
         COALESCE(b.pct, 0),
         GREATEST(COALESCE(o.montant_total_par_ha,0) - t.total_eff, 0)
    FROM public.offres o
    LEFT JOIN best b ON b.oid = o.id
    CROSS JOIN LATERAL (
      SELECT
        CASE
          WHEN b.pid IS NULL THEN COALESCE(o.montant_total_par_ha, 0)
          WHEN b.cible IN ('total_contrat','cout_global') THEN
            GREATEST(COALESCE(o.montant_total_par_ha,0) * (1 - b.pct/100.0) - b.fixe, 0)
          WHEN b.cible = 'special' THEN
            GREATEST(COALESCE(o.montant_total_par_ha,0) - b.fixe, 0)
          ELSE COALESCE(o.montant_total_par_ha, 0)
        END AS total_eff,
        CASE
          WHEN b.pid IS NULL THEN COALESCE(o.montant_depot_initial_par_ha, o.montant_da_par_ha, 0)
          WHEN b.cible = 'depot_initial' THEN
            GREATEST(COALESCE(o.montant_depot_initial_par_ha, o.montant_da_par_ha, 0) * (1 - b.pct/100.0) - b.fixe, 0)
          ELSE COALESCE(o.montant_depot_initial_par_ha, o.montant_da_par_ha, 0)
        END AS di_eff
    ) t
   WHERE o.actif = true;
$$;
REVOKE ALL ON FUNCTION public.offre_prix_effectif() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.offre_prix_effectif() TO authenticated, anon, service_role;

-- =========================================================
-- 6. PORTAIL AGRIPLAN — accès client à son dossier
-- =========================================================
CREATE OR REPLACE FUNCTION public.agriplan_mon_client_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT id FROM public.agriplan_clients WHERE user_id = auth.uid() LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.agriplan_mon_client_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.agriplan_mon_client_id() TO authenticated, service_role;

-- Lecture client (son dossier uniquement)
DROP POLICY IF EXISTS "client lit son dossier" ON public.agriplan_clients;
CREATE POLICY "client lit son dossier" ON public.agriplan_clients
  FOR SELECT TO authenticated USING (user_id = auth.uid());

DROP POLICY IF EXISTS "client lit ses ventes" ON public.agriplan_ventes;
CREATE POLICY "client lit ses ventes" ON public.agriplan_ventes
  FOR SELECT TO authenticated USING (client_id = public.agriplan_mon_client_id());

DROP POLICY IF EXISTS "client lit ses echeances" ON public.agriplan_echeances;
CREATE POLICY "client lit ses echeances" ON public.agriplan_echeances
  FOR SELECT TO authenticated USING (client_id = public.agriplan_mon_client_id());

DROP POLICY IF EXISTS "client lit ses plantations" ON public.agriplan_plantations;
CREATE POLICY "client lit ses plantations" ON public.agriplan_plantations
  FOR SELECT TO authenticated USING (client_id = public.agriplan_mon_client_id());

DROP POLICY IF EXISTS "client lit ses visites" ON public.agriplan_visites;
CREATE POLICY "client lit ses visites" ON public.agriplan_visites
  FOR SELECT TO authenticated USING (client_id = public.agriplan_mon_client_id() AND publie = true);

DROP POLICY IF EXISTS "client lit ses documents" ON public.agriplan_documents;
CREATE POLICY "client lit ses documents" ON public.agriplan_documents
  FOR SELECT TO authenticated USING (client_id = public.agriplan_mon_client_id());

DROP POLICY IF EXISTS "client lit ses messages" ON public.agriplan_messages;
CREATE POLICY "client lit ses messages" ON public.agriplan_messages
  FOR SELECT TO authenticated USING (client_id = public.agriplan_mon_client_id());

DROP POLICY IF EXISTS "client ecrit ses messages" ON public.agriplan_messages;
CREATE POLICY "client ecrit ses messages" ON public.agriplan_messages
  FOR INSERT TO authenticated WITH CHECK (
    client_id = public.agriplan_mon_client_id() AND auteur_user_id = auth.uid()
  );

DROP POLICY IF EXISTS "client lit ses evenements" ON public.agriplan_evenements;
CREATE POLICY "client lit ses evenements" ON public.agriplan_evenements
  FOR SELECT TO authenticated USING (client_id = public.agriplan_mon_client_id() AND visible_client = true);

DROP POLICY IF EXISTS "client lit ses paiements agriplan" ON public.paiements;
CREATE POLICY "client lit ses paiements agriplan" ON public.paiements
  FOR SELECT TO authenticated USING (agriplan_client_id = public.agriplan_mon_client_id());