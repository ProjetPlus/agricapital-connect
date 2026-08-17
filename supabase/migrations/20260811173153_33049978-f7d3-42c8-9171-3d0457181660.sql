-- 1. Stakeholders: restrict SELECT to finance/admin roles
DROP POLICY IF EXISTS "Authenticated users can view stakeholders" ON public.stakeholders;
CREATE POLICY "Finance roles can view stakeholders"
ON public.stakeholders FOR SELECT TO authenticated
USING (
  is_admin(auth.uid())
  OR has_role(auth.uid(), 'comptable'::app_role)
  OR has_role(auth.uid(), 'raf'::app_role)
);

-- 2. Audit logs: no direct client inserts (system/service role only)
DROP POLICY IF EXISTS "System can insert audit logs" ON public.audit_logs;

-- 3. Documents: restrict SELECT to owner, related transaction creator, or privileged roles
DROP POLICY IF EXISTS "Authenticated users can view documents" ON public.documents;
CREATE POLICY "Users can view own or related documents"
ON public.documents FOR SELECT TO authenticated
USING (
  auth.uid() = uploaded_by
  OR is_admin(auth.uid())
  OR has_role(auth.uid(), 'comptable'::app_role)
  OR has_role(auth.uid(), 'raf'::app_role)
  OR EXISTS (
    SELECT 1 FROM public.transactions t
    WHERE t.id = documents.transaction_id
      AND t.created_by = auth.uid()
  )
);

-- 4. Storage: restrict reads of the private documents bucket
DROP POLICY IF EXISTS "Authenticated users can view documents" ON storage.objects;
CREATE POLICY "Users can view own documents in storage"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'documents'
  AND (
    owner = auth.uid()
    OR (storage.foldername(name))[1] = auth.uid()::text
    OR is_admin(auth.uid())
    OR has_role(auth.uid(), 'comptable'::app_role)
    OR has_role(auth.uid(), 'raf'::app_role)
  )
);

DROP POLICY IF EXISTS "Authenticated users can upload documents" ON storage.objects;
CREATE POLICY "Users can upload own documents to storage"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'documents'
  AND (
    owner = auth.uid()
    OR (storage.foldername(name))[1] = auth.uid()::text
    OR is_admin(auth.uid())
  )
);