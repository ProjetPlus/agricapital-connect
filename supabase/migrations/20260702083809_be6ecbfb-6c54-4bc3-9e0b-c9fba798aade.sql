-- Ajoute les colonnes manquantes à profiles pour aligner avec les formulaires
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS whatsapp text,
  ADD COLUMN IF NOT EXISTS departement text,
  ADD COLUMN IF NOT EXISTS poste text,
  ADD COLUMN IF NOT EXISTS relation_rh text DEFAULT 'Employé',
  ADD COLUMN IF NOT EXISTS taux_commission numeric,
  ADD COLUMN IF NOT EXISTS district_id uuid,
  ADD COLUMN IF NOT EXISTS region_id uuid,
  ADD COLUMN IF NOT EXISTS role text;

-- Assure les grants
GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;

-- Force le rafraîchissement du cache PostgREST
NOTIFY pgrst, 'reload schema';