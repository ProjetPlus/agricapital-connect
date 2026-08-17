
CREATE OR REPLACE FUNCTION public.recompute_pending_di()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  r RECORD;
  v_di numeric; v_total numeric; v_duree int; v_taux numeric;
  v_tranches jsonb; v_mens numeric; v_ha numeric;
BEGIN
  FOR r IN
    SELECT s.id AS sid, s.offre_id, s.total_hectares
      FROM public.souscripteurs s
     WHERE COALESCE(s.compte_actif,false) = false
       AND s.offre_id IS NOT NULL
  LOOP
    SELECT di_effectif, total_effectif INTO v_di, v_total
      FROM public.v_prix_effectif_offres WHERE offre_id = r.offre_id;
    SELECT duree_paiement_mois, tranches_paiement INTO v_duree, v_tranches
      FROM public.offres WHERE id = r.offre_id;

    v_ha := COALESCE(r.total_hectares, 0);
    IF v_di IS NULL OR v_ha <= 0 THEN CONTINUE; END IF;

    v_taux := CASE WHEN COALESCE(v_duree,0) > 0 THEN v_total / (v_duree * 30) ELSE 0 END;
    v_mens := 0;
    IF v_tranches IS NOT NULL AND jsonb_typeof(v_tranches) = 'array' AND jsonb_array_length(v_tranches) > 0 THEN
      v_mens := COALESCE((v_tranches->0->>'mensualite_par_ha')::numeric, 0) * v_ha;
    END IF;

    UPDATE public.souscripteurs
       SET montant_total_contrat = v_total * v_ha,
           jours_contrat_total = COALESCE(v_duree,34) * 30,
           taux_journalier_ha = v_taux,
           mensualite_montant = v_mens,
           updated_at = now()
     WHERE id = r.sid;

    UPDATE public.paiements
       SET montant = v_di * v_ha,
           montant_theorique = v_di * v_ha,
           updated_at = now()
     WHERE souscripteur_id = r.sid
       AND est_depot_initial = true
       AND statut = 'en_attente';
  END LOOP;
END; $$;

DROP TRIGGER IF EXISTS trg_offres_recompute ON public.offres;
CREATE TRIGGER trg_offres_recompute
  AFTER UPDATE OF montant_depot_initial_par_ha, montant_total_par_ha, montant_cash_par_ha, tranches_paiement, duree_paiement_mois
  ON public.offres
  FOR EACH STATEMENT EXECUTE FUNCTION public.trg_recompute_di_on_change();

CREATE OR REPLACE FUNCTION public.trg_souscripteur_recompute()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_di numeric; v_total numeric; v_duree int; v_taux numeric;
  v_tranches jsonb; v_mens numeric; v_ha numeric;
BEGIN
  IF COALESCE(NEW.compte_actif,false) = true OR NEW.offre_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE'
     AND NEW.offre_id IS NOT DISTINCT FROM OLD.offre_id
     AND NEW.promotion_id IS NOT DISTINCT FROM OLD.promotion_id
     AND NEW.total_hectares IS NOT DISTINCT FROM OLD.total_hectares THEN
    RETURN NEW;
  END IF;

  SELECT di_effectif, total_effectif INTO v_di, v_total
    FROM public.v_prix_effectif_offres WHERE offre_id = NEW.offre_id;
  SELECT duree_paiement_mois, tranches_paiement INTO v_duree, v_tranches
    FROM public.offres WHERE id = NEW.offre_id;

  v_ha := COALESCE(NEW.total_hectares, 0);
  IF v_di IS NULL OR v_ha <= 0 THEN RETURN NEW; END IF;

  v_taux := CASE WHEN COALESCE(v_duree,0) > 0 THEN v_total / (v_duree * 30) ELSE 0 END;
  v_mens := 0;
  IF v_tranches IS NOT NULL AND jsonb_typeof(v_tranches) = 'array' AND jsonb_array_length(v_tranches) > 0 THEN
    v_mens := COALESCE((v_tranches->0->>'mensualite_par_ha')::numeric, 0) * v_ha;
  END IF;

  NEW.montant_total_contrat := v_total * v_ha;
  NEW.jours_contrat_total := COALESCE(v_duree,34) * 30;
  NEW.taux_journalier_ha := v_taux;
  NEW.mensualite_montant := v_mens;

  UPDATE public.paiements
     SET montant = v_di * v_ha,
         montant_theorique = v_di * v_ha,
         updated_at = now()
   WHERE souscripteur_id = NEW.id
     AND est_depot_initial = true
     AND statut = 'en_attente';

  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_souscripteur_recompute ON public.souscripteurs;
CREATE TRIGGER trg_souscripteur_recompute
  BEFORE INSERT OR UPDATE OF offre_id, promotion_id, total_hectares
  ON public.souscripteurs
  FOR EACH ROW EXECUTE FUNCTION public.trg_souscripteur_recompute();

SELECT public.recompute_pending_di();
