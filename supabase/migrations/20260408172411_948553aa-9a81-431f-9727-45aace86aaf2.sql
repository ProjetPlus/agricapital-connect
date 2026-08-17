
-- 1. Ajout colonnes sur souscripteurs et plantations EN PREMIER
ALTER TABLE public.souscripteurs 
  ADD COLUMN IF NOT EXISTS type_souscripteur TEXT DEFAULT 'sans_terre',
  ADD COLUMN IF NOT EXISTS parcelle_id UUID;

ALTER TABLE public.plantations
  ADD COLUMN IF NOT EXISTS parcelle_id UUID;

-- 2. Table proprietaires_terres
CREATE TABLE IF NOT EXISTS public.proprietaires_terres (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  id_unique TEXT,
  civilite TEXT,
  nom TEXT NOT NULL,
  prenoms TEXT,
  nom_complet TEXT,
  date_naissance DATE,
  lieu_naissance TEXT,
  telephone TEXT NOT NULL,
  whatsapp TEXT,
  email TEXT,
  type_piece TEXT,
  numero_piece TEXT,
  date_delivrance_piece DATE,
  fichier_piece_recto_url TEXT,
  fichier_piece_verso_url TEXT,
  photo_profil_url TEXT,
  domicile TEXT,
  district_id UUID REFERENCES public.districts(id),
  region_id UUID REFERENCES public.regions(id),
  departement_id UUID REFERENCES public.departements(id),
  sous_prefecture_id UUID REFERENCES public.sous_prefectures(id),
  village TEXT,
  statut TEXT DEFAULT 'actif',
  nombre_parcelles INTEGER DEFAULT 0,
  surface_totale_ha NUMERIC DEFAULT 0,
  notes TEXT,
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.proprietaires_terres ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Staff can view proprietaires" ON public.proprietaires_terres FOR SELECT TO authenticated USING (is_staff(auth.uid()));
CREATE POLICY "Staff can insert proprietaires" ON public.proprietaires_terres FOR INSERT TO authenticated WITH CHECK (is_staff(auth.uid()));
CREATE POLICY "Staff can update proprietaires" ON public.proprietaires_terres FOR UPDATE TO authenticated USING (is_staff(auth.uid()));
CREATE POLICY "Admins can delete proprietaires" ON public.proprietaires_terres FOR DELETE TO authenticated USING (is_admin(auth.uid()));

-- 3. Table parcelles
CREATE TABLE IF NOT EXISTS public.parcelles (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  id_unique TEXT,
  proprietaire_id UUID REFERENCES public.proprietaires_terres(id) ON DELETE SET NULL,
  nom TEXT,
  surface_totale_ha NUMERIC NOT NULL DEFAULT 0,
  surface_proprietaire_ha NUMERIC NOT NULL DEFAULT 0,
  surface_agricapital_ha NUMERIC NOT NULL DEFAULT 0,
  surface_attribuee_ha NUMERIC NOT NULL DEFAULT 0,
  surface_disponible_ha NUMERIC NOT NULL DEFAULT 0,
  district_id UUID REFERENCES public.districts(id),
  region_id UUID REFERENCES public.regions(id),
  departement_id UUID REFERENCES public.departements(id),
  sous_prefecture_id UUID REFERENCES public.sous_prefectures(id),
  village TEXT,
  localisation_gps_lat NUMERIC,
  localisation_gps_lng NUMERIC,
  polygone_gps JSONB,
  duree_convention INTEGER DEFAULT 30,
  date_convention DATE,
  statut TEXT DEFAULT 'disponible',
  notes TEXT,
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.parcelles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Staff can view parcelles" ON public.parcelles FOR SELECT TO authenticated USING (is_staff(auth.uid()));
CREATE POLICY "Staff can insert parcelles" ON public.parcelles FOR INSERT TO authenticated WITH CHECK (is_staff(auth.uid()));
CREATE POLICY "Staff can update parcelles" ON public.parcelles FOR UPDATE TO authenticated USING (is_staff(auth.uid()));
CREATE POLICY "Admins can delete parcelles" ON public.parcelles FOR DELETE TO authenticated USING (is_admin(auth.uid()));

-- 4. Now add FK constraints
ALTER TABLE public.souscripteurs ADD CONSTRAINT souscripteurs_parcelle_id_fkey FOREIGN KEY (parcelle_id) REFERENCES public.parcelles(id);
ALTER TABLE public.plantations ADD CONSTRAINT plantations_parcelle_id_fkey FOREIGN KEY (parcelle_id) REFERENCES public.parcelles(id);

-- 5. Souscripteurs portal can see their parcelles
CREATE POLICY "Souscripteurs view own parcelles" ON public.parcelles
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.souscripteurs s
    JOIN public.plantations p ON p.souscripteur_id = s.id
    WHERE p.parcelle_id = parcelles.id AND s.user_id = auth.uid()
  ));

-- 6. ID generators
CREATE OR REPLACE FUNCTION public.generate_parcelle_id()
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE new_id TEXT; seq INTEGER;
BEGIN
  SELECT COALESCE(MAX(CAST(SUBSTRING(id_unique FROM 5) AS INTEGER)), 0) + 1 INTO seq FROM public.parcelles WHERE id_unique LIKE 'PAR-%';
  new_id := 'PAR-' || LPAD(seq::TEXT, 6, '0');
  RETURN new_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.generate_proprietaire_id()
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE new_id TEXT; seq INTEGER;
BEGIN
  SELECT COALESCE(MAX(CAST(SUBSTRING(id_unique FROM 5) AS INTEGER)), 0) + 1 INTO seq FROM public.proprietaires_terres WHERE id_unique LIKE 'PRP-%';
  new_id := 'PRP-' || LPAD(seq::TEXT, 6, '0');
  RETURN new_id;
END;
$$;

-- 7. Trigger: auto-calculate parcelle surfaces (50/50)
CREATE OR REPLACE FUNCTION public.calculate_parcelle_surfaces()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  NEW.surface_proprietaire_ha := NEW.surface_totale_ha / 2;
  NEW.surface_agricapital_ha := NEW.surface_totale_ha / 2;
  NEW.surface_disponible_ha := NEW.surface_agricapital_ha - COALESCE(NEW.surface_attribuee_ha, 0);
  IF NEW.surface_disponible_ha < 0 THEN
    RAISE EXCEPTION 'Surface disponible insuffisante sur cette parcelle';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_calculate_parcelle_surfaces
  BEFORE INSERT OR UPDATE ON public.parcelles
  FOR EACH ROW EXECUTE FUNCTION public.calculate_parcelle_surfaces();

-- 8. Trigger: update parcelle on plantation change
CREATE OR REPLACE FUNCTION public.update_parcelle_attribution()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_parcelle_id UUID; v_total NUMERIC;
BEGIN
  v_parcelle_id := COALESCE(NEW.parcelle_id, OLD.parcelle_id);
  IF v_parcelle_id IS NULL THEN RETURN COALESCE(NEW, OLD); END IF;
  SELECT COALESCE(SUM(superficie_ha), 0) INTO v_total FROM public.plantations WHERE parcelle_id = v_parcelle_id;
  UPDATE public.parcelles SET surface_attribuee_ha = v_total,
    statut = CASE WHEN v_total >= surface_agricapital_ha THEN 'saturee' WHEN v_total > 0 THEN 'partiellement_attribuee' ELSE 'disponible' END
  WHERE id = v_parcelle_id;
  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trigger_update_parcelle_attribution
  AFTER INSERT OR UPDATE OR DELETE ON public.plantations
  FOR EACH ROW EXECUTE FUNCTION public.update_parcelle_attribution();

-- 9. Trigger: update proprietaire stats
CREATE OR REPLACE FUNCTION public.update_proprietaire_stats()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_prop_id UUID; v_count INTEGER; v_total NUMERIC;
BEGIN
  v_prop_id := COALESCE(NEW.proprietaire_id, OLD.proprietaire_id);
  IF v_prop_id IS NULL THEN RETURN COALESCE(NEW, OLD); END IF;
  SELECT COUNT(*), COALESCE(SUM(surface_totale_ha), 0) INTO v_count, v_total FROM public.parcelles WHERE proprietaire_id = v_prop_id;
  UPDATE public.proprietaires_terres SET nombre_parcelles = v_count, surface_totale_ha = v_total WHERE id = v_prop_id;
  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trigger_update_proprietaire_stats
  AFTER INSERT OR UPDATE OR DELETE ON public.parcelles
  FOR EACH ROW EXECUTE FUNCTION public.update_proprietaire_stats();

-- 10. updated_at triggers
CREATE TRIGGER update_proprietaires_updated_at BEFORE UPDATE ON public.proprietaires_terres FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_parcelles_updated_at BEFORE UPDATE ON public.parcelles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 11. Indexes
CREATE INDEX IF NOT EXISTS idx_parcelles_proprietaire ON public.parcelles(proprietaire_id);
CREATE INDEX IF NOT EXISTS idx_parcelles_statut ON public.parcelles(statut);
CREATE INDEX IF NOT EXISTS idx_parcelles_disponible ON public.parcelles(surface_disponible_ha) WHERE statut != 'saturee';
CREATE INDEX IF NOT EXISTS idx_plantations_parcelle ON public.plantations(parcelle_id);
CREATE INDEX IF NOT EXISTS idx_souscripteurs_type ON public.souscripteurs(type_souscripteur);
CREATE INDEX IF NOT EXISTS idx_souscripteurs_parcelle ON public.souscripteurs(parcelle_id);
CREATE INDEX IF NOT EXISTS idx_proprietaires_statut ON public.proprietaires_terres(statut);
