
-- 1. Paiements: non-staff may only touch refund request columns
CREATE OR REPLACE FUNCTION public.guard_paiements_self_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR public.is_admin(auth.uid()) OR public.is_staff(auth.uid()) THEN
    RETURN NEW;
  END IF;

  NEW.id := OLD.id;
  NEW.souscripteur_id := OLD.souscripteur_id;
  NEW.plantation_id := OLD.plantation_id;
  NEW.montant := OLD.montant;
  NEW.montant_paye := OLD.montant_paye;
  NEW.montant_theorique := OLD.montant_theorique;
  NEW.type_paiement := OLD.type_paiement;
  NEW.mode_paiement := OLD.mode_paiement;
  NEW.statut := OLD.statut;
  NEW.reference := OLD.reference;
  NEW.date_paiement := OLD.date_paiement;
  NEW.date_echeance := OLD.date_echeance;
  NEW.preuve_paiement_url := OLD.preuve_paiement_url;
  NEW.metadata := OLD.metadata;
  NEW.notes := OLD.notes;
  NEW.valide_par := OLD.valide_par;
  NEW.date_validation := OLD.date_validation;
  NEW.created_by := OLD.created_by;
  NEW.created_at := OLD.created_at;
  NEW.kkiapay_transaction_id := OLD.kkiapay_transaction_id;
  NEW.refunded_at := OLD.refunded_at;
  NEW.cancelled_at := OLD.cancelled_at;
  NEW.annee := OLD.annee;
  NEW.type_preuve := OLD.type_preuve;
  NEW.id_transaction := OLD.id_transaction;
  NEW.operateur_mobile_money := OLD.operateur_mobile_money;
  NEW.fichier_preuve_url := OLD.fichier_preuve_url;
  NEW.date_upload_preuve := OLD.date_upload_preuve;
  NEW.observations := OLD.observations;
  NEW.est_depot_initial := OLD.est_depot_initial;
  NEW.numero_echeance := OLD.numero_echeance;
  NEW.jours_couverts := OLD.jours_couverts;
  NEW.periode_debut := OLD.periode_debut;
  NEW.periode_fin := OLD.periode_fin;
  NEW.phase := OLD.phase;
  NEW.jours_retard := OLD.jours_retard;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_paiements_self_update ON public.paiements;
CREATE TRIGGER guard_paiements_self_update
  BEFORE UPDATE ON public.paiements
  FOR EACH ROW EXECUTE FUNCTION public.guard_paiements_self_update();

-- 2. Profiles: protect sensitive HR / compensation columns from self-edit
CREATE OR REPLACE FUNCTION public.guard_profiles_sensitive_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR public.is_admin(auth.uid()) THEN
    RETURN NEW;
  END IF;

  NEW.user_id := OLD.user_id;
  NEW.taux_commission := OLD.taux_commission;
  NEW.poste := OLD.poste;
  NEW.equipe_id := OLD.equipe_id;
  NEW.actif := OLD.actif;
  NEW.district_id := OLD.district_id;
  NEW.region_id := OLD.region_id;
  NEW.departement := OLD.departement;
  NEW.relation_rh := OLD.relation_rh;
  NEW.username := OLD.username;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_profiles_sensitive_update ON public.profiles;
CREATE TRIGGER guard_profiles_sensitive_update
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.guard_profiles_sensitive_update();

-- 3. Retraits portefeuille: no self-approval
CREATE OR REPLACE FUNCTION public.guard_retraits_self_approval()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR public.is_admin(auth.uid()) THEN
    RETURN NEW;
  END IF;

  NEW.portefeuille_id := OLD.portefeuille_id;
  NEW.user_id := OLD.user_id;
  NEW.montant := OLD.montant;
  NEW.statut := OLD.statut;
  NEW.traite_par := OLD.traite_par;
  NEW.date_traitement := OLD.date_traitement;
  NEW.date_demande := OLD.date_demande;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_retraits_self_approval ON public.retraits_portefeuille;
CREATE TRIGGER guard_retraits_self_approval
  BEFORE UPDATE ON public.retraits_portefeuille
  FOR EACH ROW EXECUTE FUNCTION public.guard_retraits_self_approval();
