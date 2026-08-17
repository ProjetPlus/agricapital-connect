
-- Relax type_remuneration check to accept new types
ALTER TABLE public.grille_remuneration DROP CONSTRAINT IF EXISTS grille_remuneration_type_remuneration_check;
ALTER TABLE public.grille_remuneration ADD CONSTRAINT grille_remuneration_type_remuneration_check
  CHECK (type_remuneration IN (
    'souscription','recouvrement_mensuel','cash','salaire_fixe','prime_ha','bonus_qualite',
    'commission_ha_signature','commission_cash','commission_surplus_di','commission_recouvrement',
    'bonus_palier','objectif_mensuel'
  ));

-- Deactivate duplicate uppercase offer codes
UPDATE public.offres SET actif = false WHERE code IN ('PALMINVEST','PALMINVEST_PLUS','TERRAPALM','TERRAPALM_PLUS');

-- Password field on account requests
ALTER TABLE public.account_requests ADD COLUMN IF NOT EXISTS password_souhaite text;

-- Promotion cible validation (allow depot_initial | total_contrat | special)
CREATE OR REPLACE FUNCTION public.validate_promotion_cible()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.cible IS NULL THEN NEW.cible := 'depot_initial'; END IF;
  IF NEW.cible NOT IN ('depot_initial','total_contrat','special') THEN
    RAISE EXCEPTION 'promotions.cible invalide: %', NEW.cible;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_validate_promotion_cible ON public.promotions;
CREATE TRIGGER trg_validate_promotion_cible BEFORE INSERT OR UPDATE ON public.promotions
FOR EACH ROW EXECUTE FUNCTION public.validate_promotion_cible();

-- Seed commercial commission grid
DELETE FROM public.grille_remuneration WHERE role_cible='commercial';
INSERT INTO public.grille_remuneration (role_cible,type_remuneration,montant,taux_pourcentage,annee_application,description,actif) VALUES
 ('commercial','commission_ha_signature',10000,NULL,NULL,'FCFA/ha vendu (après DI validé, quinzaine suivante)',true),
 ('commercial','commission_cash',NULL,2.0,NULL,'2% du cash total encaissé',true),
 ('commercial','commission_surplus_di',NULL,2.5,NULL,'2,5% du surplus DI',true),
 ('commercial','commission_recouvrement',NULL,2.5,1,'An1 M1-M12 : 2,5%/mensualité',true),
 ('commercial','commission_recouvrement',NULL,1.5,2,'An2 M13-M24 : 1,5%',true),
 ('commercial','commission_recouvrement',NULL,1.0,3,'An3 M25-M35 : 1,0%',true),
 ('commercial','bonus_palier',15000,NULL,10,'Palier 10 ha/mois (PH<25%)',true),
 ('commercial','bonus_palier',25000,NULL,15,'Palier 15 ha/mois',true),
 ('commercial','bonus_palier',35000,NULL,20,'Palier 20 ha/mois',true),
 ('commercial','bonus_palier',50000,NULL,25,'Palier 25 ha/mois - cible',true),
 ('commercial','objectif_mensuel',5,NULL,1,'M1-M6 Démarrage',true),
 ('commercial','objectif_mensuel',10,NULL,2,'M7-M12 Montée',true),
 ('commercial','objectif_mensuel',15,NULL,3,'M13-M18 Développement',true),
 ('commercial','objectif_mensuel',20,NULL,4,'M19-M24 Accélération',true),
 ('commercial','objectif_mensuel',25,NULL,5,'M25-M30 Performance',true),
 ('commercial','objectif_mensuel',25,NULL,6,'M31-M36 Consolidation',true);

-- Commissions table: add columns needed
ALTER TABLE public.commissions
  ADD COLUMN IF NOT EXISTS paiement_id uuid,
  ADD COLUMN IF NOT EXISTS souscripteur_id uuid,
  ADD COLUMN IF NOT EXISTS type_commission text,
  ADD COLUMN IF NOT EXISTS taux_applique numeric,
  ADD COLUMN IF NOT EXISTS annee_contrat int,
  ADD COLUMN IF NOT EXISTS statut text DEFAULT 'calculee';
CREATE UNIQUE INDEX IF NOT EXISTS commissions_paiement_unique ON public.commissions(paiement_id) WHERE paiement_id IS NOT NULL;

-- Compute commission
CREATE OR REPLACE FUNCTION public.compute_commission_for_paiement(p_paiement_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  p RECORD; v_s RECORD; v_com uuid; v_taux numeric := 0; v_montant numeric := 0;
  v_type text := 'recouvrement'; v_annee int := 1; v_mois int;
BEGIN
  SELECT * INTO p FROM public.paiements WHERE id = p_paiement_id;
  IF NOT FOUND OR COALESCE(p.statut,'') <> 'valide' THEN RETURN; END IF;
  SELECT s.*, s.cree_par AS commercial_id INTO v_s FROM public.souscripteurs s WHERE s.id = p.souscripteur_id;
  IF NOT FOUND OR v_s.commercial_id IS NULL THEN RETURN; END IF;
  v_com := v_s.commercial_id;
  v_mois := GREATEST(0, (EXTRACT(YEAR FROM AGE(p.date_paiement, COALESCE(v_s.date_souscription, v_s.created_at)))*12
    + EXTRACT(MONTH FROM AGE(p.date_paiement, COALESCE(v_s.date_souscription, v_s.created_at))))::int);
  IF v_mois < 12 THEN v_annee := 1; ELSIF v_mois < 24 THEN v_annee := 2; ELSE v_annee := 3; END IF;

  IF COALESCE(p.type_paiement,'') IN ('depot_initial','di') THEN
    v_type := 'signature';
    SELECT montant INTO v_montant FROM public.grille_remuneration
      WHERE role_cible='commercial' AND type_remuneration='commission_ha_signature' AND actif LIMIT 1;
    v_montant := COALESCE(v_montant,10000) * COALESCE(v_s.superficie_prevue,1);
  ELSIF COALESCE(p.type_paiement,'') = 'cash' THEN
    v_type := 'cash';
    SELECT taux_pourcentage INTO v_taux FROM public.grille_remuneration
      WHERE role_cible='commercial' AND type_remuneration='commission_cash' AND actif LIMIT 1;
    v_montant := p.montant * COALESCE(v_taux,2)/100.0;
  ELSE
    v_type := 'recouvrement';
    SELECT taux_pourcentage INTO v_taux FROM public.grille_remuneration
      WHERE role_cible='commercial' AND type_remuneration='commission_recouvrement'
        AND annee_application=v_annee AND actif LIMIT 1;
    v_montant := p.montant * COALESCE(v_taux,1)/100.0;
  END IF;

  IF v_montant > 0 THEN
    INSERT INTO public.commissions (commercial_id, paiement_id, souscripteur_id, type_commission, montant, taux_applique, annee_contrat, statut)
    VALUES (v_com, p.id, p.souscripteur_id, v_type, v_montant, COALESCE(v_taux,0), v_annee, 'calculee')
    ON CONFLICT DO NOTHING;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.trg_paiement_commission()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.statut='valide' AND (TG_OP='INSERT' OR OLD.statut IS DISTINCT FROM 'valide') THEN
    PERFORM public.compute_commission_for_paiement(NEW.id);
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_paiement_commission ON public.paiements;
CREATE TRIGGER trg_paiement_commission AFTER INSERT OR UPDATE ON public.paiements
FOR EACH ROW EXECUTE FUNCTION public.trg_paiement_commission();
