---
name: Cycle 34 mois
description: Cycle souscripteur sur 34 mois (3 ans de construction de plantation) + revenus reversés 25 ans
type: feature
---
Cycle de vie d'un souscripteur (conforme flyer V2 AgriCapital) :
- Phase de construction : 34 mensualités (12 + 12 + 10) + 1 Dépôt Initial.
- Après les 34 mois : remise de la plantation et reversement des revenus pendant 25 ans (100% pour PalmInvest/TerraPalm, 75% pour les variantes +).
- 4 offres officielles : `palm-invest`, `palm-invest-plus`, `terra-palm`, `terra-palm-plus`.
- Tarifs/ha (PalmInvest/+) : DI 90 700, cash 3 890 700, total 4 190 700, mensualités 60k/120k/194k.
- Tarifs/ha (TerraPalm/+) : DI 84 700, cash 2 294 700, total 2 594 700, mensualités 54k/75k/96 200.
- DB :
  - `offres` : `montant_cash_par_ha`, `montant_total_par_ha`, `montant_depot_initial_par_ha`, `duree_paiement_mois=34`, `gestion_type`, `pourcentage_revenus_reverses`, `tranches_paiement` jsonb.
  - `souscripteurs` : `promotion_id`, `montant_promo_applique`, `phase_actuelle` ∈ {attente_di, annee_1, annee_2, annee_3, termine_construction, production}, `contrat_fin_at = da_paye_at + 34 months`.
  - `paiements` : 34 lignes REDEVANCE générées à la validation du DI, `numero_echeance 1..34`, `phase = annee_1|2|3`.
- Fonctions clés : `recompute_contrat_totaux`, `handle_paiement_valide`, `create_depot_initial`, `compute_paiement_jours_couverts`.
- Vue `v_souscripteur_synthese` expose : mois_payes, mois_restants (sur 34), total_paye, reste_a_payer, pourcentage_avancement, phase_actuelle.
- Promotions : `cible` ∈ {depot_initial, total_contrat}, `pourcentage_reduction` OU `montant_fixe_reduction`, `code` unique. Seed `LANCEMENT25` -25% sur total jusqu'au 30 juin 2026.