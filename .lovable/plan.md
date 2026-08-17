## Contexte — correction majeure

Le flyer V2 R impose un modèle **34 mois** (pas 28 ans) :
- **3 ans de construction de plantation** = 34 mensualités (12 + 12 + 10) + 1 Dépôt Initial.
- 4 offres : **PalmInvest**, **PalmInvest+**, **TerraPalm**, **TerraPalm+**.
- Après les 34 mois : remise de plantation + revenus reversés sur 25 ans (100% ou 75% selon offre). Pas de mensualités après mois 34.
- Promo lancement -25 % jusqu'au 30 juin 2026.

---

## 1. Migration DB V5 — Modèle 34 mois

### `offres` (refonte)
Colonnes ajoutées / réutilisées :
- `montant_cash_par_ha` (paiement comptant remisé)
- `montant_total_par_ha` (prix catalogue / ha hors promo)
- `montant_depot_initial_par_ha`
- `duree_paiement_mois` = 34
- `gestion_type` : `propre` | `deleguee`
- `pourcentage_revenus_reverses` : 100 | 75
- `duree_revenus_ans` : 25
- `tranches_paiement` jsonb : `[{annee:1, mois:12, mensualite_par_ha:60000}, {annee:2,mois:12,mensualite_par_ha:120000}, {annee:3,mois:10,mensualite_par_ha:194000}]`
- Suppression de l'usage `redevance_production_par_ha_an`, `duree_production_ans` (gardés mais ignorés / mis à 0).

Seed des 4 offres exactement comme le flyer (par ha) :

```text
PalmInvest   total 4 190 700  cash 3 890 700  DI 90 700  mensualités 60k/120k/194k
PalmInvest+  total 4 190 700  cash 3 890 700  DI 90 700  mensualités 60k/120k/194k  gestion=déléguée  %=75
TerraPalm    total 2 594 700  cash 2 294 700  DI 84 700  mensualités 54k/75k/96 200
TerraPalm+   total 2 594 700  cash 2 294 700  DI 84 700  mensualités 54k/75k/96 200  gestion=déléguée  %=75
```

### `souscripteurs`
- `contrat_fin_at = da_paye_at + 34 months`
- `mensualite_montant` recalculé par phase (an1/an2/an3)
- `phase_actuelle` ∈ `attente_di | annee_1 | annee_2 | annee_3 | termine_construction | production`
- `montant_total_contrat = montant_total_par_ha × hectares` (avec promo si appliquée à la signature)
- `taux_journalier_ha = montant_total_contrat / (34 × 30) / hectares` (pour fractionnement portail)

### `paiements`
- Génération 34 lignes REDEVANCE après validation DI, montant par tranche selon `tranches_paiement`.
- `numero_echeance` 1..34 ; `phase` = `annee_1|2|3`.

### `promotions`
- `cible` text NOT NULL DEFAULT `depot_initial` (`depot_initial` | `total_contrat`) — déjà présent, vérifier.
- `pourcentage_reduction numeric`, `montant_fixe_reduction numeric` (optionnel).
- `code` text unique.
- Seed promo flyer : `LANCEMENT25`, -25 %, cible `total_contrat`, fin 2026‑06‑30.

### Triggers/fonctions à mettre à jour
- `handle_paiement_valide` : génère 34 (pas 36) échéances à partir de `tranches_paiement`.
- `recompute_contrat_totaux` : remplace formule 28 ans par 34 mois flyer.
- `simuler_paiement_fractionne` : utilise nouveau `taux_journalier`.
- `mark_overdue_payments` : inchangé.
- Fonction `apply_promotion(_souscripteur, _promo)` : applique réduction sur DI **ou** total selon `cible`.

### Vue `v_souscripteur_synthese`
Mise à jour pour exposer : `mois_payes`, `mois_restants` (sur 34), `tranche_actuelle`, `prochaine_mensualite`, `total_paye`, `reste_a_payer`, `pourcentage_avancement`, `phase_actuelle`, `date_fin_construction`, `date_debut_production`.

### Storage
Vérifier buckets `preuves-paiement`, `documents-fonciers`, `pieces-identite`, `photos-plantations` : RLS owner-based + staff read. Politiques manquantes ajoutées dans la migration.

### GRANTS & RLS
Re-vérification systématique pour toutes les tables touchées.

---

## 2. Front — pages alignées

| Page | Changement |
|---|---|
| `Etape0Offre` | Sélection parmi 4 offres, affichage tableau tranches (Cash/DI/An1/An2/An3), calcul montant promo selon `cible` |
| `Promotions` | Form : champ `cible` (DI / Total), `pourcentage` ou `montant fixe`, `code`, dates, offres ciblées |
| `Offres` (paramètres) | CRUD des 4 offres avec éditeur `tranches_paiement` |
| `Dashboard` | KPI synthèse 34 mois (mois payés, retard, prochaine échéance) |
| `GestionPaiements` | Colonne `tranche` + `numero_echeance/34` |
| `RapportsFinanciers` | Prévisionnel sur 34 mois (plus de 28 ans) |
| `Souscripteurs` détail | Timeline 3 ans + phase production |
| `Etape6Confirmation` | Récap avec total promo |
| `portal-api` | `synthese`, `echeances` (34), `simuler-paiement`, `promotions-actives?cible=` |

---

## 3. Mémoire
- Réécriture de `mem://logique-metier/cycle-28-ans.md` → renommé `cycle-34-mois.md`.
- Mise à jour de l'index.

---

## 4. Livraison
1. Migration V5 (schéma + seed offres + seed promo + grants/RLS).
2. Refacto `Etape0Offre` + `Promotions` + `Offres`.
3. Mise à jour Dashboard / RapportsFinanciers / GestionPaiements.
4. `portal-api` mis à jour.
5. Mémoire + suppression mention 28 ans.

**Confirme et je lance la migration puis tout le refacto en parallèle.**