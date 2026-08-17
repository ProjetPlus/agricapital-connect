-- ====================================================================
-- SECURITY AUDIT FIXES: Tightening RLS and Storage Policies
-- ====================================================================

-- 1. CLEANUP LEGACY DUMP POLICIES (Very loose policies from pg_dump)
-- We drop them all to ensure a clean state for sensitive tables.
DO $$ 
DECLARE 
    t text;
    p text;
BEGIN
    FOR t, p IN 
        VALUES 
            ('commissions', 'write_commissions'), ('commissions', 'read_commissions'),
            ('configurations_systeme', 'write_configurations'), ('configurations_systeme', 'read_configurations'),
            ('departements', 'write_departements'), ('departements', 'read_departements'),
            ('districts', 'write_districts'), ('districts', 'read_districts'),
            ('documents', 'write_documents'), ('documents', 'read_documents'),
            ('equipes', 'write_equipes'), ('equipes', 'read_equipes'),
            ('historique_activites', 'write_historique'), ('historique_activites', 'read_historique'),
            ('notes', 'write_notes'), ('notes', 'read_notes'),
            ('offres', 'write_offres'), ('offres', 'read_offres'),
            ('paiements', 'write_paiements'), ('paiements', 'read_paiements'),
            ('plantations', 'write_plantations'), ('plantations', 'read_plantations'),
            ('profiles', 'write_profiles'), ('profiles', 'read_profiles'),
            ('promotions', 'write_promotions'), ('promotions', 'read_promotions'),
            ('promotions_offres', 'write_promotions_offres'), ('promotions_offres', 'read_promotions_offres'),
            ('regions', 'write_regions'), ('regions', 'read_regions'),
            ('sous_prefectures', 'write_sous_prefectures'), ('sous_prefectures', 'read_sous_prefectures'),
            ('souscripteurs', 'write_souscripteurs'), ('souscripteurs', 'read_souscripteurs'),
            ('tickets_support', 'write_tickets'), ('tickets_support', 'read_tickets'),
            ('villages', 'write_villages'), ('villages', 'read_villages')
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', p, t);
    END LOOP;
END $$;

-- 2. TIGHTEN REMAINING RECENT POLICIES
DROP POLICY IF EXISTS "Authenticated can read profiles" ON public.profiles;
DROP POLICY IF EXISTS "Authenticated can read roles" ON public.user_roles;
DROP POLICY IF EXISTS "Anyone can read villages" ON public.villages;
DROP POLICY IF EXISTS "Anyone can read districts" ON public.districts;
DROP POLICY IF EXISTS "Anyone can read regions" ON public.regions;
DROP POLICY IF EXISTS "Anyone can read departements" ON public.departements;
DROP POLICY IF EXISTS "Anyone can read sous_prefectures" ON public.sous_prefectures;
DROP POLICY IF EXISTS "Anyone can read offres" ON public.offres;
DROP POLICY IF EXISTS "Anyone can read promotions" ON public.promotions;
DROP POLICY IF EXISTS "read_account_requests" ON public.account_requests;

-- 3. APPLY TIGHT BASELINE POLICIES

-- REFERENTIAL DATA: Authenticated users can read
CREATE POLICY "Auth read districts" ON public.districts FOR SELECT TO authenticated USING (true);
CREATE POLICY "Auth read regions" ON public.regions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Auth read departements" ON public.departements FOR SELECT TO authenticated USING (true);
CREATE POLICY "Auth read sous_prefectures" ON public.sous_prefectures FOR SELECT TO authenticated USING (true);
CREATE POLICY "Auth read villages" ON public.villages FOR SELECT TO authenticated USING (true);
CREATE POLICY "Auth read offres" ON public.offres FOR SELECT TO authenticated USING (true);
CREATE POLICY "Auth read promotions" ON public.promotions FOR SELECT TO authenticated USING (true);

-- SENSITIVE DATA: Staff/Admin only (or owners)
CREATE POLICY "Staff manage commissions" ON public.commissions FOR ALL TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff manage equipes" ON public.equipes FOR ALL TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff manage plantations" ON public.plantations FOR ALL TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff manage souscripteurs" ON public.souscripteurs FOR ALL TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff manage documents" ON public.documents FOR ALL TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff manage paiements" ON public.paiements FOR ALL TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff manage tickets" ON public.tickets_support FOR ALL TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff manage history" ON public.historique_activites FOR ALL TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff manage notes" ON public.notes FOR ALL TO authenticated USING (public.is_staff(auth.uid()));

-- PROFILES: Everyone authenticated can read basic profile info, but update only own or admin
CREATE POLICY "Auth read profiles" ON public.profiles FOR SELECT TO authenticated USING (true);
-- Update own profile is usually already covered by "Users update own profile", let's ensure it's clean
DROP POLICY IF EXISTS "Users update own profile" ON public.profiles;
CREATE POLICY "Users update own profile" ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = user_id OR public.is_admin(auth.uid()));

-- ACCOUNT_REQUESTS: Staff only can read/update
CREATE POLICY "Staff manage account_requests" ON public.account_requests FOR SELECT, UPDATE, DELETE TO authenticated USING (public.is_staff(auth.uid()));

-- 4. STORAGE POLICIES
DROP POLICY IF EXISTS "Public read documents bucket" ON storage.objects;
DROP POLICY IF EXISTS "Public read docs" ON storage.objects;

-- Restricted read for sensitive buckets
CREATE POLICY "Staff read documents" ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'documents' AND public.is_staff(auth.uid()));
CREATE POLICY "Staff read pieces-identite" ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'pieces-identite' AND public.is_staff(auth.uid()));
CREATE POLICY "Staff read documents-fonciers" ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'documents-fonciers' AND public.is_staff(auth.uid()));

-- Public read for profile photos
CREATE POLICY "Public read photos-profils" ON storage.objects FOR SELECT TO public USING (bucket_id = 'photos-profils');

-- 5. FUNCTION SECURITY
REVOKE ALL ON FUNCTION public.is_staff(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_admin(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_staff(uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.is_admin(uuid) TO authenticated, anon;

-- Note: anonymous insert for account_requests and paiements are preserved as they were defined in recent migrations with specific checks.
