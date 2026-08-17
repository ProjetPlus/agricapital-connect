
-- 1) account_requests: drop plaintext password column
ALTER TABLE public.account_requests DROP COLUMN IF EXISTS password_souhaite;

-- 2) leads: restrict anonymous inserts to safe fields with server-controlled defaults
DROP POLICY IF EXISTS "Anon can insert leads" ON public.leads;
CREATE POLICY "Anon can insert leads"
ON public.leads
FOR INSERT
TO anon
WITH CHECK (
  statut = 'nouveau'
  AND assigned_to IS NULL
  AND souscripteur_id IS NULL
  AND converti_at IS NULL
  AND created_by IS NULL
  AND prochaine_relance_at IS NULL
  AND nom IS NOT NULL
  AND length(btrim(nom)) BETWEEN 2 AND 120
  AND telephone IS NOT NULL
  AND length(btrim(telephone)) BETWEEN 6 AND 30
  AND (email IS NULL OR email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$')
  AND (source IS NULL OR source IN ('site_web','formulaire_public','landing','referral'))
);

-- 3) photos-profils: add explicit RLS policies (bucket is being switched to private separately)
DROP POLICY IF EXISTS "Users read own profile photo" ON storage.objects;
CREATE POLICY "Users read own profile photo"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'photos-profils'
  AND (storage.foldername(name))[1] = (auth.uid())::text
);

DROP POLICY IF EXISTS "Staff read all profile photos" ON storage.objects;
CREATE POLICY "Staff read all profile photos"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'photos-profils'
  AND public.is_staff(auth.uid())
);

DROP POLICY IF EXISTS "Users update own profile photo" ON storage.objects;
CREATE POLICY "Users update own profile photo"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'photos-profils'
  AND (storage.foldername(name))[1] = (auth.uid())::text
)
WITH CHECK (
  bucket_id = 'photos-profils'
  AND (storage.foldername(name))[1] = (auth.uid())::text
);

DROP POLICY IF EXISTS "Users delete own profile photo" ON storage.objects;
CREATE POLICY "Users delete own profile photo"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'photos-profils'
  AND (storage.foldername(name))[1] = (auth.uid())::text
);
