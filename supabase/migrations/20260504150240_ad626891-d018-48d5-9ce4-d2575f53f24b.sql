
-- ============================================================================
-- MIGRATION RÉFÉRENCEMENT V3 — AgriCapital
-- ============================================================================

-- 1) SOUS-PRÉFECTURES : code SP national unique
ALTER TABLE public.sous_prefectures
  ADD COLUMN IF NOT EXISTS code_sp TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS sp_assigned_at TIMESTAMPTZ;

CREATE SEQUENCE IF NOT EXISTS public.sp_code_seq START 1;

CREATE OR REPLACE FUNCTION public.assign_sp_code(_sp_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code TEXT;
  v_existing TEXT;
BEGIN
  SELECT code_sp INTO v_existing FROM public.sous_prefectures WHERE id = _sp_id;
  IF v_existing IS NOT NULL THEN
    RETURN v_existing;
  END IF;
  v_code := 'SP' || LPAD(nextval('public.sp_code_seq')::TEXT, 3, '0');
  UPDATE public.sous_prefectures
    SET code_sp = v_code, sp_assigned_at = now()
    WHERE id = _sp_id;
  RETURN v_code;
END;
$$;

GRANT EXECUTE ON FUNCTION public.assign_sp_code(UUID) TO authenticated;

-- 2) DOMAINES — regroupement village/zone
CREATE TABLE IF NOT EXISTS public.domaines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code_dom TEXT UNIQUE NOT NULL,
  nom TEXT NOT NULL,
  description TEXT,
  sous_prefecture_id UUID REFERENCES public.sous_prefectures(id) ON DELETE RESTRICT,
  village TEXT,
  created_by UUID,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.domaines ENABLE ROW LEVEL SECURITY;

CREATE SEQUENCE IF NOT EXISTS public.domaine_code_seq START 1;

CREATE OR REPLACE FUNCTION public.set_domaine_code()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.code_dom IS NULL OR NEW.code_dom = '' THEN
    NEW.code_dom := 'DOM' || LPAD(nextval('public.domaine_code_seq')::TEXT, 3, '0');
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_domaine_code ON public.domaines;
CREATE TRIGGER trg_set_domaine_code
  BEFORE INSERT OR UPDATE ON public.domaines
  FOR EACH ROW EXECUTE FUNCTION public.set_domaine_code();

CREATE POLICY "Anyone authenticated reads domaines"
  ON public.domaines FOR SELECT TO authenticated USING (true);
CREATE POLICY "Staff manage domaines"
  ON public.domaines FOR ALL TO authenticated
  USING (public.is_staff(auth.uid()))
  WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Admins delete domaines"
  ON public.domaines FOR DELETE TO authenticated
  USING (public.is_admin(auth.uid()));

-- 3) CONVENTIONS FONCIÈRES (Planté-Partagé)
CREATE TABLE IF NOT EXISTS public.conventions_foncieres (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reference TEXT UNIQUE,
  proprietaire_id UUID NOT NULL,
  parcelle_id UUID,
  domaine_id UUID REFERENCES public.domaines(id),
  sous_prefecture_id UUID REFERENCES public.sous_prefectures(id),
  code_sp TEXT,
  code_dom TEXT,
  code_parc TEXT,
  type_convention TEXT NOT NULL DEFAULT 'PP',
  duree_ans INTEGER DEFAULT 30,
  date_signature DATE,
  date_debut DATE,
  date_fin DATE,
  surface_totale_ha NUMERIC DEFAULT 0,
  statut TEXT DEFAULT 'active',
  fichier_convention_url TEXT,
  notes TEXT,
  created_by UUID,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.conventions_foncieres ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Staff manage conventions"
  ON public.conventions_foncieres FOR ALL TO authenticated
  USING (public.is_staff(auth.uid()))
  WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Admins delete conventions"
  ON public.conventions_foncieres FOR DELETE TO authenticated
  USING (public.is_admin(auth.uid()));

-- 4) PARCELLES : code parc + lien domaine
ALTER TABLE public.parcelles
  ADD COLUMN IF NOT EXISTS domaine_id UUID REFERENCES public.domaines(id),
  ADD COLUMN IF NOT EXISTS code_parc TEXT,
  ADD COLUMN IF NOT EXISTS reference_convention TEXT,
  ADD COLUMN IF NOT EXISTS convention_id UUID REFERENCES public.conventions_foncieres(id);

CREATE SEQUENCE IF NOT EXISTS public.parcelle_code_seq START 1;

CREATE OR REPLACE FUNCTION public.set_parcelle_code()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.code_parc IS NULL OR NEW.code_parc = '' THEN
    NEW.code_parc := 'PARC' || LPAD(nextval('public.parcelle_code_seq')::TEXT, 3, '0');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_parcelle_code ON public.parcelles;
CREATE TRIGGER trg_set_parcelle_code
  BEFORE INSERT ON public.parcelles
  FOR EACH ROW EXECUTE FUNCTION public.set_parcelle_code();

-- 5) Génération référence convention
CREATE OR REPLACE FUNCTION public.generate_convention_reference()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sp_code TEXT;
  v_dom_code TEXT;
  v_parc_code TEXT;
BEGIN
  -- Assigne le code SP si pas encore fait
  IF NEW.sous_prefecture_id IS NOT NULL THEN
    v_sp_code := public.assign_sp_code(NEW.sous_prefecture_id);
    NEW.code_sp := v_sp_code;
  END IF;

  IF NEW.domaine_id IS NOT NULL THEN
    SELECT code_dom INTO v_dom_code FROM public.domaines WHERE id = NEW.domaine_id;
    NEW.code_dom := v_dom_code;
  END IF;

  IF NEW.parcelle_id IS NOT NULL THEN
    SELECT code_parc INTO v_parc_code FROM public.parcelles WHERE id = NEW.parcelle_id;
    NEW.code_parc := v_parc_code;
  END IF;

  IF NEW.reference IS NULL OR NEW.reference = '' THEN
    NEW.reference := 'AC-PP-' 
      || COALESCE(NEW.code_sp, 'SP000') || '-'
      || COALESCE(NEW.code_dom, 'DOM000') || '-'
      || COALESCE(NEW.code_parc, 'PARC000');
  END IF;

  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_generate_convention_reference ON public.conventions_foncieres;
CREATE TRIGGER trg_generate_convention_reference
  BEFORE INSERT OR UPDATE ON public.conventions_foncieres
  FOR EACH ROW EXECUTE FUNCTION public.generate_convention_reference();

-- 6) LOTS HECTARES (géomètre)
CREATE TABLE IF NOT EXISTS public.lots_hectares (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reference TEXT UNIQUE,
  convention_id UUID REFERENCES public.conventions_foncieres(id) ON DELETE CASCADE,
  parcelle_id UUID,
  numero_h INTEGER NOT NULL,
  surface_ha NUMERIC DEFAULT 1.0,
  polygone_gps JSONB,
  centroid_lat NUMERIC,
  centroid_lng NUMERIC,
  statut TEXT DEFAULT 'disponible',
  souscripteur_id UUID,
  date_attribution DATE,
  certifie_geometre BOOLEAN DEFAULT false,
  date_certification DATE,
  geometre_nom TEXT,
  fichier_plan_url TEXT,
  notes TEXT,
  created_by UUID,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (convention_id, numero_h)
);

ALTER TABLE public.lots_hectares ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.set_lot_reference()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_conv_ref TEXT;
BEGIN
  IF NEW.reference IS NULL OR NEW.reference = '' THEN
    SELECT reference INTO v_conv_ref FROM public.conventions_foncieres WHERE id = NEW.convention_id;
    NEW.reference := COALESCE(v_conv_ref, 'AC-PP-SP000-DOM000-PARC000') 
      || '-H' || LPAD(NEW.numero_h::TEXT, 2, '0');
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_lot_reference ON public.lots_hectares;
CREATE TRIGGER trg_set_lot_reference
  BEFORE INSERT OR UPDATE ON public.lots_hectares
  FOR EACH ROW EXECUTE FUNCTION public.set_lot_reference();

CREATE POLICY "Staff manage lots"
  ON public.lots_hectares FOR ALL TO authenticated
  USING (public.is_staff(auth.uid()))
  WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Souscripteurs read own lots"
  ON public.lots_hectares FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.souscripteurs s
      WHERE s.id = lots_hectares.souscripteur_id
        AND s.user_id = auth.uid()
    )
  );
CREATE POLICY "Admins delete lots"
  ON public.lots_hectares FOR DELETE TO authenticated
  USING (public.is_admin(auth.uid()));

-- 7) SOUSCRIPTEURS : numéro de contrat V3
ALTER TABLE public.souscripteurs
  ADD COLUMN IF NOT EXISTS numero_contrat TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS annee_contrat INTEGER,
  ADD COLUMN IF NOT EXISTS code_sp_contrat TEXT,
  ADD COLUMN IF NOT EXISTS numero_ordre_global INTEGER,
  ADD COLUMN IF NOT EXISTS type_souscripteur_foncier TEXT DEFAULT 'EXT';

CREATE SEQUENCE IF NOT EXISTS public.souscripteur_global_counter START 1;

CREATE OR REPLACE FUNCTION public.generate_numero_contrat_souscripteur()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sp_code TEXT;
  v_year INTEGER;
  v_ordre INTEGER;
BEGIN
  IF NEW.numero_contrat IS NOT NULL AND NEW.numero_contrat <> '' THEN
    RETURN NEW;
  END IF;

  v_year := COALESCE(NEW.annee_contrat, EXTRACT(YEAR FROM now())::INTEGER);
  NEW.annee_contrat := v_year;

  IF NEW.sous_prefecture_id IS NOT NULL THEN
    v_sp_code := public.assign_sp_code(NEW.sous_prefecture_id);
  END IF;
  NEW.code_sp_contrat := COALESCE(v_sp_code, 'SP000');

  v_ordre := nextval('public.souscripteur_global_counter')::INTEGER;
  NEW.numero_ordre_global := v_ordre;

  NEW.numero_contrat := 'AGC-SUB-' || v_year::TEXT || '-' 
    || NEW.code_sp_contrat || '-'
    || LPAD(v_ordre::TEXT, 4, '0');

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_generate_numero_contrat ON public.souscripteurs;
CREATE TRIGGER trg_generate_numero_contrat
  BEFORE INSERT ON public.souscripteurs
  FOR EACH ROW EXECUTE FUNCTION public.generate_numero_contrat_souscripteur();

-- 8) SOUSCRIPTION ↔ LOTS (table de liaison N–N)
CREATE TABLE IF NOT EXISTS public.souscription_lots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  souscripteur_id UUID NOT NULL,
  lot_id UUID NOT NULL REFERENCES public.lots_hectares(id) ON DELETE CASCADE,
  date_attribution DATE DEFAULT CURRENT_DATE,
  surface_ha NUMERIC DEFAULT 1.0,
  notes TEXT,
  created_by UUID,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (souscripteur_id, lot_id)
);

ALTER TABLE public.souscription_lots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Staff manage souscription_lots"
  ON public.souscription_lots FOR ALL TO authenticated
  USING (public.is_staff(auth.uid()))
  WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Souscripteurs read own lots attribution"
  ON public.souscription_lots FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.souscripteurs s
      WHERE s.id = souscription_lots.souscripteur_id
        AND s.user_id = auth.uid()
    )
  );
CREATE POLICY "Admins delete souscription_lots"
  ON public.souscription_lots FOR DELETE TO authenticated
  USING (public.is_admin(auth.uid()));

-- 9) Index utiles
CREATE INDEX IF NOT EXISTS idx_lots_convention ON public.lots_hectares(convention_id);
CREATE INDEX IF NOT EXISTS idx_lots_souscripteur ON public.lots_hectares(souscripteur_id);
CREATE INDEX IF NOT EXISTS idx_souscripteurs_numero_contrat ON public.souscripteurs(numero_contrat);
CREATE INDEX IF NOT EXISTS idx_conventions_proprietaire ON public.conventions_foncieres(proprietaire_id);
CREATE INDEX IF NOT EXISTS idx_parcelles_domaine ON public.parcelles(domaine_id);
CREATE INDEX IF NOT EXISTS idx_parcelles_convention ON public.parcelles(convention_id);

-- 10) Grants nécessaires
GRANT EXECUTE ON FUNCTION public.generate_convention_reference() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_lot_reference() TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_numero_contrat_souscripteur() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_domaine_code() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_parcelle_code() TO authenticated;
