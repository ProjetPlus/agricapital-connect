-- 1. Historique des leads
CREATE TABLE IF NOT EXISTS public.lead_historique (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id uuid NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  action text NOT NULL,
  champ text,
  ancienne_valeur text,
  nouvelle_valeur text,
  commentaire text,
  acteur_id uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT ON public.lead_historique TO authenticated;
GRANT ALL ON public.lead_historique TO service_role;

ALTER TABLE public.lead_historique ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Lead actors view historique" ON public.lead_historique;
CREATE POLICY "Lead actors view historique"
ON public.lead_historique FOR SELECT TO authenticated
USING (EXISTS (
  SELECT 1 FROM public.leads l
  WHERE l.id = lead_historique.lead_id
    AND (l.created_by = auth.uid() OR l.assigned_to = auth.uid() OR public.can_supervise_leads(auth.uid()))
));

DROP POLICY IF EXISTS "Lead actors insert historique" ON public.lead_historique;
CREATE POLICY "Lead actors insert historique"
ON public.lead_historique FOR INSERT TO authenticated
WITH CHECK (acteur_id = auth.uid() AND EXISTS (
  SELECT 1 FROM public.leads l
  WHERE l.id = lead_historique.lead_id
    AND (l.created_by = auth.uid() OR l.assigned_to = auth.uid() OR public.can_supervise_leads(auth.uid()))
));

CREATE INDEX IF NOT EXISTS idx_lead_historique_lead ON public.lead_historique(lead_id, created_at DESC);

-- 2. Trigger de traçabilité automatique
CREATE OR REPLACE FUNCTION public.trace_lead_changes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.lead_historique(lead_id, action, commentaire, acteur_id, nouvelle_valeur)
    VALUES (NEW.id, 'creation', 'Prospect créé (source: ' || COALESCE(NEW.source,'—') || ')', COALESCE(NEW.created_by, auth.uid()), NEW.statut);
    RETURN NEW;
  END IF;

  IF NEW.assigned_to IS DISTINCT FROM OLD.assigned_to THEN
    INSERT INTO public.lead_historique(lead_id, action, champ, ancienne_valeur, nouvelle_valeur, acteur_id)
    VALUES (NEW.id, 'reaffectation', 'assigned_to', OLD.assigned_to::text, NEW.assigned_to::text, auth.uid());
  END IF;

  IF NEW.statut IS DISTINCT FROM OLD.statut THEN
    INSERT INTO public.lead_historique(lead_id, action, champ, ancienne_valeur, nouvelle_valeur, acteur_id)
    VALUES (NEW.id,
      CASE WHEN NEW.statut = 'converti' THEN 'conversion' ELSE 'changement_statut' END,
      'statut', OLD.statut, NEW.statut, auth.uid());
  END IF;

  IF NEW.souscripteur_id IS DISTINCT FROM OLD.souscripteur_id AND NEW.souscripteur_id IS NOT NULL THEN
    INSERT INTO public.lead_historique(lead_id, action, champ, ancienne_valeur, nouvelle_valeur, acteur_id)
    VALUES (NEW.id, 'conversion', 'souscripteur_id', OLD.souscripteur_id::text, NEW.souscripteur_id::text, auth.uid());
  END IF;

  IF (NEW.nom, NEW.prenoms, NEW.telephone, NEW.whatsapp, NEW.email, NEW.region_residence, NEW.commentaire)
     IS DISTINCT FROM (OLD.nom, OLD.prenoms, OLD.telephone, OLD.whatsapp, OLD.email, OLD.region_residence, OLD.commentaire) THEN
    INSERT INTO public.lead_historique(lead_id, action, commentaire, acteur_id)
    VALUES (NEW.id, 'modification', 'Coordonnées / informations mises à jour', auth.uid());
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_trace_lead_changes ON public.leads;
CREATE TRIGGER trg_trace_lead_changes
AFTER INSERT OR UPDATE ON public.leads
FOR EACH ROW EXECUTE FUNCTION public.trace_lead_changes();

-- 3. Réaffectation sécurisée
CREATE OR REPLACE FUNCTION public.reassign_lead(_lead_id uuid, _new_owner uuid, _motif text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_old uuid;
BEGIN
  IF NOT (public.can_supervise_leads(auth.uid()) OR public.is_admin(auth.uid())) THEN
    RAISE EXCEPTION 'Vous n''êtes pas autorisé à réaffecter ce prospect';
  END IF;

  SELECT assigned_to INTO v_old FROM public.leads WHERE id = _lead_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Prospect introuvable';
  END IF;

  UPDATE public.leads SET assigned_to = _new_owner, updated_at = now() WHERE id = _lead_id;

  INSERT INTO public.lead_historique(lead_id, action, champ, ancienne_valeur, nouvelle_valeur, commentaire, acteur_id)
  VALUES (_lead_id, 'reaffectation', 'assigned_to', v_old::text, _new_owner::text, _motif, auth.uid());
END;
$$;

REVOKE ALL ON FUNCTION public.reassign_lead(uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reassign_lead(uuid, uuid, text) TO authenticated;

-- 4. account_requests : élargir les rôles acceptés pour l'inscription directe
DROP POLICY IF EXISTS "Public can submit pending account requests" ON public.account_requests;
CREATE POLICY "Public can submit pending account requests"
ON public.account_requests FOR INSERT TO anon, authenticated
WITH CHECK (
  statut = 'en_attente'
  AND traite_par IS NULL AND traite_le IS NULL AND motif_rejet IS NULL
  AND nom_complet IS NOT NULL AND length(trim(nom_complet)) BETWEEN 2 AND 120
  AND email IS NOT NULL AND email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'
  AND telephone IS NOT NULL AND length(trim(telephone)) >= 8
  AND role_souhaite = ANY (ARRAY[
    'commercial','technicien','chef_equipe_commercial','chef_equipe_technique',
    'responsable_commercial','responsable_technique_agronomique','responsable_zone',
    'superviseur_tc','chef_equipe','comptable','service_client','operations','agent_terrain','user'
  ])
  AND (photo_url IS NULL OR photo_url LIKE '%/storage/v1/object/%/documents/account-requests/%')
  AND (cv_url IS NULL OR cv_url LIKE '%/storage/v1/object/%/documents/account-requests/%')
);

CREATE INDEX IF NOT EXISTS idx_account_requests_statut ON public.account_requests(statut, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_account_requests_username_unique ON public.account_requests(lower(username)) WHERE username IS NOT NULL;