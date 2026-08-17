
-- 1. Ajouter le District des Savanes (manquant)
INSERT INTO public.districts (nom, code, est_actif) 
SELECT 'District des Savanes', 'SAV', true
WHERE NOT EXISTS (SELECT 1 FROM public.districts WHERE nom = 'District des Savanes');

-- 2. Ajouter les régions manquantes
-- Bafing (sous Woroba)
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Bafing', 'BAF', id, true FROM public.districts WHERE nom = 'District du Woroba'
AND NOT EXISTS (SELECT 1 FROM public.regions WHERE nom = 'Bafing');

-- Bagoué (sous Savanes)
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Bagoué', 'BAG', id, true FROM public.districts WHERE nom = 'District des Savanes'
AND NOT EXISTS (SELECT 1 FROM public.regions WHERE nom = 'Bagoué');

-- Poro (sous Savanes)
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Poro', 'POR', id, true FROM public.districts WHERE nom = 'District des Savanes'
AND NOT EXISTS (SELECT 1 FROM public.regions WHERE nom = 'Poro');

-- Tchologo (sous Savanes)
INSERT INTO public.regions (nom, code, district_id, est_active)
SELECT 'Tchologo', 'TCH', id, true FROM public.districts WHERE nom = 'District des Savanes'
AND NOT EXISTS (SELECT 1 FROM public.regions WHERE nom = 'Tchologo');

-- 3. Ajouter tous les départements manquants par région

-- Bafing: Koro, Ouaninou, Touba
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Touba', id, true FROM public.regions WHERE nom = 'Bafing' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Touba');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Koro', id, true FROM public.regions WHERE nom = 'Bafing' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Koro');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Ouaninou', id, true FROM public.regions WHERE nom = 'Bafing' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Ouaninou');

-- Bagoué: Boundiali, Kouto, Tengrela
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Boundiali', id, true FROM public.regions WHERE nom = 'Bagoué' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Boundiali');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Kouto', id, true FROM public.regions WHERE nom = 'Bagoué' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Kouto');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Tengrela', id, true FROM public.regions WHERE nom = 'Bagoué' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Tengrela');

-- Bélier: Didiévi, Djékanou, Tiébissou, Toumodi
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Didiévi', id, true FROM public.regions WHERE nom = 'Bélier' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Didiévi');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Djékanou', id, true FROM public.regions WHERE nom = 'Bélier' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Djékanou');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Tiébissou', id, true FROM public.regions WHERE nom = 'Bélier' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Tiébissou');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Toumodi', id, true FROM public.regions WHERE nom = 'Bélier' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Toumodi');

-- Béré: Dianra, Kounahiri, Mankono
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Dianra', id, true FROM public.regions WHERE nom = 'Béré' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Dianra');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Kounahiri', id, true FROM public.regions WHERE nom = 'Béré' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Kounahiri');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Mankono', id, true FROM public.regions WHERE nom = 'Béré' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Mankono');

-- Bounkani: Bouna, Doropo, Nassian, Téhini
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Bouna', id, true FROM public.regions WHERE nom = 'Bounkani' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Bouna');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Doropo', id, true FROM public.regions WHERE nom = 'Bounkani' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Doropo');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Nassian', id, true FROM public.regions WHERE nom = 'Bounkani' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Nassian');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Téhini', id, true FROM public.regions WHERE nom = 'Bounkani' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Téhini');

-- Cavally: Bloléquin, Taï, Toulépleu (Guiglo existe déjà)
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Bloléquin', id, true FROM public.regions WHERE nom = 'Cavally' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Bloléquin');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Taï', id, true FROM public.regions WHERE nom = 'Cavally' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Taï');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Toulépleu', id, true FROM public.regions WHERE nom = 'Cavally' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Toulépleu');

-- Folon: Kaniasso, Minignan
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Kaniasso', id, true FROM public.regions WHERE nom = 'Folon' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Kaniasso');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Minignan', id, true FROM public.regions WHERE nom = 'Folon' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Minignan');

-- Gbêkê: Béoumi, Botro, Bouaké, Sakassou
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Béoumi', id, true FROM public.regions WHERE nom = 'Gbêkê' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Béoumi');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Botro', id, true FROM public.regions WHERE nom = 'Gbêkê' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Botro');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Bouaké', id, true FROM public.regions WHERE nom = 'Gbêkê' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Bouaké');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Sakassou', id, true FROM public.regions WHERE nom = 'Gbêkê' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Sakassou');

-- Gontougo: Bondoukou, Koun-Fao, Sandégué, Tanda, Transua
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Bondoukou', id, true FROM public.regions WHERE nom = 'Gontougo' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Bondoukou');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Koun-Fao', id, true FROM public.regions WHERE nom = 'Gontougo' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Koun-Fao');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Sandégué', id, true FROM public.regions WHERE nom = 'Gontougo' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Sandégué');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Tanda', id, true FROM public.regions WHERE nom = 'Gontougo' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Tanda');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Transua', id, true FROM public.regions WHERE nom = 'Gontougo' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Transua');

-- Guémon: Bangolo, Kouibly, Facobly (Duékoué existe déjà)
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Bangolo', id, true FROM public.regions WHERE nom = 'Guémon' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Bangolo');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Kouibly', id, true FROM public.regions WHERE nom = 'Guémon' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Kouibly');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Facobly', id, true FROM public.regions WHERE nom = 'Guémon' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Facobly');

-- Hambol: Dabakala, Katiola, Niakaramandougou
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Dabakala', id, true FROM public.regions WHERE nom = 'Hambol' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Dabakala') LIMIT 1;
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Katiola', id, true FROM public.regions WHERE nom = 'Hambol' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Katiola') LIMIT 1;
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Niakaramandougou', id, true FROM public.regions WHERE nom = 'Hambol' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Niakaramandougou') LIMIT 1;

-- Haut-Sassandra: Zoukougbeu (Daloa, Issia, Vavoua existent)
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Zoukougbeu', id, true FROM public.regions WHERE nom = 'Haut-Sassandra' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Zoukougbeu');

-- Iffou: Daoukro, M'Bahiakro, Prikro
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Daoukro', id, true FROM public.regions WHERE nom = 'Iffou' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Daoukro');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT E'M\'Bahiakro', id, true FROM public.regions WHERE nom = 'Iffou' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = E'M\'Bahiakro');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Prikro', id, true FROM public.regions WHERE nom = 'Iffou' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Prikro');

-- Indénié-Djuablin: Bettié (Abengourou, Agnibilékrou existent)
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Bettié', id, true FROM public.regions WHERE nom = 'Indénié-Djuablin' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Bettié');

-- Kabadougou: Gbéléban, Madinani, Odienné, Samatiguila, Séguélon
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Gbéléban', id, true FROM public.regions WHERE nom = 'Kabadougou' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Gbéléban');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Madinani', id, true FROM public.regions WHERE nom = 'Kabadougou' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Madinani');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Odienné', id, true FROM public.regions WHERE nom = 'Kabadougou' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Odienné');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Samatiguila', id, true FROM public.regions WHERE nom = 'Kabadougou' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Samatiguila');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Séguélon', id, true FROM public.regions WHERE nom = 'Kabadougou' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Séguélon');

-- Lôh-Djiboua: Guitry (Divo, Lakota existent)
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Guitry', id, true FROM public.regions WHERE nom = 'Lôh-Djiboua' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Guitry');

-- Moronou: Arrah, Bongouanou, M'Batto
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Arrah', id, true FROM public.regions WHERE nom = 'Moronou' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Arrah');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Bongouanou', id, true FROM public.regions WHERE nom = 'Moronou' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Bongouanou');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT E'M\'Batto', id, true FROM public.regions WHERE nom = 'Moronou' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = E'M\'Batto');

-- Nawa: Méagui (Buyo, Soubré existent) - Méagui est sous Nawa pas Gbôklé
-- On corrige aussi Méagui: le déplacer de Gbôklé vers Nawa si mal placé
UPDATE public.departements SET region_id = (SELECT id FROM public.regions WHERE nom = 'Nawa' LIMIT 1) WHERE nom = 'Méagui' AND region_id = (SELECT id FROM public.regions WHERE nom = 'Gbôklé' LIMIT 1);

-- N'Zi: Bocanda, Dimbokro, Kouassi-Kouassikro
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Bocanda', id, true FROM public.regions WHERE nom = E'N\'Zi' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Bocanda');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Dimbokro', id, true FROM public.regions WHERE nom = E'N\'Zi' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Dimbokro');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Kouassi-Kouassikro', id, true FROM public.regions WHERE nom = E'N\'Zi' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Kouassi-Kouassikro');

-- Poro: Dikodougou, Korhogo, M'Bengué, Sinématiali
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Dikodougou', id, true FROM public.regions WHERE nom = 'Poro' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Dikodougou');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Korhogo', id, true FROM public.regions WHERE nom = 'Poro' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Korhogo');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT E'M\'Bengué', id, true FROM public.regions WHERE nom = 'Poro' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = E'M\'Bengué');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Sinématiali', id, true FROM public.regions WHERE nom = 'Poro' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Sinématiali');

-- Sud-Comoé: Adiaké, Tiapoum (Aboisso, Grand-Bassam existent)
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Adiaké', id, true FROM public.regions WHERE nom = 'Sud-Comoé' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Adiaké');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Tiapoum', id, true FROM public.regions WHERE nom = 'Sud-Comoé' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Tiapoum');

-- Tchologo: Ferkessédougou, Kong, Ouangolodougou
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Ferkessédougou', id, true FROM public.regions WHERE nom = 'Tchologo' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Ferkessédougou');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Kong', id, true FROM public.regions WHERE nom = 'Tchologo' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Kong');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Ouangolodougou', id, true FROM public.regions WHERE nom = 'Tchologo' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Ouangolodougou');

-- Tonkpi: Biankouma, Zouan-Hounien (Danané, Man existent)
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Biankouma', id, true FROM public.regions WHERE nom = 'Tonkpi' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Biankouma');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Zouan-Hounien', id, true FROM public.regions WHERE nom = 'Tonkpi' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Zouan-Hounien');

-- Worodougou: Kani, Séguéla
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Kani', id, true FROM public.regions WHERE nom = 'Worodougou' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Kani');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Séguéla', id, true FROM public.regions WHERE nom = 'Worodougou' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Séguéla');

-- Grands-Ponts: Jacqueville (Dabou existe)
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Jacqueville', id, true FROM public.regions WHERE nom = 'Grands-Ponts' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Jacqueville');

-- Mé: Akoupé, Yakassé-Attobrou (Adzopé existe)
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Akoupé', id, true FROM public.regions WHERE nom = 'Mé' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Akoupé');
INSERT INTO public.departements (nom, region_id, est_actif) SELECT 'Yakassé-Attobrou', id, true FROM public.regions WHERE nom = 'Mé' AND NOT EXISTS (SELECT 1 FROM public.departements WHERE nom = 'Yakassé-Attobrou');

-- 4. Ajouter des sous-préfectures principales (chef-lieux de département)
-- Pour chaque département ajouté, on crée au minimum la sous-préfecture du chef-lieu

-- Sous-préfectures pour les régions les plus importantes
INSERT INTO public.sous_prefectures (nom, departement_id, est_active) SELECT 'Bouaké', id, true FROM public.departements WHERE nom = 'Bouaké' AND NOT EXISTS (SELECT 1 FROM public.sous_prefectures WHERE nom = 'Bouaké');
INSERT INTO public.sous_prefectures (nom, departement_id, est_active) SELECT 'Korhogo', id, true FROM public.departements WHERE nom = 'Korhogo' AND NOT EXISTS (SELECT 1 FROM public.sous_prefectures WHERE nom = 'Korhogo');
INSERT INTO public.sous_prefectures (nom, departement_id, est_active) SELECT 'Ferkessédougou', id, true FROM public.departements WHERE nom = 'Ferkessédougou' AND NOT EXISTS (SELECT 1 FROM public.sous_prefectures WHERE nom = 'Ferkessédougou');
INSERT INTO public.sous_prefectures (nom, departement_id, est_active) SELECT 'Bondoukou', id, true FROM public.departements WHERE nom = 'Bondoukou' AND NOT EXISTS (SELECT 1 FROM public.sous_prefectures WHERE nom = 'Bondoukou');
INSERT INTO public.sous_prefectures (nom, departement_id, est_active) SELECT 'Odienné', id, true FROM public.departements WHERE nom = 'Odienné' AND NOT EXISTS (SELECT 1 FROM public.sous_prefectures WHERE nom = 'Odienné');
INSERT INTO public.sous_prefectures (nom, departement_id, est_active) SELECT 'Boundiali', id, true FROM public.departements WHERE nom = 'Boundiali' AND NOT EXISTS (SELECT 1 FROM public.sous_prefectures WHERE nom = 'Boundiali');
INSERT INTO public.sous_prefectures (nom, departement_id, est_active) SELECT 'Mankono', id, true FROM public.departements WHERE nom = 'Mankono' AND NOT EXISTS (SELECT 1 FROM public.sous_prefectures WHERE nom = 'Mankono');
INSERT INTO public.sous_prefectures (nom, departement_id, est_active) SELECT 'Séguéla', id, true FROM public.departements WHERE nom = 'Séguéla' AND NOT EXISTS (SELECT 1 FROM public.sous_prefectures WHERE nom = 'Séguéla');
INSERT INTO public.sous_prefectures (nom, departement_id, est_active) SELECT 'Touba', id, true FROM public.departements WHERE nom = 'Touba' AND NOT EXISTS (SELECT 1 FROM public.sous_prefectures WHERE nom = 'Touba');
INSERT INTO public.sous_prefectures (nom, departement_id, est_active) SELECT 'Daoukro', id, true FROM public.departements WHERE nom = 'Daoukro' AND NOT EXISTS (SELECT 1 FROM public.sous_prefectures WHERE nom = 'Daoukro');
INSERT INTO public.sous_prefectures (nom, departement_id, est_active) SELECT 'Dimbokro', id, true FROM public.departements WHERE nom = 'Dimbokro' AND NOT EXISTS (SELECT 1 FROM public.sous_prefectures WHERE nom = 'Dimbokro');
INSERT INTO public.sous_prefectures (nom, departement_id, est_active) SELECT 'Bongouanou', id, true FROM public.departements WHERE nom = 'Bongouanou' AND NOT EXISTS (SELECT 1 FROM public.sous_prefectures WHERE nom = 'Bongouanou');
INSERT INTO public.sous_prefectures (nom, departement_id, est_active) SELECT 'Toumodi', id, true FROM public.departements WHERE nom = 'Toumodi' AND NOT EXISTS (SELECT 1 FROM public.sous_prefectures WHERE nom = 'Toumodi');
INSERT INTO public.sous_prefectures (nom, departement_id, est_active) SELECT 'Katiola', id, true FROM public.departements WHERE nom = 'Katiola' AND NOT EXISTS (SELECT 1 FROM public.sous_prefectures WHERE nom = 'Katiola');
INSERT INTO public.sous_prefectures (nom, departement_id, est_active) SELECT 'Man', id, true FROM public.departements WHERE nom = 'Man' AND NOT EXISTS (SELECT 1 FROM public.sous_prefectures WHERE nom = 'Man');
INSERT INTO public.sous_prefectures (nom, departement_id, est_active) SELECT 'Danané', id, true FROM public.departements WHERE nom = 'Danané' AND NOT EXISTS (SELECT 1 FROM public.sous_prefectures WHERE nom = 'Danané');
INSERT INTO public.sous_prefectures (nom, departement_id, est_active) SELECT 'Bouna', id, true FROM public.departements WHERE nom = 'Bouna' AND NOT EXISTS (SELECT 1 FROM public.sous_prefectures WHERE nom = 'Bouna');
INSERT INTO public.sous_prefectures (nom, departement_id, est_active) SELECT 'Tengrela', id, true FROM public.departements WHERE nom = 'Tengrela' AND NOT EXISTS (SELECT 1 FROM public.sous_prefectures WHERE nom = 'Tengrela');
INSERT INTO public.sous_prefectures (nom, departement_id, est_active) SELECT 'Minignan', id, true FROM public.departements WHERE nom = 'Minignan' AND NOT EXISTS (SELECT 1 FROM public.sous_prefectures WHERE nom = 'Minignan');
INSERT INTO public.sous_prefectures (nom, departement_id, est_active) SELECT 'Tanda', id, true FROM public.departements WHERE nom = 'Tanda' AND NOT EXISTS (SELECT 1 FROM public.sous_prefectures WHERE nom = 'Tanda');
INSERT INTO public.sous_prefectures (nom, departement_id, est_active) SELECT 'Bangolo', id, true FROM public.departements WHERE nom = 'Bangolo' AND NOT EXISTS (SELECT 1 FROM public.sous_prefectures WHERE nom = 'Bangolo');
INSERT INTO public.sous_prefectures (nom, departement_id, est_active) SELECT 'Bloléquin', id, true FROM public.departements WHERE nom = 'Bloléquin' AND NOT EXISTS (SELECT 1 FROM public.sous_prefectures WHERE nom = 'Bloléquin');
INSERT INTO public.sous_prefectures (nom, departement_id, est_active) SELECT 'Divo', id, true FROM public.departements WHERE nom = 'Divo' AND NOT EXISTS (SELECT 1 FROM public.sous_prefectures WHERE nom = 'Divo');
INSERT INTO public.sous_prefectures (nom, departement_id, est_active) SELECT 'Lakota', id, true FROM public.departements WHERE nom = 'Lakota' AND NOT EXISTS (SELECT 1 FROM public.sous_prefectures WHERE nom = 'Lakota');
INSERT INTO public.sous_prefectures (nom, departement_id, est_active) SELECT 'Guitry', id, true FROM public.departements WHERE nom = 'Guitry' AND NOT EXISTS (SELECT 1 FROM public.sous_prefectures WHERE nom = 'Guitry');

-- Supprimer le doublon Hambol du "District du Bandama" s'il existe
-- (Hambol est dans le District de la Vallée du Bandama, pas un district séparé)
DELETE FROM public.regions WHERE nom = 'Hambol' AND district_id = (SELECT id FROM public.districts WHERE nom = 'District du Bandama' LIMIT 1) AND id != (SELECT id FROM public.regions WHERE nom = 'Hambol' AND district_id = (SELECT id FROM public.districts WHERE nom = 'District de la Vallée du Bandama' LIMIT 1) LIMIT 1);

-- Supprimer le District du Bandama (doublon) s'il n'a plus de régions
DELETE FROM public.districts WHERE nom = 'District du Bandama' AND NOT EXISTS (SELECT 1 FROM public.regions WHERE district_id = districts.id);
