
-- 1. Add type_equipe to equipes table
ALTER TABLE public.equipes ADD COLUMN IF NOT EXISTS type_equipe text DEFAULT 'commercial' CHECK (type_equipe IN ('commercial', 'technique'));
ALTER TABLE public.equipes ADD COLUMN IF NOT EXISTS superviseur_id uuid REFERENCES public.profiles(id);

-- 2. Create grille_remuneration table
CREATE TABLE IF NOT EXISTS public.grille_remuneration (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role_cible text NOT NULL CHECK (role_cible IN ('commercial', 'technicien')),
  type_remuneration text NOT NULL CHECK (type_remuneration IN ('souscription', 'recouvrement_mensuel', 'cash', 'salaire_fixe', 'prime_ha', 'bonus_qualite')),
  montant numeric DEFAULT 0,
  taux_pourcentage numeric DEFAULT 0,
  annee_application integer DEFAULT 1,
  description text,
  actif boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.grille_remuneration ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins manage grille" ON public.grille_remuneration FOR ALL TO authenticated USING (is_admin(auth.uid()));
CREATE POLICY "Staff read grille" ON public.grille_remuneration FOR SELECT TO authenticated USING (is_staff(auth.uid()));

-- 3. Update user_roles: rename responsable_zone -> superviseur_tc
UPDATE public.user_roles SET role = 'superviseur_tc' WHERE role = 'responsable_zone';

-- 4. Update is_staff to include technicien
CREATE OR REPLACE FUNCTION public.is_staff(_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles 
    WHERE user_id = _user_id 
    AND role NOT IN ('souscripteur', 'user')
  )
$$;

-- 5. Update notify_hierarchy for new role
CREATE OR REPLACE FUNCTION public.notify_hierarchy(p_type text, p_title text, p_message text, p_data jsonb DEFAULT NULL::jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE v_user RECORD;
BEGIN
  FOR v_user IN SELECT DISTINCT ur.user_id FROM public.user_roles ur 
    WHERE ur.role IN ('super_admin', 'directeur_tc', 'superviseur_tc', 'chef_equipe')
  LOOP
    INSERT INTO public.notifications (user_id, type, title, message, data) 
    VALUES (v_user.user_id, p_type, p_title, p_message, p_data);
  END LOOP;
END;
$$;

-- 6. Insert grille_remuneration data
-- Commerciaux
INSERT INTO public.grille_remuneration (role_cible, type_remuneration, montant, description) VALUES
  ('commercial', 'souscription', 15000, '15 000 F/ha à la souscription (acquisition client)'),
  ('commercial', 'recouvrement_mensuel', 0, '5% de chaque paiement mensuel si recouvrement régulier');
UPDATE public.grille_remuneration SET taux_pourcentage = 5 WHERE role_cible = 'commercial' AND type_remuneration = 'recouvrement_mensuel';
INSERT INTO public.grille_remuneration (role_cible, type_remuneration, montant, taux_pourcentage, description) VALUES
  ('commercial', 'cash', 0, 3, '3% du coût total pour paiement cash');

-- Techniciens An 1
INSERT INTO public.grille_remuneration (role_cible, type_remuneration, montant, annee_application, description) VALUES
  ('technicien', 'salaire_fixe', 75000, 1, 'Salaire fixe mensuel An 1'),
  ('technicien', 'prime_ha', 5000, 1, 'Prime par hectare suivi An 1'),
  ('technicien', 'bonus_qualite', 2500, 1, 'Bonus qualité par hectare An 1');

-- Techniciens An 2
INSERT INTO public.grille_remuneration (role_cible, type_remuneration, montant, annee_application, description) VALUES
  ('technicien', 'salaire_fixe', 85000, 2, 'Salaire fixe mensuel An 2'),
  ('technicien', 'prime_ha', 4000, 2, 'Prime par hectare suivi An 2'),
  ('technicien', 'bonus_qualite', 3500, 2, 'Bonus qualité par hectare An 2');

-- Techniciens An 3
INSERT INTO public.grille_remuneration (role_cible, type_remuneration, montant, annee_application, description) VALUES
  ('technicien', 'salaire_fixe', 100000, 3, 'Salaire fixe mensuel An 3'),
  ('technicien', 'prime_ha', 3000, 3, 'Prime par hectare suivi An 3'),
  ('technicien', 'bonus_qualite', 5000, 3, 'Bonus qualité par hectare An 3');

-- 7. Trigger for updated_at
CREATE TRIGGER update_grille_remuneration_updated_at
  BEFORE UPDATE ON public.grille_remuneration
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
