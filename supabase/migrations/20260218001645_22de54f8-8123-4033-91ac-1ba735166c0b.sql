
-- Add missing departements for Hambol region
INSERT INTO public.departements (nom, region_id, code) 
SELECT d.nom, r.id, d.code 
FROM (VALUES 
  ('Katiola', 'KAT'),
  ('Dabakala', 'DAB'),
  ('Niakara', 'NIA')
) AS d(nom, code)
CROSS JOIN (SELECT id FROM public.regions WHERE nom = 'Hambol') r
ON CONFLICT DO NOTHING;

-- Add sous-prefectures for all departments that don't have any
-- Using a massive insert with department name matching

-- Abidjan district departments
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES 
  ('Abobo'), ('Adjamé'), ('Attécoubé'), ('Cocody'), ('Koumassi'), ('Marcory'), ('Plateau'), ('Port-Bouët'), ('Treichville'), ('Yopougon')
) AS sp(nom) CROSS JOIN departements d WHERE d.nom = 'Abidjan' ON CONFLICT DO NOTHING;

INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Anyama'), ('Abobo-Baoulé')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Anyama' ON CONFLICT DO NOTHING;

INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Bingerville'), ('Adjin')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Bingerville' ON CONFLICT DO NOTHING;

-- Agnéby-Tiassa
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Agboville'), ('Azaguié'), ('Rubino'), ('Grand-Morié')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Agboville' ON CONFLICT DO NOTHING;

INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Tiassalé'), ('N''Douci'), ('Morokro')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Tiassalé' AND d.region_id = (SELECT id FROM regions WHERE nom = 'Agnéby-Tiassa') ON CONFLICT DO NOTHING;

-- Grands-Ponts  
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Dabou'), ('Lopou'), ('Toupah')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Dabou' ON CONFLICT DO NOTHING;

-- Mé
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Adzopé'), ('Bécédi-Brignan'), ('Assikoi')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Adzopé' ON CONFLICT DO NOTHING;

INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Akoupé'), ('Bécouéfin')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Akoupé' ON CONFLICT DO NOTHING;

INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Yakassé-Attobrou'), ('Biéby')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Yakassé-Attobrou' ON CONFLICT DO NOTHING;

-- Bélier
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Djékanou'), ('Tié-Diékro')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Djékanou' ON CONFLICT DO NOTHING;

-- Iffou
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Prikro'), ('Groyaridougou')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Prikro' ON CONFLICT DO NOTHING;

-- Moronou
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Arrah'), ('Kouadioblékro')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Arrah' ON CONFLICT DO NOTHING;

INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('M''Batto'), ('Tiémélékro')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'M''Batto' ON CONFLICT DO NOTHING;

-- Gbêkê
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Botro'), ('Diabo')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Botro' ON CONFLICT DO NOTHING;

INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Sakassou'), ('Ayaou-Sran')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Sakassou' ON CONFLICT DO NOTHING;

-- Hambol (new departments)
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Katiola'), ('Fronan'), ('Timbé')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Katiola' AND d.region_id = (SELECT id FROM regions WHERE nom = 'Hambol') ON CONFLICT DO NOTHING;

INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Dabakala'), ('Satama-Sokoura'), ('Satama-Sokoro')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Dabakala' AND d.region_id = (SELECT id FROM regions WHERE nom = 'Hambol') ON CONFLICT DO NOTHING;

INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Niakara'), ('Tafiré'), ('Niakaramandougou')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Niakara' AND d.region_id = (SELECT id FROM regions WHERE nom = 'Hambol') ON CONFLICT DO NOTHING;

-- Indénié-Djuablin
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Agnibilékrou'), ('Damé')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Agnibilékrou' ON CONFLICT DO NOTHING;

-- Sud-Comoé
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Grand-Bassam'), ('Bonoua'), ('Assinie-Mafia')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Grand-Bassam' ON CONFLICT DO NOTHING;

INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Adiaké'), ('Assini')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Adiaké' ON CONFLICT DO NOTHING;

INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Tiapoum'), ('Étuéboué')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Tiapoum' ON CONFLICT DO NOTHING;

-- Haut-Sassandra
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Vavoua'), ('Bazra-Nattis'), ('Kétro-Bassam')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Vavoua' ON CONFLICT DO NOTHING;

INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Zoukougbeu'), ('Guezon')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Zoukougbeu' ON CONFLICT DO NOTHING;

-- Marahoué
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Sinfra'), ('Konéfla')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Sinfra' ON CONFLICT DO NOTHING;

INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Zuénoula'), ('Gohitafla')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Zuénoula' ON CONFLICT DO NOTHING;

-- Gôh
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Oumé'), ('Diégonéfla'), ('Tonla')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Oumé' ON CONFLICT DO NOTHING;

-- Lôh-Djiboua (already has some, but add chef-lieu SPs)

-- Cavally
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Guiglo'), ('Duékoué')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Guiglo' ON CONFLICT DO NOTHING;

INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Taï'), ('Zagné')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Taï' ON CONFLICT DO NOTHING;

INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Toulépleu'), ('Péhé'), ('Bakoubly')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Toulépleu' ON CONFLICT DO NOTHING;

-- Guémon
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Duékoué'), ('Guézon'), ('Kouibly')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Duékoué' AND d.region_id = (SELECT id FROM regions WHERE nom = 'Guémon') ON CONFLICT DO NOTHING;

INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Facobly'), ('Tiéni')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Facobly' ON CONFLICT DO NOTHING;

-- Tonkpi
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Zouan-Hounien'), ('Bin-Houyé')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Zouan-Hounien' ON CONFLICT DO NOTHING;

-- Bas-Sassandra
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('San-Pédro'), ('Grand-Béréby'), ('Tabou')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'San-Pédro' AND d.region_id = (SELECT id FROM regions WHERE nom = 'San-Pédro') ON CONFLICT DO NOTHING;

INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Fresco'), ('Dassioko')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Fresco' ON CONFLICT DO NOTHING;

-- Nawa
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Méagui'), ('Oupoyo')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Méagui' ON CONFLICT DO NOTHING;

INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Guéyo'), ('Dabouyo')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Guéyo' ON CONFLICT DO NOTHING;

-- Gbôklé
-- (Fresco already handled above)

-- Gontougo
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Koun-Fao'), ('Tankessé')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Koun-Fao' ON CONFLICT DO NOTHING;

INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Transua'), ('Assuéfry')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Transua' ON CONFLICT DO NOTHING;

-- Bounkani
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Doropo'), ('Kalamon')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Doropo' ON CONFLICT DO NOTHING;

INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Nassian'), ('Sominassé')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Nassian' ON CONFLICT DO NOTHING;

-- Denguélé - Folon
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Kaniasso'), ('Goulia')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Kaniasso' ON CONFLICT DO NOTHING;

-- Kabadougou
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Madinani'), ('Tienko')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Madinani' ON CONFLICT DO NOTHING;

INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Gbéléban'), ('Férentéla')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Gbéléban' ON CONFLICT DO NOTHING;

INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Samatiguila'), ('Kimbirila-Nord')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Samatiguila' ON CONFLICT DO NOTHING;

-- Worodougou
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Kani'), ('Morondo')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Kani' ON CONFLICT DO NOTHING;

-- Béré
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Kounahiri'), ('Kongasso')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Kounahiri' ON CONFLICT DO NOTHING;

INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Dianra'), ('Sarhala')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Dianra' ON CONFLICT DO NOTHING;

-- Bafing
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Koro'), ('Booko')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Koro' AND d.region_id = (SELECT id FROM regions WHERE nom = 'Bafing') ON CONFLICT DO NOTHING;

-- Bagoué
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Kouto'), ('Siempurgo')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Kouto' ON CONFLICT DO NOTHING;

-- Poro
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('M''Bengué'), ('Tioroniaradougou')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'M''Bengué' ON CONFLICT DO NOTHING;

-- Tchologo
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Kong'), ('Nafana')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Kong' ON CONFLICT DO NOTHING;

-- Yamoussoukro
INSERT INTO public.sous_prefectures (nom, departement_id) 
SELECT sp.nom, d.id FROM (VALUES ('Yamoussoukro'), ('Attiégouakro'), ('Kossou')) AS sp(nom) 
CROSS JOIN departements d WHERE d.nom = 'Yamoussoukro' AND d.region_id = (SELECT id FROM regions WHERE nom = 'Yamoussoukro') ON CONFLICT DO NOTHING;
