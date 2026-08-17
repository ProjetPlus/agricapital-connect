-- Fix demo client role: change from super_admin to souscripteur
UPDATE user_roles SET role = 'souscripteur' WHERE user_id = 'bd9579fd-1d07-4431-9cc4-b57dfeeab593';

-- Create souscripteur record for demo client
INSERT INTO souscripteurs (
  user_id, nom_complet, nom_famille, prenoms, telephone, email,
  district_id, region_id, domicile, domicile_residence, statut, statut_global,
  id_unique, civilite
) VALUES (
  'bd9579fd-1d07-4431-9cc4-b57dfeeab593',
  'KOFFI Inocent',
  'KOFFI',
  'Inocent',
  '0759566087',
  'innocentkoffi1@gmail.com',
  'c552c470-bd75-4985-93f6-7c101251ebc3',
  'd7738144-14cf-43f6-be4d-500f21a9cee5',
  'Daloa, Gnamanou',
  'Daloa',
  'actif',
  'actif',
  (SELECT generate_souscripteur_id()),
  'M.'
);

-- Update profile
UPDATE profiles SET actif = true WHERE user_id = 'bd9579fd-1d07-4431-9cc4-b57dfeeab593';
UPDATE profiles SET username = 'admin' WHERE user_id = '8d616fdc-6f25-43e9-baaa-51ead746222e';
