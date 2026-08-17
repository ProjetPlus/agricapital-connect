
DO $$
DECLARE sp_id UUID;
BEGIN
  sp_id := gen_random_uuid();
  INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Niakaramandougou', '5f2e4090-d15b-40a2-be53-c0c9e2637371');
  INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Niakaramandougou', sp_id), ('Tafiré', sp_id), ('Niakara', sp_id);

  sp_id := gen_random_uuid();
  INSERT INTO sous_prefectures (id, nom, departement_id) VALUES (sp_id, 'Tafiré', '5f2e4090-d15b-40a2-be53-c0c9e2637371');
  INSERT INTO villages (nom, sous_prefecture_id) VALUES ('Tafiré', sp_id), ('Karakoro', sp_id);
END $$;
