
-- Insert villages for all sous-prefectures that don't have any
-- Abidjan communes (urban - quartiers as villages)
INSERT INTO public.villages (nom, sous_prefecture_id) VALUES
-- Adjamé
('Williamsville', '1d865f0c-b7f4-46a9-88b6-547a9d0ac2b4'),
('220 Logements', '1d865f0c-b7f4-46a9-88b6-547a9d0ac2b4'),
('Liberté', '1d865f0c-b7f4-46a9-88b6-547a9d0ac2b4'),
-- Attécoubé
('Locodjro', '2577a87b-e6a6-417d-b669-50fd57d7c40a'),
('Agban-Village', '2577a87b-e6a6-417d-b669-50fd57d7c40a'),
-- Cocody
('Riviera', 'e44a5d10-966e-437f-9b80-90beb67a20a2'),
('Angré', 'e44a5d10-966e-437f-9b80-90beb67a20a2'),
('Danga', 'e44a5d10-966e-437f-9b80-90beb67a20a2'),
-- Koumassi
('Koumassi-Nord', 'd0d668d6-3ae0-48f8-8f51-fa110dadfb92'),
('Koumassi-Remblais', 'd0d668d6-3ae0-48f8-8f51-fa110dadfb92'),
-- Marcory
('Zone 4', '2af086a7-7515-4c9f-80e1-14cf3ad65fbc'),
('Anoumabo', '2af086a7-7515-4c9f-80e1-14cf3ad65fbc'),
-- Plateau
('Plateau-Centre', '807e7ad7-ff89-4c4d-87d0-63e7c75dc963'),
-- Port-Bouët
('Vridi', '63484ca8-8a73-49bf-8277-756232f506a5'),
('Gonzagueville', '63484ca8-8a73-49bf-8277-756232f506a5'),
-- Treichville
('Treichville-Centre', '48c3f90c-d8a8-4a28-8adf-c6b6fc0c6048'),
('Avenue 10', '48c3f90c-d8a8-4a28-8adf-c6b6fc0c6048'),
-- Yopougon
('Niangon', '6e9e27c7-c345-435a-8102-25dbe6c80878'),
('Wassakara', '6e9e27c7-c345-435a-8102-25dbe6c80878'),
('Banco', '6e9e27c7-c345-435a-8102-25dbe6c80878'),

-- Assini (Adiaké)
('Assini-Mafia', 'e7c79c96-b4ff-4952-a254-c69bd69a5e2f'),
('Assini-N''Djem', 'e7c79c96-b4ff-4952-a254-c69bd69a5e2f'),

-- Assikoi (Adzopé)
('Assikoi-Village', 'c43e7fab-c99f-4061-8e96-08a9db3eb517'),
('Aboudé-Kouassikro', 'c43e7fab-c99f-4061-8e96-08a9db3eb517'),
-- Bécédi-Brignan
('Bécédi-Brignan', '3c82e44c-013d-4027-ae7c-be39e39a13ba'),
('Loviguié', '3c82e44c-013d-4027-ae7c-be39e39a13ba'),

-- Grand-Morié (Agboville)
('Grand-Morié', '31b3ef40-c8c7-455b-80da-fe94b7e08ee5'),
('Oress-Krobou', '31b3ef40-c8c7-455b-80da-fe94b7e08ee5'),
-- Rubino
('Rubino', '02c0652d-7aff-482e-9f2c-79746503e0d3'),
('Gomon', '02c0652d-7aff-482e-9f2c-79746503e0d3'),

-- Damé (Agnibilékrou)
('Damé', '5388e821-0cb0-4aa1-bfc0-becd4b9034a6'),
('Kangandissou', '5388e821-0cb0-4aa1-bfc0-becd4b9034a6'),

-- Bécouéfin (Akoupé)
('Bécouéfin', 'e0a78d54-7ac0-4b1c-8df2-4b5446350784'),
('Aboisso-Comoé', 'e0a78d54-7ac0-4b1c-8df2-4b5446350784'),

-- Abobo-Baoulé (Anyama)
('Abobo-Baoulé', 'bd2f8d3a-9c1d-4200-8d93-2cb9bb0a39c6'),
('N''Dotré', 'bd2f8d3a-9c1d-4200-8d93-2cb9bb0a39c6'),

-- Arrah
('Arrah-Centre', 'ece65707-fe90-4031-b340-f6648ba29134'),
('Kondéyaokro', 'ece65707-fe90-4031-b340-f6648ba29134'),
-- Kouadioblékro
('Kouadioblékro', '890e9069-4621-4157-b4db-a82a5f8b4781'),
('Abongoua', '890e9069-4621-4157-b4db-a82a5f8b4781'),

-- Adjin (Bingerville)
('Adjin', 'ac0a2c1a-b6e2-410d-8586-fad33ced4f50'),
('Akouai-Santai', 'ac0a2c1a-b6e2-410d-8586-fad33ced4f50'),

-- Diabo (Botro)
('Diabo', 'b52bbf00-6b80-4315-b4e6-f6f5afd5b288'),
('Langbassou', 'b52bbf00-6b80-4315-b4e6-f6f5afd5b288'),

-- Satama-Sokoro (Dabakala)
('Satama-Sokoro', 'bc95f471-5b84-4a96-a9c8-98535e082de2'),
('Foumbolo', 'bc95f471-5b84-4a96-a9c8-98535e082de2'),
-- Satama-Sokoura
('Satama-Sokoura', 'b20f5ec0-1f54-416c-808d-344db22bd0c7'),
('Kationon', 'b20f5ec0-1f54-416c-808d-344db22bd0c7'),

-- Lopou (Dabou)
('Lopou', 'e9bb4e45-1505-4355-aeb5-7d1692cdc93e'),
('Aklodj', 'e9bb4e45-1505-4355-aeb5-7d1692cdc93e'),
-- Toupah
('Toupah', 'bd69d937-08d3-4230-8412-04495aeeb519'),
('Irobo', 'bd69d937-08d3-4230-8412-04495aeeb519'),

-- Domangbeu (Daloa)
('Domangbeu', 'd0ca50ea-e0be-4b26-b2f1-87ccd5d7da9b'),
('Bédiala', 'd0ca50ea-e0be-4b26-b2f1-87ccd5d7da9b'),
-- Gboguhé
('Gboguhé', '6eddcfc5-7483-4c83-8b72-ad1fe34d6bfe'),
('Gonaté', '6eddcfc5-7483-4c83-8b72-ad1fe34d6bfe'),
-- Zaibo
('Zaibo', 'c8f11101-5afb-4c0e-a71a-da0132598d7c'),
('Tagoura', 'c8f11101-5afb-4c0e-a71a-da0132598d7c'),

-- Sarhala (Dianra)
('Sarhala', 'babcf837-b214-435d-8360-9bf966629744'),
('Boniéré', 'babcf837-b214-435d-8360-9bf966629744'),

-- Tié-Diékro (Djékanou)
('Tié-Diékro', '54402d4a-bd05-4dfd-a20b-6b81edb8d25f'),
('Attokro', '54402d4a-bd05-4dfd-a20b-6b81edb8d25f'),

-- Kalamon (Doropo)
('Kalamon', '7e1b4d1f-f2e2-4faf-8685-68c939ab3d95'),
('Bouna-Secteur', '7e1b4d1f-f2e2-4faf-8685-68c939ab3d95'),

-- Duékoué (Duékoué)
('Duékoué-Ville', '52ffedef-160f-4491-84e0-65377ec42954'),
('Bagouo', '52ffedef-160f-4491-84e0-65377ec42954'),
-- Guézon
('Guézon', '9cdd99e2-a8c8-4a2a-a7b2-3112ca603c90'),
('Ponan', '9cdd99e2-a8c8-4a2a-a7b2-3112ca603c90'),
-- Kouibly
('Kouibly', 'fa6e80df-8a3b-419e-887a-59bcf30d26d7'),
('Biankouma-Secteur', 'fa6e80df-8a3b-419e-887a-59bcf30d26d7'),

-- Tiéni (Facobly)
('Tiéni', 'b12a3c43-a812-4a77-8fe7-b8f9ccc30a72'),
('Bléniméouin', 'b12a3c43-a812-4a77-8fe7-b8f9ccc30a72'),

-- Dassioko (Fresco)
('Dassioko', '866407c7-87df-47d3-ad93-5e6c68ffe3d0'),
('Gbagbam', '866407c7-87df-47d3-ad93-5e6c68ffe3d0'),

-- Ouragahio (Gagnoa)
('Ouragahio', '8409b1d0-a92b-41b8-ae14-d85f982b0141'),
('Bayota', '8409b1d0-a92b-41b8-ae14-d85f982b0141'),

-- Férentéla (Gbéléban)
('Férentéla', '7a8f074d-ae8e-4860-ba54-696fd03cd3ee'),
('Bandougou', '7a8f074d-ae8e-4860-ba54-696fd03cd3ee'),
-- Gbéléban
('Gbéléban-Village', '63d66636-95cd-45c2-8981-19bb38da1609'),
('Sananférédougou', '63d66636-95cd-45c2-8981-19bb38da1609'),

-- Assinie-Mafia (Grand-Bassam)
('Assinie-Mafia-Village', 'ecd656ef-7d3d-4706-8952-b23443cb5d9b'),
('Mondoukou', 'ecd656ef-7d3d-4706-8952-b23443cb5d9b'),

-- Dabouyo (Guéyo)
('Dabouyo', '53e92be3-a0a3-4265-8634-34862c253a13'),
('Grégbeu', '53e92be3-a0a3-4265-8634-34862c253a13'),
-- Guéyo
('Guéyo-Village', '4b963afe-df1a-4dbd-8f54-a7625210d963'),
('Gnago', '4b963afe-df1a-4dbd-8f54-a7625210d963'),

-- Duékoué (Guiglo)
('Nizahon', '0387b762-064b-4dc1-82a3-d18d26f7a859'),
('Kaadé', '0387b762-064b-4dc1-82a3-d18d26f7a859'),

-- Saïoua (Issia)
('Saïoua', 'c4c7292f-7449-4b74-9144-6d0586fd774e'),
('Iboguhé', 'c4c7292f-7449-4b74-9144-6d0586fd774e'),

-- Kani
('Kani-Village', '37cbea7e-3480-4ee7-aed0-f4bf8e88be31'),
('Dasso', '37cbea7e-3480-4ee7-aed0-f4bf8e88be31'),
-- Morondo
('Morondo', '45d868d5-5afe-42f0-8b26-c9b8eac71fdb'),
('Sifié', '45d868d5-5afe-42f0-8b26-c9b8eac71fdb'),

-- Goulia (Kaniasso)
('Goulia', '3a79f43a-8f36-42af-8ff3-e1f50684ce65'),
('Tiémé', '3a79f43a-8f36-42af-8ff3-e1f50684ce65'),
-- Kaniasso
('Kaniasso-Village', 'e421edb4-353f-4e90-ab65-e5785a04733b'),
('Kahanso', 'e421edb4-353f-4e90-ab65-e5785a04733b'),

-- Fronan (Katiola)
('Fronan', '2b24b014-b338-4563-b506-c8c04a0e75af'),
('Torla', '2b24b014-b338-4563-b506-c8c04a0e75af'),
-- Katiola
('Katiola-Village', 'b018af5f-e2b7-437e-a20b-52deba8f5267'),
('Niakaramandougou', 'b018af5f-e2b7-437e-a20b-52deba8f5267'),
-- Timbé
('Timbé', '3a28bd8e-0455-4f56-8616-009c66b21912'),
('Niéméné', '3a28bd8e-0455-4f56-8616-009c66b21912'),

-- Kong
('Kong-Village', '25d8c98c-6b23-47b8-aabb-bd5c77dd86c2'),
('Koumbolokoro', '25d8c98c-6b23-47b8-aabb-bd5c77dd86c2'),
-- Nafana
('Nafana', '97bd3464-2231-4bcb-ae59-f939887e7ee7'),
('Gbédié', '97bd3464-2231-4bcb-ae59-f939887e7ee7'),

-- Booko (Koro)
('Booko', '6f0dfd9f-a151-4e5d-bd11-e1cf33fff8b9'),
('Dianra-Village', '6f0dfd9f-a151-4e5d-bd11-e1cf33fff8b9'),
-- Koro
('Koro-Village', '319921d9-472b-48cd-959b-ca150a70624a'),
('Djonkro', '319921d9-472b-48cd-959b-ca150a70624a'),

-- Koun-Fao
('Koun-Fao', '15b2727c-29ef-447b-9334-83d4013fbbb3'),
('Abié', '15b2727c-29ef-447b-9334-83d4013fbbb3'),
-- Tankessé
('Tankessé', 'b56c3cbc-0b80-4e9b-806b-41b90039a2ec'),
('Assuamé', 'b56c3cbc-0b80-4e9b-806b-41b90039a2ec'),

-- Kongasso (Kounahiri)
('Kongasso', 'f170e3d5-994c-4fd4-8711-b1044ad6a49c'),
('Tiéla', 'f170e3d5-994c-4fd4-8711-b1044ad6a49c'),
-- Kounahiri
('Kounahiri-Village', 'a04b9f74-3487-434a-9190-2dcc5e2f5ef1'),
('Boli', 'a04b9f74-3487-434a-9190-2dcc5e2f5ef1'),

-- Siempurgo (Kouto)
('Siempurgo', '18848d38-2692-40c8-8636-04a71634e091'),
('Katégué', '18848d38-2692-40c8-8636-04a71634e091'),

-- M''Batto
('M''Batto-Village', '31d6b3ce-6358-4ddc-a651-76d8c4a889cf'),
('Assié-Koumassi', '31d6b3ce-6358-4ddc-a651-76d8c4a889cf'),
-- Tiémélékro
('Tiémélékro', 'b9d9bb58-cd06-4aaa-8f8d-4397f7aacecf'),
('Kotobi', 'b9d9bb58-cd06-4aaa-8f8d-4397f7aacecf'),

-- M''Bengué
('M''Bengué-Village', '362b1e54-3d6f-4492-ae0c-bea1e5747d05'),
('Ouazomon', '362b1e54-3d6f-4492-ae0c-bea1e5747d05'),
-- Tioroniaradougou
('Tioroniaradougou', 'c678c3cf-9e11-4580-af77-670e864097fa'),
('Tiorotiérissé', 'c678c3cf-9e11-4580-af77-670e864097fa'),

-- Madinani
('Madinani-Village', '31a174a6-3b7e-49a8-8f10-d1d25237b8b1'),
('Dembasso', '31a174a6-3b7e-49a8-8f10-d1d25237b8b1');
