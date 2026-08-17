-- Create Haut-Sassandra region under Sassandra-Marahoué district
INSERT INTO regions (nom, code, district_id, est_active) 
VALUES ('Haut-Sassandra', 'HS', 'c552c470-bd75-4985-93f6-7c101251ebc3', true)
ON CONFLICT DO NOTHING;

-- Fix security: tighten account_requests INSERT policy to validate required fields
-- The existing policies are fine - admins only can SELECT/UPDATE
-- The INSERT with true is needed for anonymous account requests

-- Fix commissions: restrict staff to only see their own commissions
DROP POLICY IF EXISTS "Staff can view commissions" ON commissions;
CREATE POLICY "Staff can view own commissions" ON commissions
FOR SELECT USING (
  is_admin(auth.uid()) 
  OR profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
);
