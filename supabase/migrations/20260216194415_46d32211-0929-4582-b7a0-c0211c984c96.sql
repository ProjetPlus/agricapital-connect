
-- =============================================
-- MIGRATION GÉOGRAPHIQUE CÔTE D'IVOIRE
-- Ajouter aux données existantes sans supprimer
-- =============================================

-- 1. Table villages
CREATE TABLE IF NOT EXISTS public.villages (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  nom TEXT NOT NULL,
  sous_prefecture_id UUID REFERENCES public.sous_prefectures(id),
  est_actif BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.villages ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='villages' AND policyname='Anyone can read villages') THEN
    CREATE POLICY "Anyone can read villages" ON public.villages FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='villages' AND policyname='Admins manage villages') THEN
    CREATE POLICY "Admins manage villages" ON public.villages FOR ALL USING (is_admin(auth.uid()));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_villages_sous_prefecture ON public.villages(sous_prefecture_id);
CREATE INDEX IF NOT EXISTS idx_villages_nom ON public.villages(nom);

-- 2. Fonctions de cascade
CREATE OR REPLACE FUNCTION public.cascade_district_activation()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.est_actif = false AND OLD.est_actif = true THEN
    UPDATE public.regions SET est_active = false WHERE district_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.cascade_region_activation()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.est_active = false AND OLD.est_active = true THEN
    UPDATE public.departements SET est_actif = false WHERE region_id = NEW.id;
  END IF;
  IF NEW.est_active = true AND OLD.est_active = false THEN
    IF EXISTS (SELECT 1 FROM public.districts WHERE id = NEW.district_id AND est_actif = false) THEN
      RAISE EXCEPTION 'Impossible d''activer cette région : le district parent est désactivé';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.cascade_departement_activation()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.est_actif = false AND OLD.est_actif = true THEN
    UPDATE public.sous_prefectures SET est_active = false WHERE departement_id = NEW.id;
  END IF;
  IF NEW.est_actif = true AND OLD.est_actif = false THEN
    IF EXISTS (SELECT 1 FROM public.regions WHERE id = NEW.region_id AND est_active = false) THEN
      RAISE EXCEPTION 'Impossible d''activer ce département : la région parente est désactivée';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.cascade_sous_prefecture_activation()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.est_active = false AND OLD.est_active = true THEN
    UPDATE public.villages SET est_actif = false WHERE sous_prefecture_id = NEW.id;
  END IF;
  IF NEW.est_active = true AND OLD.est_active = false THEN
    IF EXISTS (SELECT 1 FROM public.departements WHERE id = NEW.departement_id AND est_actif = false) THEN
      RAISE EXCEPTION 'Impossible d''activer cette sous-préfecture : le département parent est désactivé';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Triggers de cascade
DROP TRIGGER IF EXISTS trigger_cascade_district ON public.districts;
CREATE TRIGGER trigger_cascade_district
  BEFORE UPDATE OF est_actif ON public.districts
  FOR EACH ROW EXECUTE FUNCTION public.cascade_district_activation();

DROP TRIGGER IF EXISTS trigger_cascade_region ON public.regions;
CREATE TRIGGER trigger_cascade_region
  BEFORE UPDATE OF est_active ON public.regions
  FOR EACH ROW EXECUTE FUNCTION public.cascade_region_activation();

DROP TRIGGER IF EXISTS trigger_cascade_departement ON public.departements;
CREATE TRIGGER trigger_cascade_departement
  BEFORE UPDATE OF est_actif ON public.departements
  FOR EACH ROW EXECUTE FUNCTION public.cascade_departement_activation();

DROP TRIGGER IF EXISTS trigger_cascade_sous_prefecture ON public.sous_prefectures;
CREATE TRIGGER trigger_cascade_sous_prefecture
  BEFORE UPDATE OF est_active ON public.sous_prefectures
  FOR EACH ROW EXECUTE FUNCTION public.cascade_sous_prefecture_activation();

-- 3. Mettre à jour les noms des districts existants pour cohérence
UPDATE public.districts SET code = 'DAA' WHERE nom LIKE '%Abidjan%';
UPDATE public.districts SET code = 'DAY' WHERE nom LIKE '%Yamoussoukro%';
UPDATE public.districts SET code = 'MON' WHERE nom LIKE '%Montagnes%';
UPDATE public.districts SET code = 'SMH' WHERE nom LIKE '%Sassandra-Marahoué%';
UPDATE public.districts SET code = 'BSS' WHERE nom LIKE '%Bas-Sassandra%';
UPDATE public.districts SET code = 'COM' WHERE nom LIKE '%Comoé%';
UPDATE public.districts SET code = 'GDJ' WHERE nom LIKE '%Gôh-Djiboua%';
UPDATE public.districts SET code = 'LAC' WHERE nom LIKE '%Lacs%';
UPDATE public.districts SET code = 'LAG' WHERE nom LIKE '%Lagunes%';
UPDATE public.districts SET code = 'VDB' WHERE nom LIKE '%Bandama%' AND nom NOT LIKE '%Vallée%';
UPDATE public.districts SET code = 'DEN' WHERE nom LIKE '%Denguélé%';
UPDATE public.districts SET code = 'WOR' WHERE nom LIKE '%Woroba%';
UPDATE public.districts SET code = 'VBD' WHERE nom LIKE '%Vallée%';
UPDATE public.districts SET code = 'ZAN' WHERE nom LIKE '%Zanzan%';

-- Désactiver les districts non déployés
UPDATE public.districts SET est_actif = false WHERE nom LIKE '%Denguélé%';
UPDATE public.districts SET est_actif = false WHERE nom LIKE '%Lacs%';
UPDATE public.districts SET est_actif = false WHERE nom LIKE '%Vallée%';
UPDATE public.districts SET est_actif = false WHERE nom LIKE '%Woroba%';
UPDATE public.districts SET est_actif = false WHERE nom LIKE '%Zanzan%';
UPDATE public.districts SET est_actif = false WHERE nom LIKE '%Bandama%' AND nom NOT LIKE '%Vallée%';
UPDATE public.districts SET est_actif = false WHERE nom LIKE '%Savanes%' OR nom LIKE '%SAV%';

-- 4. Ajouter les régions manquantes (en utilisant les IDs des districts existants)
-- Abidjan
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Abidjan', 'ABJ', id, true FROM public.districts WHERE nom LIKE '%Abidjan%'
ON CONFLICT DO NOTHING;

-- Yamoussoukro  
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Yamoussoukro', 'YAM', id, true FROM public.districts WHERE nom LIKE '%Yamoussoukro%'
ON CONFLICT DO NOTHING;

-- Bas-Sassandra regions
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Gbôklé', 'GBK', id, true FROM public.districts WHERE nom LIKE '%Bas-Sassandra%'
ON CONFLICT DO NOTHING;
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Nawa', 'NAW', id, true FROM public.districts WHERE nom LIKE '%Bas-Sassandra%'
ON CONFLICT DO NOTHING;
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'San-Pédro', 'SPE', id, true FROM public.districts WHERE nom LIKE '%Bas-Sassandra%'
ON CONFLICT DO NOTHING;

-- Comoé
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Indénié-Djuablin', 'IDJ', id, true FROM public.districts WHERE nom LIKE '%Comoé%'
ON CONFLICT DO NOTHING;
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Sud-Comoé', 'SCO', id, true FROM public.districts WHERE nom LIKE '%Comoé%'
ON CONFLICT DO NOTHING;

-- Denguélé (désactivé)
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Folon', 'FOL', id, false FROM public.districts WHERE nom LIKE '%Denguélé%'
ON CONFLICT DO NOTHING;
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Kabadougou', 'KBD', id, false FROM public.districts WHERE nom LIKE '%Denguélé%'
ON CONFLICT DO NOTHING;

-- Gôh-Djiboua
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Gôh', 'GOH', id, true FROM public.districts WHERE nom LIKE '%Gôh-Djiboua%'
ON CONFLICT DO NOTHING;
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Lôh-Djiboua', 'LDJ', id, true FROM public.districts WHERE nom LIKE '%Gôh-Djiboua%'
ON CONFLICT DO NOTHING;

-- Lacs (désactivé)
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Bélier', 'BEL', id, false FROM public.districts WHERE nom LIKE '%Lacs%'
ON CONFLICT DO NOTHING;
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Iffou', 'IFF', id, false FROM public.districts WHERE nom LIKE '%Lacs%'
ON CONFLICT DO NOTHING;
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Moronou', 'MOR', id, false FROM public.districts WHERE nom LIKE '%Lacs%'
ON CONFLICT DO NOTHING;
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'N''Zi', 'NZI', id, false FROM public.districts WHERE nom LIKE '%Lacs%'
ON CONFLICT DO NOTHING;

-- Lagunes
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Agnéby-Tiassa', 'AGT', id, true FROM public.districts WHERE nom LIKE '%Lagunes%'
ON CONFLICT DO NOTHING;
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Grands-Ponts', 'GPO', id, true FROM public.districts WHERE nom LIKE '%Lagunes%'
ON CONFLICT DO NOTHING;
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Mé', 'ME', id, true FROM public.districts WHERE nom LIKE '%Lagunes%'
ON CONFLICT DO NOTHING;

-- Montagnes
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Cavally', 'CAV', id, true FROM public.districts WHERE nom LIKE '%Montagnes%'
ON CONFLICT DO NOTHING;
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Guémon', 'GUE', id, true FROM public.districts WHERE nom LIKE '%Montagnes%'
ON CONFLICT DO NOTHING;
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Tonkpi', 'TON', id, true FROM public.districts WHERE nom LIKE '%Montagnes%'
ON CONFLICT DO NOTHING;

-- Sassandra-Marahoué (Haut-Sassandra existe déjà)
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Marahoué', 'MAR', id, true FROM public.districts WHERE nom LIKE '%Sassandra-Marahoué%'
ON CONFLICT DO NOTHING;

-- Savanes (désactivé) 
-- Pas de district Savanes dans les données, on skip

-- Vallée du Bandama (désactivé)
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Gbêkê', 'GBE', id, false FROM public.districts WHERE nom LIKE '%Vallée%'
ON CONFLICT DO NOTHING;
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Hambol', 'HAM', id, false FROM public.districts WHERE nom LIKE '%Vallée%'
ON CONFLICT DO NOTHING;

-- Woroba (désactivé)
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Béré', 'BER', id, false FROM public.districts WHERE nom LIKE '%Woroba%'
ON CONFLICT DO NOTHING;
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Worodougou', 'WOD', id, false FROM public.districts WHERE nom LIKE '%Woroba%'
ON CONFLICT DO NOTHING;

-- Zanzan (désactivé)
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Bounkani', 'BOU', id, false FROM public.districts WHERE nom LIKE '%Zanzan%'
ON CONFLICT DO NOTHING;
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Gontougo', 'GON', id, false FROM public.districts WHERE nom LIKE '%Zanzan%'
ON CONFLICT DO NOTHING;

-- Bandama (désactivé)
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Hambol', 'HAM2', id, false FROM public.districts WHERE nom LIKE '%Bandama%' AND nom NOT LIKE '%Vallée%'
ON CONFLICT DO NOTHING;

-- 5. Ajouter les départements principaux
-- Haut-Sassandra (utiliser la région existante)
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Daloa', 'DAL', id, true FROM public.regions WHERE nom = 'Haut-Sassandra'
ON CONFLICT DO NOTHING;
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Issia', 'ISS', id, true FROM public.regions WHERE nom = 'Haut-Sassandra'
ON CONFLICT DO NOTHING;
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Vavoua', 'VAV', id, true FROM public.regions WHERE nom = 'Haut-Sassandra'
ON CONFLICT DO NOTHING;

-- Marahoué
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Bouaflé', 'BOF', id, true FROM public.regions WHERE nom = 'Marahoué'
ON CONFLICT DO NOTHING;
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Sinfra', 'SIN', id, true FROM public.regions WHERE nom = 'Marahoué'
ON CONFLICT DO NOTHING;
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Zuénoula', 'ZUE', id, true FROM public.regions WHERE nom = 'Marahoué'
ON CONFLICT DO NOTHING;

-- Nawa
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Soubré', 'SOU', id, true FROM public.regions WHERE nom = 'Nawa'
ON CONFLICT DO NOTHING;
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Buyo', 'BUY', id, true FROM public.regions WHERE nom = 'Nawa'
ON CONFLICT DO NOTHING;
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Guéyo', 'GUY', id, true FROM public.regions WHERE nom = 'Nawa'
ON CONFLICT DO NOTHING;

-- Gbôklé
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Sassandra', 'SAS', id, true FROM public.regions WHERE nom = 'Gbôklé'
ON CONFLICT DO NOTHING;
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Fresco', 'FRE', id, true FROM public.regions WHERE nom = 'Gbôklé'
ON CONFLICT DO NOTHING;
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Méagui', 'MEA', id, true FROM public.regions WHERE nom = 'Gbôklé'
ON CONFLICT DO NOTHING;

-- San-Pédro
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'San-Pédro', 'SPE', id, true FROM public.regions WHERE nom = 'San-Pédro'
ON CONFLICT DO NOTHING;
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Tabou', 'TAB', id, true FROM public.regions WHERE nom = 'San-Pédro'
ON CONFLICT DO NOTHING;

-- Gôh
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Gagnoa', 'GAG', id, true FROM public.regions WHERE nom = 'Gôh'
ON CONFLICT DO NOTHING;
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Oumé', 'OUM', id, true FROM public.regions WHERE nom = 'Gôh'
ON CONFLICT DO NOTHING;

-- Lôh-Djiboua
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Divo', 'DIV', id, true FROM public.regions WHERE nom = 'Lôh-Djiboua'
ON CONFLICT DO NOTHING;
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Lakota', 'LAK', id, true FROM public.regions WHERE nom = 'Lôh-Djiboua'
ON CONFLICT DO NOTHING;

-- Indénié-Djuablin
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Abengourou', 'ABE', id, true FROM public.regions WHERE nom = 'Indénié-Djuablin'
ON CONFLICT DO NOTHING;
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Agnibilékrou', 'AGN', id, true FROM public.regions WHERE nom = 'Indénié-Djuablin'
ON CONFLICT DO NOTHING;

-- Sud-Comoé
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Aboisso', 'ABO', id, true FROM public.regions WHERE nom = 'Sud-Comoé'
ON CONFLICT DO NOTHING;
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Grand-Bassam', 'GBA', id, true FROM public.regions WHERE nom = 'Sud-Comoé'
ON CONFLICT DO NOTHING;

-- Abidjan
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Abidjan', 'ABJ', id, true FROM public.regions WHERE nom = 'Abidjan'
ON CONFLICT DO NOTHING;
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Anyama', 'ANY', id, true FROM public.regions WHERE nom = 'Abidjan'
ON CONFLICT DO NOTHING;
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Bingerville', 'BIN', id, true FROM public.regions WHERE nom = 'Abidjan'
ON CONFLICT DO NOTHING;

-- Yamoussoukro
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Yamoussoukro', 'YAM', id, true FROM public.regions WHERE nom = 'Yamoussoukro'
ON CONFLICT DO NOTHING;

-- Lagunes regions
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Agboville', 'AGB', id, true FROM public.regions WHERE nom = 'Agnéby-Tiassa'
ON CONFLICT DO NOTHING;
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Tiassalé', 'TIS', id, true FROM public.regions WHERE nom = 'Agnéby-Tiassa'
ON CONFLICT DO NOTHING;
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Dabou', 'DAB', id, true FROM public.regions WHERE nom = 'Grands-Ponts'
ON CONFLICT DO NOTHING;
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Adzopé', 'ADZ', id, true FROM public.regions WHERE nom = 'Mé'
ON CONFLICT DO NOTHING;

-- Montagnes
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Guiglo', 'GIG', id, true FROM public.regions WHERE nom = 'Cavally'
ON CONFLICT DO NOTHING;
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Duékoué', 'DUE', id, true FROM public.regions WHERE nom = 'Guémon'
ON CONFLICT DO NOTHING;
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Man', 'MAN', id, true FROM public.regions WHERE nom = 'Tonkpi'
ON CONFLICT DO NOTHING;
INSERT INTO public.departements (nom, code, region_id, est_actif)
SELECT 'Danané', 'DAN', id, true FROM public.regions WHERE nom = 'Tonkpi'
ON CONFLICT DO NOTHING;

-- 6. Sous-préfectures de Daloa
INSERT INTO public.sous_prefectures (nom, code, departement_id, est_active)
SELECT 'Daloa', 'DAL', id, true FROM public.departements WHERE nom = 'Daloa' AND code = 'DAL'
ON CONFLICT DO NOTHING;
INSERT INTO public.sous_prefectures (nom, code, departement_id, est_active)
SELECT 'Gonaté', 'GON', id, true FROM public.departements WHERE nom = 'Daloa' AND code = 'DAL'
ON CONFLICT DO NOTHING;
INSERT INTO public.sous_prefectures (nom, code, departement_id, est_active)
SELECT 'Bédiala', 'BED', id, true FROM public.departements WHERE nom = 'Daloa' AND code = 'DAL'
ON CONFLICT DO NOTHING;
INSERT INTO public.sous_prefectures (nom, code, departement_id, est_active)
SELECT 'Domangbeu', 'DOM', id, true FROM public.departements WHERE nom = 'Daloa' AND code = 'DAL'
ON CONFLICT DO NOTHING;
INSERT INTO public.sous_prefectures (nom, code, departement_id, est_active)
SELECT 'Gboguhé', 'GBO', id, true FROM public.departements WHERE nom = 'Daloa' AND code = 'DAL'
ON CONFLICT DO NOTHING;
INSERT INTO public.sous_prefectures (nom, code, departement_id, est_active)
SELECT 'Zaibo', 'ZAI', id, true FROM public.departements WHERE nom = 'Daloa' AND code = 'DAL'
ON CONFLICT DO NOTHING;

-- Sous-préfectures d'Issia
INSERT INTO public.sous_prefectures (nom, code, departement_id, est_active)
SELECT 'Issia', 'ISS', id, true FROM public.departements WHERE nom = 'Issia'
ON CONFLICT DO NOTHING;
INSERT INTO public.sous_prefectures (nom, code, departement_id, est_active)
SELECT 'Saïoua', 'SAI', id, true FROM public.departements WHERE nom = 'Issia'
ON CONFLICT DO NOTHING;

-- Sous-préfectures de Soubré
INSERT INTO public.sous_prefectures (nom, code, departement_id, est_active)
SELECT 'Soubré', 'SOU', id, true FROM public.departements WHERE nom = 'Soubré'
ON CONFLICT DO NOTHING;
INSERT INTO public.sous_prefectures (nom, code, departement_id, est_active)
SELECT 'Grand-Zattry', 'GZA', id, true FROM public.departements WHERE nom = 'Soubré'
ON CONFLICT DO NOTHING;

-- Sous-préfectures de Gagnoa
INSERT INTO public.sous_prefectures (nom, code, departement_id, est_active)
SELECT 'Gagnoa', 'GAG', id, true FROM public.departements WHERE nom = 'Gagnoa'
ON CONFLICT DO NOTHING;
INSERT INTO public.sous_prefectures (nom, code, departement_id, est_active)
SELECT 'Ouragahio', 'OUR', id, true FROM public.departements WHERE nom = 'Gagnoa'
ON CONFLICT DO NOTHING;

-- 7. Villages pour la zone de Daloa
INSERT INTO public.villages (nom, sous_prefecture_id)
SELECT 'Gnamanou', id FROM public.sous_prefectures WHERE nom = 'Daloa' AND code = 'DAL'
ON CONFLICT DO NOTHING;
INSERT INTO public.villages (nom, sous_prefecture_id)
SELECT 'Tazibouo', id FROM public.sous_prefectures WHERE nom = 'Daloa' AND code = 'DAL'
ON CONFLICT DO NOTHING;
INSERT INTO public.villages (nom, sous_prefecture_id)
SELECT 'Gbeuliville', id FROM public.sous_prefectures WHERE nom = 'Daloa' AND code = 'DAL'
ON CONFLICT DO NOTHING;
INSERT INTO public.villages (nom, sous_prefecture_id)
SELECT 'Bribouo', id FROM public.sous_prefectures WHERE nom = 'Daloa' AND code = 'DAL'
ON CONFLICT DO NOTHING;
INSERT INTO public.villages (nom, sous_prefecture_id)
SELECT 'Sapia', id FROM public.sous_prefectures WHERE nom = 'Gonaté'
ON CONFLICT DO NOTHING;
INSERT INTO public.villages (nom, sous_prefecture_id)
SELECT 'Bédiala', id FROM public.sous_prefectures WHERE nom = 'Bédiala'
ON CONFLICT DO NOTHING;
INSERT INTO public.villages (nom, sous_prefecture_id)
SELECT 'Gadouan', id FROM public.sous_prefectures WHERE nom = 'Bédiala'
ON CONFLICT DO NOTHING;

-- 8. Realtime sur villages
ALTER PUBLICATION supabase_realtime ADD TABLE public.villages;
