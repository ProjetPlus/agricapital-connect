# AgriPlan — Spécification pour le développeur du Portail Client

Le CRM (cette base) est la source de vérité. Le portail ne fait que lire/écrire via Supabase avec la RLS déjà en place.

## Connexion
- Supabase URL / anon key : identiques au CRM (`VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`).
- Le client se connecte avec l'email/téléphone de son compte auth. Son dossier est lié par `agriplan_clients.user_id = auth.uid()`.

## Tables exposées au client (RLS : lecture limitée à son propre dossier)
| Table | Usage portail |
|---|---|
| `agriplan_clients` | identité, `numero_client`, `statut_dossier` |
| `agriplan_ventes` | montant total, total payé, solde, superficie |
| `agriplan_echeances` | échéancier (numéro, libellé, date, montant, statut, montant payé) |
| `paiements` (filtre `parcours = 'AGRIPLAN'`) | historique des paiements + reçus |
| `agriplan_plantations` | Plantation 1..N : localisation, superficie, avancement |
| `agriplan_visites` | rapports techniciens (observations, interventions, état, photos) |
| `agriplan_documents` | contrats, reçus, rapports (bucket privé `agriplan`, URL signée) |
| `agriplan_messages` | échanges client ↔ équipe (le client peut insérer) |
| `agriplan_evenements` | historique / traçabilité (lecture seule) |

## Écritures autorisées au client
- `agriplan_messages` : INSERT (son `client_id` uniquement).
- Aucun autre INSERT/UPDATE : ventes, échéances, visites et paiements sont gérés par le CRM.

## Fichiers
Bucket privé `agriplan`, chemins `clients/<client_id>/...`. Toujours passer par
`supabase.storage.from('agriplan').createSignedUrl(path, 3600)`.

## Écrans attendus
1. Tableau de bord : solde, prochaine échéance, avancement plantation.
2. Plantations : une carte par plantation + état courant.
3. Suivi technique : liste des visites, photos, compte rendu.
4. Paiements : échéancier + historique + reçus téléchargeables.
5. Documents : liste avec téléchargement signé.
6. Échanges : messagerie simple.

## Règles métier
- Une seule offre AgriPlan (`agriplan_offre`, code `agriplan`) : prix, tranches, périodicité d'accompagnement. Ne jamais coder ces montants en dur.
- Le total payé et le solde sont recalculés par trigger côté base : le portail les affiche, ne les calcule pas.
- Un dossier archivé (`statut = 'archive'`) reste consultable en lecture seule.
