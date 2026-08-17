
-- Insert sous-prefectures and villages for departments that have none
-- Using DO block for cleaner insertion with references

DO $$
DECLARE
  sp_id UUID;
BEGIN

-- 1. Ouaninou (Bafing)
sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Ouaninou', '19229aa1-4757-4f6f-a6a2-ca1d53933bc8');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Ouaninou', sp_id), ('Gbangbégouiné', sp_id), ('Sipilou', sp_id);

sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Gbangbégouiné', '19229aa1-4757-4f6f-a6a2-ca1d53933bc8');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Kouan-Houlé', sp_id), ('Sémien', sp_id);

-- 2. Didiévi (Bélier)
sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Didiévi', '117a15e7-3761-4cbd-9599-b63b5e64ceef');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Didiévi', sp_id), ('Langbassou', sp_id), ('N''Gattakro', sp_id);

sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Tié-N''Diékro', '117a15e7-3761-4cbd-9599-b63b5e64ceef');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Tié-N''Diékro', sp_id), ('Raviart', sp_id);

-- 3. Tiébissou (Bélier)
sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Tiébissou', '5a53eff8-d91e-4a04-b4d8-59a26ae1d560');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Tiébissou', sp_id), ('Molonoublé', sp_id), ('Kouakro', sp_id);

sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Molonoublé', '5a53eff8-d91e-4a04-b4d8-59a26ae1d560');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Sakiakro', sp_id), ('Djèbonouan', sp_id);

-- 4. Téhini (Bounkani)
sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Téhini', 'ee67b4ef-bd3e-42a8-b9b7-18fdcaed383f');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Téhini', sp_id), ('Kounzié', sp_id), ('Kalamon', sp_id);

sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Tougbo', 'ee67b4ef-bd3e-42a8-b9b7-18fdcaed383f');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Tougbo', sp_id), ('Yalo', sp_id);

-- 5. Béoumi (Gbêkê)
sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Béoumi', '5f174892-e31a-44f0-b86b-857d1ac10289');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Béoumi', sp_id), ('Kondrobo', sp_id), ('Bodokro', sp_id);

sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Bodokro', '5f174892-e31a-44f0-b86b-857d1ac10289');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Lolobo', sp_id), ('Konankro', sp_id);

sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Kondrobo', '5f174892-e31a-44f0-b86b-857d1ac10289');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Marabadiassa', sp_id), ('Sakassou', sp_id);

-- 6. Sassandra (Gbôklé)
sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Sassandra', '50d21e71-2504-4f73-8685-5071c588d747');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Sassandra', sp_id), ('Dakpadou', sp_id), ('Sago', sp_id);

sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Sago', '50d21e71-2504-4f73-8685-5071c588d747');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Grabo', sp_id), ('Dakpadou', sp_id);

-- 7. Sandégué (Gontougo)
sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Sandégué', '01630a89-9f8f-4aa8-b72f-263efe1e3f1f');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Sandégué', sp_id), ('Assuéfry', sp_id), ('Kouassi-Datékro', sp_id);

sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Kouassi-Datékro', '01630a89-9f8f-4aa8-b72f-263efe1e3f1f');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Pinda-Boroko', sp_id), ('Tankessé', sp_id);

-- 8. Jacqueville (Grands-Ponts)
sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Jacqueville', '9307ee60-2dd3-4453-b0ed-e71db21aba81');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Jacqueville', sp_id), ('Addah', sp_id), ('Avagou', sp_id);

sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Attoutou', '9307ee60-2dd3-4453-b0ed-e71db21aba81');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Attoutou', sp_id), ('Adiadon', sp_id);

-- 9. Kouibly (Guémon)
sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Kouibly', 'e9bcdfc0-2ae5-49af-97c3-d129af972707');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Kouibly', sp_id), ('Ouyably-Gnondrou', sp_id), ('Bangolo', sp_id);

sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Ouyably-Gnondrou', 'e9bcdfc0-2ae5-49af-97c3-d129af972707');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Gbapleu', sp_id), ('Tiéolé-Oula', sp_id);

-- 10. M'Bahiakro (Iffou)
sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'M''Bahiakro', '09180ae2-5236-4cf8-88d7-1cc3259f6ca8');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('M''Bahiakro', sp_id), ('Prikro', sp_id), ('Ouellé', sp_id);

sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Prikro', '09180ae2-5236-4cf8-88d7-1cc3259f6ca8');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Prikro', sp_id), ('Brou Ahoussoukro', sp_id);

-- 11. Abengourou (Indénié-Djuablin)
sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Abengourou', 'ac8c04f5-c38e-46cf-9aa6-237e06bb23d2');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Abengourou', sp_id), ('Aniassué', sp_id), ('Amélékia', sp_id);

sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Aniassué', 'ac8c04f5-c38e-46cf-9aa6-237e06bb23d2');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Aniassué', sp_id), ('Yakassé-Féyassé', sp_id);

sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Niablé', 'ac8c04f5-c38e-46cf-9aa6-237e06bb23d2');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Niablé', sp_id), ('Ébilassékro', sp_id);

-- 12. Bettié (Indénié-Djuablin)
sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Bettié', '96a77d32-c813-4027-9563-570838a53ee6');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Bettié', sp_id), ('Aboisso-Comoé', sp_id), ('Zaranou', sp_id);

-- 13. Séguélon (Kabadougou)
sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Séguélon', 'aa28dcbd-7b70-4120-8bd7-be2fb2e35c85');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Séguélon', sp_id), ('Kani', sp_id), ('Tienko', sp_id);

sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Kani', 'aa28dcbd-7b70-4120-8bd7-be2fb2e35c85');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Kaniasso', sp_id), ('Goulia', sp_id);

-- 14. Bouaflé (Marahoué)
sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Bouaflé', '6fb9611b-5833-4df0-bb70-b75926af4015');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Bouaflé', sp_id), ('Bonon', sp_id), ('Pakouabo', sp_id);

sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Bonon', '6fb9611b-5833-4df0-bb70-b75926af4015');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Bonon', sp_id), ('Béziaka', sp_id);

sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Pakouabo', '6fb9611b-5833-4df0-bb70-b75926af4015');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Pakouabo', sp_id), ('Bognonzra', sp_id);

-- 15. Bocanda (N'Zi)
sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Bocanda', '4da367f3-5afe-47a8-8e74-f4630b4b1dca');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Bocanda', sp_id), ('Kouadioblékro', sp_id), ('Ananda', sp_id);

sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Kouadioblékro', '4da367f3-5afe-47a8-8e74-f4630b4b1dca');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('N''Guessankro', sp_id), ('Boli', sp_id);

-- 16. Kouassi-Kouassikro (N'Zi)
sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Kouassi-Kouassikro', 'e5f741c4-07f0-4beb-ae9a-d8d7a4f91d6c');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Kouassi-Kouassikro', sp_id), ('Kpouèbo', sp_id);

-- 17. Buyo (Nawa)
sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Buyo', '36a3f69e-517b-46f9-a063-958d0bbff65e');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Buyo', sp_id), ('Guéyo', sp_id), ('Gbagbam', sp_id);

sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Guéyo', '36a3f69e-517b-46f9-a063-958d0bbff65e');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Guéyo', sp_id), ('Dahiri', sp_id);

-- 18. Dikodougou (Poro)
sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Dikodougou', '0b2f0e61-d7e6-4d7f-b814-9d48c0041e08');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Dikodougou', sp_id), ('Guiembé', sp_id), ('Kounzié', sp_id);

-- 19. Sinématiali (Poro)
sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Sinématiali', '8369cf16-7259-4781-9b25-9d6c62a5bc04');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Sinématiali', sp_id), ('Tioroniaradougou', sp_id), ('Kounzié', sp_id);

-- 20. Tabou (San-Pédro)
sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Tabou', 'c3bbc480-25ec-4d5b-ab63-ed029be695da');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Tabou', sp_id), ('Grabo', sp_id), ('Olodio', sp_id);

sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Grabo', 'c3bbc480-25ec-4d5b-ab63-ed029be695da');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Grabo', sp_id), ('Djéro', sp_id);

-- 21. Aboisso (Sud-Comoé)
sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Aboisso', '7426da83-31bb-4e6f-b924-856eaadf9227');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Aboisso', sp_id), ('Ayamé', sp_id), ('Maféré', sp_id);

sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Ayamé', '7426da83-31bb-4e6f-b924-856eaadf9227');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Ayamé', sp_id), ('Bianouan', sp_id);

sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Maféré', '7426da83-31bb-4e6f-b924-856eaadf9227');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Maféré', sp_id), ('Krindjabo', sp_id);

-- 22. Ouangolodougou (Tchologo)
sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Ouangolodougou', '73517c08-3cf1-41e4-93cb-ed15724bcde0');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Ouangolodougou', sp_id), ('Papara', sp_id), ('Niellé', sp_id);

sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Papara', '73517c08-3cf1-41e4-93cb-ed15724bcde0');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Papara', sp_id), ('Ngorotingué', sp_id);

-- 23. Biankouma (Tonkpi)
sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Biankouma', '93164567-d230-431b-8abc-12d80aa15cef');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Biankouma', sp_id), ('Gbonné', sp_id), ('Santa', sp_id);

sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Santa', '93164567-d230-431b-8abc-12d80aa15cef');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Santa', sp_id), ('Gouiné', sp_id);

sp_id := gen_random_uuid();
INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Gbonné', '93164567-d230-431b-8abc-12d80aa15cef');
INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Gbonné', sp_id), ('Sipilou', sp_id);

END $$;
