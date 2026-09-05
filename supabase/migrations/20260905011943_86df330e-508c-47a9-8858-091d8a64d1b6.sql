-- 1) Card photos in storage: staff only
DROP POLICY IF EXISTS cartes_photos_read ON storage.objects;
CREATE POLICY cartes_photos_read ON storage.objects
FOR SELECT TO authenticated
USING (bucket_id = 'cartes-personnel' AND public.is_staff(auth.uid()));

-- 2) Public card verification: minimal data only, no photo, no department
DROP FUNCTION IF EXISTS public.verifier_carte(text);
CREATE FUNCTION public.verifier_carte(_code text)
RETURNS TABLE(matricule text, nom_complet text, poste text, type_contrat text, date_expiration date, statut text, valide boolean)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT c.matricule,
         p.nom_complet,
         COALESCE(c.poste, p.poste),
         c.type_contrat,
         c.date_expiration,
         c.statut,
         (c.statut = 'active' AND c.date_expiration >= current_date) AS valide
  FROM public.cartes_personnel c
  JOIN public.profiles p ON p.id = c.profile_id
  WHERE length(_code) BETWEEN 6 AND 64
    AND lower(c.code_verification) = lower(_code)
  LIMIT 1
$function$;

REVOKE ALL ON FUNCTION public.verifier_carte(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.verifier_carte(text) TO anon, authenticated, service_role;