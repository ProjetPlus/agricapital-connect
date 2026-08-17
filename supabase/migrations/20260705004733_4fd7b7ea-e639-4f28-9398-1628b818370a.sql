
-- 1. Mise à jour des offres : 75% → 70% de revenus reversés (gestion déléguée)
UPDATE public.offres
   SET pourcentage_revenus_reverses = 70,
       avantages = replace(avantages::text, '75%', '70%')::jsonb,
       updated_at = now()
 WHERE gestion_type = 'deleguee'
   AND pourcentage_revenus_reverses = 75;

-- Nettoyage général au cas où d'autres offres contiendraient encore "75%" dans avantages
UPDATE public.offres
   SET avantages = replace(avantages::text, '75%', '70%')::jsonb,
       updated_at = now()
 WHERE avantages::text LIKE '%75%%';

-- 2. Ajout des tables au publication temps réel (idempotent)
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.offres;
  EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.promotions;
  EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.souscripteurs;
  EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.paiements;
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

-- Diffuser les colonnes complètes pour UPDATE (utile pour le portail)
ALTER TABLE public.offres REPLICA IDENTITY FULL;
ALTER TABLE public.promotions REPLICA IDENTITY FULL;
ALTER TABLE public.souscripteurs REPLICA IDENTITY FULL;
ALTER TABLE public.paiements REPLICA IDENTITY FULL;

-- 3. RLS leads : s'assurer que le staff peut lire tout, convertir et suivre l'historique
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
     WHERE schemaname='public' AND tablename='leads'
       AND policyname='Staff can manage all leads'
  ) THEN
    EXECUTE $p$
      CREATE POLICY "Staff can manage all leads"
        ON public.leads FOR ALL
        TO authenticated
        USING (public.is_staff(auth.uid()))
        WITH CHECK (public.is_staff(auth.uid()))
    $p$;
  END IF;
END $$;

-- 4. Déclenche le recalcul global pour appliquer les nouvelles valeurs
SELECT public.recompute_pending_di();
