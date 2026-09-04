CREATE TABLE IF NOT EXISTS public.cartes_personnel (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  matricule text NOT NULL UNIQUE,
  code_verification text NOT NULL UNIQUE DEFAULT encode(gen_random_bytes(8), 'hex'),
  type_contrat text NOT NULL DEFAULT 'cdi',
  poste text,
  departement text,
  role_code text,
  photo_url text,
  date_delivrance date NOT NULL DEFAULT current_date,
  date_expiration date NOT NULL DEFAULT (current_date + interval '1 year'),
  statut text NOT NULL DEFAULT 'active',
  notes text,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cartes_personnel_profile ON public.cartes_personnel(profile_id);
CREATE INDEX IF NOT EXISTS idx_cartes_personnel_statut ON public.cartes_personnel(statut);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.cartes_personnel TO authenticated;
GRANT ALL ON public.cartes_personnel TO service_role;

ALTER TABLE public.cartes_personnel ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "cartes_select_staff" ON public.cartes_personnel;
CREATE POLICY "cartes_select_staff" ON public.cartes_personnel
  FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "cartes_write_admin" ON public.cartes_personnel;
CREATE POLICY "cartes_write_admin" ON public.cartes_personnel
  FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'responsable_operations'))
  WITH CHECK (public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'responsable_operations'));

DROP TRIGGER IF EXISTS trg_cartes_personnel_updated_at ON public.cartes_personnel;
CREATE TRIGGER trg_cartes_personnel_updated_at
  BEFORE UPDATE ON public.cartes_personnel
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trg_cartes_personnel_audit ON public.cartes_personnel;
CREATE TRIGGER trg_cartes_personnel_audit
  AFTER INSERT OR UPDATE OR DELETE ON public.cartes_personnel
  FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

CREATE OR REPLACE FUNCTION public.verifier_carte(_code text)
RETURNS TABLE(
  matricule text,
  nom_complet text,
  poste text,
  departement text,
  role_code text,
  type_contrat text,
  photo_url text,
  date_delivrance date,
  date_expiration date,
  statut text,
  valide boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT c.matricule,
         p.nom_complet,
         COALESCE(c.poste, p.poste),
         COALESCE(c.departement, p.departement),
         c.role_code,
         c.type_contrat,
         c.photo_url,
         c.date_delivrance,
         c.date_expiration,
         c.statut,
         (c.statut = 'active' AND c.date_expiration >= current_date) AS valide
  FROM public.cartes_personnel c
  JOIN public.profiles p ON p.id = c.profile_id
  WHERE lower(c.code_verification) = lower(_code)
  LIMIT 1
$$;

REVOKE ALL ON FUNCTION public.verifier_carte(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.verifier_carte(text) TO anon, authenticated, service_role;

DROP POLICY IF EXISTS "cartes_photos_read" ON storage.objects;
CREATE POLICY "cartes_photos_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'cartes-personnel');

DROP POLICY IF EXISTS "cartes_photos_write" ON storage.objects;
CREATE POLICY "cartes_photos_write" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'cartes-personnel' AND (public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'responsable_operations')));

DROP POLICY IF EXISTS "cartes_photos_update" ON storage.objects;
CREATE POLICY "cartes_photos_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'cartes-personnel' AND (public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'responsable_operations')));