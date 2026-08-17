
-- Add type_offre column to offres
ALTER TABLE public.offres ADD COLUMN IF NOT EXISTS type_offre text DEFAULT 'sans_terre';

-- Delete old offers
DELETE FROM public.offres;

-- Insert the 4 new offers based on flyer
INSERT INTO public.offres (code, nom, description, type_offre, montant_da_par_ha, contribution_mensuelle_par_ha, couleur, ordre, actif, avantages) VALUES
('PALMINVEST', 'PalmInvest', 'Offre d''investissement sans terre - Droits d''adhésion et contributions mensuelles. AgriCapital fournit la terre.', 'sans_terre', 45000, 3400, '#2E7D32', 1, true, '["Terre fournie par AgriCapital", "Suivi technique complet", "Rendement garanti"]'::jsonb),
('PALMINVEST_PLUS', 'PalmInvest+', 'Offre premium sans terre - Services étendus et rendements optimisés.', 'sans_terre', 60000, 4500, '#1B5E20', 2, true, '["Terre fournie par AgriCapital", "Suivi technique premium", "Rendement optimisé", "Assurance plantation"]'::jsonb),
('TERRAPALM', 'TerraPalm', 'Offre pour souscripteurs disposant déjà d''une terre.', 'avec_terre', 30000, 1900, '#E65100', 3, true, '["Utilisation de votre propre terre", "Suivi technique complet", "Rendement garanti"]'::jsonb),
('TERRAPALM_PLUS', 'TerraPalm+', 'Offre premium pour souscripteurs avec terre - Services étendus.', 'avec_terre', 40000, 2500, '#BF360C', 4, true, '["Utilisation de votre propre terre", "Suivi technique premium", "Rendement optimisé", "Assurance plantation"]'::jsonb);

-- Add localite column to souscripteurs if not exists
ALTER TABLE public.souscripteurs ADD COLUMN IF NOT EXISTS localite text;
