
-- 1. Add convention fields to proprietaires_terres
ALTER TABLE public.proprietaires_terres 
  ADD COLUMN IF NOT EXISTS type_proprietaire text DEFAULT 'personne_physique' CHECK (type_proprietaire IN ('personne_physique', 'personne_morale', 'famille_groupement')),
  ADD COLUMN IF NOT EXISTS nom_pere text,
  ADD COLUMN IF NOT EXISTS nom_mere text,
  ADD COLUMN IF NOT EXISTS denomination_sociale text,
  ADD COLUMN IF NOT EXISTS numero_enregistrement text,
  ADD COLUMN IF NOT EXISTS nombre_membres integer,
  ADD COLUMN IF NOT EXISTS nom_representant text,
  ADD COLUMN IF NOT EXISTS statut_foncier text DEFAULT 'coutumier' CHECK (statut_foncier IN ('certifie', 'titre', 'coutumier', 'autre')),
  ADD COLUMN IF NOT EXISTS reference_cadastrale text,
  ADD COLUMN IF NOT EXISTS limites_nord text,
  ADD COLUMN IF NOT EXISTS limites_sud text,
  ADD COLUMN IF NOT EXISTS limites_est text,
  ADD COLUMN IF NOT EXISTS limites_ouest text,
  ADD COLUMN IF NOT EXISTS servitudes text,
  ADD COLUMN IF NOT EXISTS croquis_joint boolean DEFAULT false;

-- 2. Create cotitulaires_mandataires table
CREATE TABLE IF NOT EXISTS public.cotitulaires_mandataires (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  proprietaire_id uuid NOT NULL REFERENCES public.proprietaires_terres(id) ON DELETE CASCADE,
  nom text NOT NULL,
  prenoms text,
  lien_proprietaire text,
  type_piece text,
  numero_piece text,
  date_naissance date,
  lieu_naissance text,
  telephone text,
  whatsapp text,
  est_mandataire boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.cotitulaires_mandataires ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Staff manage cotitulaires" ON public.cotitulaires_mandataires FOR ALL TO authenticated USING (is_staff(auth.uid())) WITH CHECK (is_staff(auth.uid()));
CREATE POLICY "Admins delete cotitulaires" ON public.cotitulaires_mandataires FOR DELETE TO authenticated USING (is_admin(auth.uid()));

-- 3. Create documents_convention table for annexes
CREATE TABLE IF NOT EXISTS public.documents_convention (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  proprietaire_id uuid REFERENCES public.proprietaires_terres(id) ON DELETE CASCADE,
  parcelle_id uuid REFERENCES public.parcelles(id) ON DELETE SET NULL,
  type_document text NOT NULL CHECK (type_document IN (
    'pv_delimitation', 'acte_reconnaissance_parts', 'pv_consentement_familial', 
    'acte_remise_plantation', 'procuration_mandataire',
    'cni_recto', 'cni_verso', 'photo_profil', 'croquis_parcellaire',
    'attestation_villageoise', 'certificat_foncier', 'autre'
  )),
  designation text NOT NULL,
  statut text DEFAULT 'a_fournir' CHECK (statut IN ('joint', 'a_fournir', 'valide', 'rejete')),
  fichier_url text,
  notes text,
  uploaded_by uuid,
  validated_by uuid,
  validated_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.documents_convention ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Staff manage documents_convention" ON public.documents_convention FOR ALL TO authenticated USING (is_staff(auth.uid())) WITH CHECK (is_staff(auth.uid()));
CREATE POLICY "Admins delete documents_convention" ON public.documents_convention FOR DELETE TO authenticated USING (is_admin(auth.uid()));

-- 4. Add triggers for updated_at
CREATE TRIGGER update_cotitulaires_updated_at BEFORE UPDATE ON public.cotitulaires_mandataires FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_documents_convention_updated_at BEFORE UPDATE ON public.documents_convention FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 5. Fix: ensure profiles with NULL user_id can still be updated by admins
-- The existing RLS policy already handles this: (auth.uid() = user_id) OR is_admin(auth.uid())
-- No change needed.

-- 6. Add foreign keys that may be missing (safe with IF NOT EXISTS pattern)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'parcelles_proprietaire_id_fkey' AND table_name = 'parcelles') THEN
    ALTER TABLE public.parcelles ADD CONSTRAINT parcelles_proprietaire_id_fkey FOREIGN KEY (proprietaire_id) REFERENCES public.proprietaires_terres(id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'plantations_souscripteur_id_fkey' AND table_name = 'plantations') THEN
    ALTER TABLE public.plantations ADD CONSTRAINT plantations_souscripteur_id_fkey FOREIGN KEY (souscripteur_id) REFERENCES public.souscripteurs(id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'plantations_parcelle_id_fkey' AND table_name = 'plantations') THEN
    ALTER TABLE public.plantations ADD CONSTRAINT plantations_parcelle_id_fkey FOREIGN KEY (parcelle_id) REFERENCES public.parcelles(id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'paiements_souscripteur_id_fkey' AND table_name = 'paiements') THEN
    ALTER TABLE public.paiements ADD CONSTRAINT paiements_souscripteur_id_fkey FOREIGN KEY (souscripteur_id) REFERENCES public.souscripteurs(id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'paiements_plantation_id_fkey' AND table_name = 'paiements') THEN
    ALTER TABLE public.paiements ADD CONSTRAINT paiements_plantation_id_fkey FOREIGN KEY (plantation_id) REFERENCES public.plantations(id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'commissions_profile_id_fkey' AND table_name = 'commissions') THEN
    ALTER TABLE public.commissions ADD CONSTRAINT commissions_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'commissions_plantation_id_fkey' AND table_name = 'commissions') THEN
    ALTER TABLE public.commissions ADD CONSTRAINT commissions_plantation_id_fkey FOREIGN KEY (plantation_id) REFERENCES public.plantations(id);
  END IF;
END $$;

-- 7. Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_proprietaires_district ON public.proprietaires_terres(district_id);
CREATE INDEX IF NOT EXISTS idx_proprietaires_region ON public.proprietaires_terres(region_id);
CREATE INDEX IF NOT EXISTS idx_parcelles_proprietaire ON public.parcelles(proprietaire_id);
CREATE INDEX IF NOT EXISTS idx_plantations_souscripteur ON public.plantations(souscripteur_id);
CREATE INDEX IF NOT EXISTS idx_plantations_parcelle ON public.plantations(parcelle_id);
CREATE INDEX IF NOT EXISTS idx_paiements_souscripteur ON public.paiements(souscripteur_id);
CREATE INDEX IF NOT EXISTS idx_paiements_plantation ON public.paiements(plantation_id);
CREATE INDEX IF NOT EXISTS idx_commissions_profile ON public.commissions(profile_id);
CREATE INDEX IF NOT EXISTS idx_documents_convention_proprietaire ON public.documents_convention(proprietaire_id);
CREATE INDEX IF NOT EXISTS idx_cotitulaires_proprietaire ON public.cotitulaires_mandataires(proprietaire_id);
