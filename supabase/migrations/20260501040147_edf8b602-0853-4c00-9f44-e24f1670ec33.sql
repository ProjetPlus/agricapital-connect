-- Nettoyage des références orphelines
UPDATE public.proprietaires_terres SET district_id = NULL WHERE district_id IS NOT NULL AND district_id NOT IN (SELECT id FROM public.districts);
UPDATE public.proprietaires_terres SET region_id = NULL WHERE region_id IS NOT NULL AND region_id NOT IN (SELECT id FROM public.regions);
UPDATE public.proprietaires_terres SET departement_id = NULL WHERE departement_id IS NOT NULL AND departement_id NOT IN (SELECT id FROM public.departements);
UPDATE public.proprietaires_terres SET sous_prefecture_id = NULL WHERE sous_prefecture_id IS NOT NULL AND sous_prefecture_id NOT IN (SELECT id FROM public.sous_prefectures);
UPDATE public.parcelles SET proprietaire_id = NULL WHERE proprietaire_id IS NOT NULL AND proprietaire_id NOT IN (SELECT id FROM public.proprietaires_terres);
UPDATE public.parcelles SET district_id = NULL WHERE district_id IS NOT NULL AND district_id NOT IN (SELECT id FROM public.districts);
UPDATE public.parcelles SET region_id = NULL WHERE region_id IS NOT NULL AND region_id NOT IN (SELECT id FROM public.regions);
UPDATE public.parcelles SET departement_id = NULL WHERE departement_id IS NOT NULL AND departement_id NOT IN (SELECT id FROM public.departements);
UPDATE public.parcelles SET sous_prefecture_id = NULL WHERE sous_prefecture_id IS NOT NULL AND sous_prefecture_id NOT IN (SELECT id FROM public.sous_prefectures);
UPDATE public.plantations SET souscripteur_id = NULL WHERE souscripteur_id IS NOT NULL AND souscripteur_id NOT IN (SELECT id FROM public.souscripteurs);
UPDATE public.plantations SET parcelle_id = NULL WHERE parcelle_id IS NOT NULL AND parcelle_id NOT IN (SELECT id FROM public.parcelles);
UPDATE public.plantations SET district_id = NULL WHERE district_id IS NOT NULL AND district_id NOT IN (SELECT id FROM public.districts);
UPDATE public.plantations SET region_id = NULL WHERE region_id IS NOT NULL AND region_id NOT IN (SELECT id FROM public.regions);
UPDATE public.plantations SET departement_id = NULL WHERE departement_id IS NOT NULL AND departement_id NOT IN (SELECT id FROM public.departements);
UPDATE public.plantations SET sous_prefecture_id = NULL WHERE sous_prefecture_id IS NOT NULL AND sous_prefecture_id NOT IN (SELECT id FROM public.sous_prefectures);
UPDATE public.souscripteurs SET offre_id = NULL WHERE offre_id IS NOT NULL AND offre_id NOT IN (SELECT id FROM public.offres);
UPDATE public.souscripteurs SET parcelle_id = NULL WHERE parcelle_id IS NOT NULL AND parcelle_id NOT IN (SELECT id FROM public.parcelles);
UPDATE public.souscripteurs SET district_id = NULL WHERE district_id IS NOT NULL AND district_id NOT IN (SELECT id FROM public.districts);
UPDATE public.souscripteurs SET region_id = NULL WHERE region_id IS NOT NULL AND region_id NOT IN (SELECT id FROM public.regions);
UPDATE public.souscripteurs SET departement_id = NULL WHERE departement_id IS NOT NULL AND departement_id NOT IN (SELECT id FROM public.departements);
UPDATE public.souscripteurs SET sous_prefecture_id = NULL WHERE sous_prefecture_id IS NOT NULL AND sous_prefecture_id NOT IN (SELECT id FROM public.sous_prefectures);
UPDATE public.profiles SET equipe_id = NULL WHERE equipe_id IS NOT NULL AND equipe_id NOT IN (SELECT id FROM public.equipes);
UPDATE public.commissions SET profile_id = NULL WHERE profile_id IS NOT NULL AND profile_id NOT IN (SELECT id FROM public.profiles);
UPDATE public.commissions SET plantation_id = NULL WHERE plantation_id IS NOT NULL AND plantation_id NOT IN (SELECT id FROM public.plantations);
UPDATE public.paiements SET souscripteur_id = NULL WHERE souscripteur_id IS NOT NULL AND souscripteur_id NOT IN (SELECT id FROM public.souscripteurs);
UPDATE public.paiements SET plantation_id = NULL WHERE plantation_id IS NOT NULL AND plantation_id NOT IN (SELECT id FROM public.plantations);
UPDATE public.tickets_techniques SET plantation_id = NULL WHERE plantation_id IS NOT NULL AND plantation_id NOT IN (SELECT id FROM public.plantations);
UPDATE public.tickets_techniques SET cree_par = NULL WHERE cree_par IS NOT NULL AND cree_par NOT IN (SELECT id FROM public.profiles);
UPDATE public.tickets_techniques SET assigne_a = NULL WHERE assigne_a IS NOT NULL AND assigne_a NOT IN (SELECT id FROM public.profiles);
UPDATE public.equipes SET responsable_id = NULL WHERE responsable_id IS NOT NULL AND responsable_id NOT IN (SELECT id FROM public.profiles);
UPDATE public.equipes SET superviseur_id = NULL WHERE superviseur_id IS NOT NULL AND superviseur_id NOT IN (SELECT id FROM public.profiles);
UPDATE public.equipes SET region_id = NULL WHERE region_id IS NOT NULL AND region_id NOT IN (SELECT id FROM public.regions);
UPDATE public.retraits_portefeuille SET portefeuille_id = NULL WHERE portefeuille_id IS NOT NULL AND portefeuille_id NOT IN (SELECT id FROM public.portefeuilles);
UPDATE public.cotitulaires_mandataires SET proprietaire_id = NULL WHERE proprietaire_id IS NOT NULL AND proprietaire_id NOT IN (SELECT id FROM public.proprietaires_terres);
UPDATE public.documents_convention SET proprietaire_id = NULL WHERE proprietaire_id IS NOT NULL AND proprietaire_id NOT IN (SELECT id FROM public.proprietaires_terres);
UPDATE public.documents_convention SET parcelle_id = NULL WHERE parcelle_id IS NOT NULL AND parcelle_id NOT IN (SELECT id FROM public.parcelles);
UPDATE public.regions SET district_id = NULL WHERE district_id IS NOT NULL AND district_id NOT IN (SELECT id FROM public.districts);
UPDATE public.departements SET region_id = NULL WHERE region_id IS NOT NULL AND region_id NOT IN (SELECT id FROM public.regions);
UPDATE public.sous_prefectures SET departement_id = NULL WHERE departement_id IS NOT NULL AND departement_id NOT IN (SELECT id FROM public.departements);
UPDATE public.villages SET sous_prefecture_id = NULL WHERE sous_prefecture_id IS NOT NULL AND sous_prefecture_id NOT IN (SELECT id FROM public.sous_prefectures);

-- ============ FOREIGN KEYS IDEMPOTENTES ============
DO $$ 
DECLARE
  fks TEXT[][] := ARRAY[
    -- table, constraint, column, ref_table, ref_column, on_delete
    ARRAY['regions','regions_district_id_fkey','district_id','districts','id','SET NULL'],
    ARRAY['departements','departements_region_id_fkey','region_id','regions','id','SET NULL'],
    ARRAY['sous_prefectures','sous_prefectures_departement_id_fkey','departement_id','departements','id','SET NULL'],
    ARRAY['villages','villages_sous_prefecture_id_fkey','sous_prefecture_id','sous_prefectures','id','SET NULL'],
    ARRAY['proprietaires_terres','proprietaires_terres_district_id_fkey','district_id','districts','id','SET NULL'],
    ARRAY['proprietaires_terres','proprietaires_terres_region_id_fkey','region_id','regions','id','SET NULL'],
    ARRAY['proprietaires_terres','proprietaires_terres_departement_id_fkey','departement_id','departements','id','SET NULL'],
    ARRAY['proprietaires_terres','proprietaires_terres_sous_prefecture_id_fkey','sous_prefecture_id','sous_prefectures','id','SET NULL'],
    ARRAY['parcelles','parcelles_proprietaire_id_fkey','proprietaire_id','proprietaires_terres','id','SET NULL'],
    ARRAY['parcelles','parcelles_district_id_fkey','district_id','districts','id','SET NULL'],
    ARRAY['parcelles','parcelles_region_id_fkey','region_id','regions','id','SET NULL'],
    ARRAY['parcelles','parcelles_departement_id_fkey','departement_id','departements','id','SET NULL'],
    ARRAY['parcelles','parcelles_sous_prefecture_id_fkey','sous_prefecture_id','sous_prefectures','id','SET NULL'],
    ARRAY['plantations','plantations_souscripteur_id_fkey','souscripteur_id','souscripteurs','id','SET NULL'],
    ARRAY['plantations','plantations_parcelle_id_fkey','parcelle_id','parcelles','id','SET NULL'],
    ARRAY['plantations','plantations_district_id_fkey','district_id','districts','id','SET NULL'],
    ARRAY['plantations','plantations_region_id_fkey','region_id','regions','id','SET NULL'],
    ARRAY['plantations','plantations_departement_id_fkey','departement_id','departements','id','SET NULL'],
    ARRAY['plantations','plantations_sous_prefecture_id_fkey','sous_prefecture_id','sous_prefectures','id','SET NULL'],
    ARRAY['souscripteurs','souscripteurs_offre_id_fkey','offre_id','offres','id','SET NULL'],
    ARRAY['souscripteurs','souscripteurs_parcelle_id_fkey','parcelle_id','parcelles','id','SET NULL'],
    ARRAY['souscripteurs','souscripteurs_district_id_fkey','district_id','districts','id','SET NULL'],
    ARRAY['souscripteurs','souscripteurs_region_id_fkey','region_id','regions','id','SET NULL'],
    ARRAY['souscripteurs','souscripteurs_departement_id_fkey','departement_id','departements','id','SET NULL'],
    ARRAY['souscripteurs','souscripteurs_sous_prefecture_id_fkey','sous_prefecture_id','sous_prefectures','id','SET NULL'],
    ARRAY['profiles','profiles_equipe_id_fkey','equipe_id','equipes','id','SET NULL'],
    ARRAY['commissions','commissions_profile_id_fkey','profile_id','profiles','id','SET NULL'],
    ARRAY['commissions','commissions_plantation_id_fkey','plantation_id','plantations','id','SET NULL'],
    ARRAY['paiements','paiements_souscripteur_id_fkey','souscripteur_id','souscripteurs','id','SET NULL'],
    ARRAY['paiements','paiements_plantation_id_fkey','plantation_id','plantations','id','SET NULL'],
    ARRAY['tickets_techniques','tickets_techniques_plantation_id_fkey','plantation_id','plantations','id','SET NULL'],
    ARRAY['tickets_techniques','tickets_techniques_cree_par_fkey','cree_par','profiles','id','SET NULL'],
    ARRAY['tickets_techniques','tickets_techniques_assigne_a_fkey','assigne_a','profiles','id','SET NULL'],
    ARRAY['equipes','equipes_responsable_id_fkey','responsable_id','profiles','id','SET NULL'],
    ARRAY['equipes','equipes_superviseur_id_fkey','superviseur_id','profiles','id','SET NULL'],
    ARRAY['equipes','equipes_region_id_fkey','region_id','regions','id','SET NULL'],
    ARRAY['retraits_portefeuille','retraits_portefeuille_portefeuille_id_fkey','portefeuille_id','portefeuilles','id','SET NULL'],
    ARRAY['cotitulaires_mandataires','cotitulaires_proprietaire_id_fkey','proprietaire_id','proprietaires_terres','id','CASCADE'],
    ARRAY['documents_convention','documents_convention_proprietaire_id_fkey','proprietaire_id','proprietaires_terres','id','SET NULL'],
    ARRAY['documents_convention','documents_convention_parcelle_id_fkey','parcelle_id','parcelles','id','SET NULL']
  ];
  fk TEXT[];
BEGIN
  FOREACH fk SLICE 1 IN ARRAY fks LOOP
    EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT IF EXISTS %I', fk[1], fk[2]);
    EXECUTE format('ALTER TABLE public.%I ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES public.%I(%I) ON DELETE %s',
      fk[1], fk[2], fk[3], fk[4], fk[5], fk[6]);
  END LOOP;
END $$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_parcelles_proprietaire ON public.parcelles(proprietaire_id);
CREATE INDEX IF NOT EXISTS idx_plantations_souscripteur ON public.plantations(souscripteur_id);
CREATE INDEX IF NOT EXISTS idx_plantations_parcelle ON public.plantations(parcelle_id);
CREATE INDEX IF NOT EXISTS idx_souscripteurs_parcelle ON public.souscripteurs(parcelle_id);
CREATE INDEX IF NOT EXISTS idx_paiements_souscripteur ON public.paiements(souscripteur_id);
CREATE INDEX IF NOT EXISTS idx_commissions_profile ON public.commissions(profile_id);