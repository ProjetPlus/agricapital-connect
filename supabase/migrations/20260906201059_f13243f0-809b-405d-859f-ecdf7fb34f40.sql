ALTER TABLE public.cartes_personnel
  ADD COLUMN IF NOT EXISTS mission text,
  ADD COLUMN IF NOT EXISTS zone_intervention text,
  ADD COLUMN IF NOT EXISTS statut_agent text NOT NULL DEFAULT 'employe';