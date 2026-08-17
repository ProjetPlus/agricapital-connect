
-- Add type_promotion to promotions table
ALTER TABLE public.promotions 
ADD COLUMN IF NOT EXISTS type_promotion text NOT NULL DEFAULT 'depot_initial';

COMMENT ON COLUMN public.promotions.type_promotion IS 'depot_initial = reduction on DA only, cout_global = reduction on total subscription cost';

-- Add nationalite to souscripteurs
ALTER TABLE public.souscripteurs
ADD COLUMN IF NOT EXISTS nationalite text DEFAULT 'Ivoirienne';

-- Add missing sous-prefectures for Haut-Sassandra
INSERT INTO public.sous_prefectures (nom, departement_id, est_active)
SELECT * FROM (VALUES
  ('Boguédia', 'e226f9ca-3eeb-4c11-a966-824a839736af'::uuid, true),
  ('Nahio', 'e226f9ca-3eeb-4c11-a966-824a839736af'::uuid, true),
  ('Iboguhé', 'e226f9ca-3eeb-4c11-a966-824a839736af'::uuid, true),
  ('Séitifla', 'c39d3bb3-46a5-41b7-9c0b-b525dd01687d'::uuid, true),
  ('Dananon', 'c39d3bb3-46a5-41b7-9c0b-b525dd01687d'::uuid, true),
  ('Dobouo', 'a575d61e-df99-4215-9b92-ce8d0a6d38db'::uuid, true)
) AS t(nom, departement_id, est_active)
WHERE NOT EXISTS (
  SELECT 1 FROM public.sous_prefectures sp 
  WHERE sp.nom = t.nom AND sp.departement_id = t.departement_id
);

-- Create souscriptions_brouillon if not exists
CREATE TABLE IF NOT EXISTS public.souscriptions_brouillon (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_by uuid NOT NULL,
  etape_actuelle integer DEFAULT 0,
  donnees jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.souscriptions_brouillon ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'souscriptions_brouillon' AND policyname = 'Users manage own drafts') THEN
    CREATE POLICY "Users manage own drafts" ON public.souscriptions_brouillon
    FOR ALL TO authenticated
    USING (auth.uid() = created_by)
    WITH CHECK (auth.uid() = created_by);
  END IF;
END $$;

-- Storage policies for anonymous account request uploads
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'objects' 
    AND schemaname = 'storage'
    AND policyname = 'Anon upload account-request docs'
  ) THEN
    CREATE POLICY "Anon upload account-request docs" ON storage.objects
    FOR INSERT TO anon, authenticated
    WITH CHECK (bucket_id = 'documents' AND (storage.foldername(name))[1] = 'account-requests');
  END IF;
END $$;

-- Ensure trigger exists for updated_at on souscriptions_brouillon
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_souscriptions_brouillon_updated_at') THEN
    CREATE TRIGGER update_souscriptions_brouillon_updated_at
    BEFORE UPDATE ON public.souscriptions_brouillon
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
  END IF;
END $$;
