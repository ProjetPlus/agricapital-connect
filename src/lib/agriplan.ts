/**
 * AGRIPLAN — SOURCE DE VÉRITÉ UNIQUE (côté client)
 *
 * Structure validée (flyer AgriPlan) :
 *  A. Mise en place de la plantation : 230 000 FCFA en 4 échéances
 *     1. Acompte                 50 000 FCFA — à la commande
 *     2. Mise en œuvre           80 000 FCFA — après piquetage / avant mobilisation
 *     3. Paiement intermédiaire  50 000 FCFA — échéance suivante
 *     4. Solde de mise en place  50 000 FCFA — dernière échéance
 *  B. Suivi et encadrement : 10 000 FCFA / trimestre pendant 36 mois (12 trimestres) = 120 000 FCFA
 *  Prix global de l'offre : 350 000 FCFA
 *
 * Les montants ne doivent JAMAIS être codés en dur ailleurs : ils proviennent
 * de la table `configurations_systeme` (catégorie `agriplan`) via `useAgriPlan`.
 * Les constantes ci-dessous ne servent que de valeurs de repli avant migration.
 */

export const AGRIPLAN_OFFRE_CODE = "agri-plan";

export interface AgriPlanTranche {
  numero: number;
  libelle: string;
  montant: number;
  declencheur: string;
}

export interface AgriPlanConfig {
  /** Mise en place de la plantation (FCFA) */
  montantMiseEnPlace: number;
  /** Échéancier de la mise en place */
  tranchesMiseEnPlace: AgriPlanTranche[];
  /** Suivi & encadrement par trimestre (FCFA) */
  montantTrimestre: number;
  /** Nombre de trimestres */
  nbTrimestres: number;
  /** Durée totale en mois */
  dureeMois: number;
}

export const AGRIPLAN_DEFAULT_CONFIG: AgriPlanConfig = {
  montantMiseEnPlace: 230_000,
  tranchesMiseEnPlace: [
    { numero: 1, libelle: "Acompte", montant: 50_000, declencheur: "À la commande" },
    { numero: 2, libelle: "Mise en œuvre", montant: 80_000, declencheur: "Après piquetage / avant mobilisation pour la plantation" },
    { numero: 3, libelle: "Paiement intermédiaire", montant: 50_000, declencheur: "Échéance suivante" },
    { numero: 4, libelle: "Solde de mise en place", montant: 50_000, declencheur: "Dernière échéance" },
  ],
  montantTrimestre: 10_000,
  nbTrimestres: 12,
  dureeMois: 36,
};

export interface AgriPlanTotaux {
  miseEnPlace: number;
  accompagnement: number;
  total: number;
}

export function computeAgriPlanTotaux(cfg: AgriPlanConfig): AgriPlanTotaux {
  const miseEnPlace = cfg.tranchesMiseEnPlace.length
    ? cfg.tranchesMiseEnPlace.reduce((s, t) => s + t.montant, 0)
    : cfg.montantMiseEnPlace;
  const accompagnement = cfg.montantTrimestre * cfg.nbTrimestres;
  return { miseEnPlace, accompagnement, total: miseEnPlace + accompagnement };
}

export type AgriPlanEcheanceStatut = "a_venir" | "du" | "paye" | "en_retard" | "annule";

export interface AgriPlanEcheance {
  id: string;
  numero_echeance: number;
  /** mise_en_place = tranches A, accompagnement = trimestres B */
  type: "mise_en_place" | "accompagnement";
  libelle: string;
  declencheur: string;
  annee: number;
  trimestre: number;
  date_echeance: string; // ISO yyyy-mm-dd
  montant: number;
  statut: AgriPlanEcheanceStatut;
  date_paiement: string | null;
  montant_paye: number;
  solde: number;
  jours_retard: number;
  reference_paiement: string | null;
  moyen_paiement: string | null;
}

const iso = (d: Date) => d.toISOString().slice(0, 10);

function addMonths(date: Date, months: number): Date {
  const d = new Date(date.getTime());
  const day = d.getDate();
  d.setMonth(d.getMonth() + months);
  if (d.getDate() < day) d.setDate(0);
  return d;
}

/**
 * Génère l'échéancier prévisionnel AgriPlan :
 * 4 tranches de mise en place + N échéances trimestrielles d'accompagnement.
 */
export function buildAgriPlanEcheancier(
  cfg: AgriPlanConfig,
  dateDebut: Date | string = new Date(),
  today: Date = new Date(),
): AgriPlanEcheance[] {
  const start = typeof dateDebut === "string" ? new Date(dateDebut) : dateDebut;
  const rows: AgriPlanEcheance[] = [];

  cfg.tranchesMiseEnPlace.forEach((t, i) => {
    const echeance = addMonths(start, i); // 1 tranche / mois par défaut
    const retard = Math.floor((today.getTime() - echeance.getTime()) / 86_400_000);
    rows.push({
      id: `agriplan-mep-${t.numero}`,
      numero_echeance: t.numero,
      type: "mise_en_place",
      libelle: t.libelle,
      declencheur: t.declencheur,
      annee: 1,
      trimestre: 0,
      date_echeance: iso(echeance),
      montant: t.montant,
      statut: retard > 0 ? "en_retard" : echeance <= today ? "du" : "a_venir",
      date_paiement: null,
      montant_paye: 0,
      solde: t.montant,
      jours_retard: retard > 0 ? retard : 0,
      reference_paiement: null,
      moyen_paiement: null,
    });
  });

  for (let i = 1; i <= cfg.nbTrimestres; i++) {
    const echeance = addMonths(start, i * 3);
    const retard = Math.floor((today.getTime() - echeance.getTime()) / 86_400_000);
    rows.push({
      id: `agriplan-t${i}`,
      numero_echeance: cfg.tranchesMiseEnPlace.length + i,
      type: "accompagnement",
      libelle: `Suivi trimestre ${i}`,
      declencheur: `Trimestre ${((i - 1) % 4) + 1} — année ${Math.ceil(i / 4)}`,
      annee: Math.ceil(i / 4),
      trimestre: ((i - 1) % 4) + 1,
      date_echeance: iso(echeance),
      montant: cfg.montantTrimestre,
      statut: retard > 0 ? "en_retard" : echeance <= today ? "du" : "a_venir",
      date_paiement: null,
      montant_paye: 0,
      solde: cfg.montantTrimestre,
      jours_retard: retard > 0 ? retard : 0,
      reference_paiement: null,
      moyen_paiement: null,
    });
  }

  return rows;
}

export interface AgriPlanSynthese {
  totalPrevu: number;
  totalPaye: number;
  totalRestant: number;
  prochaines: AgriPlanEcheance[];
  enRetard: AgriPlanEcheance[];
  pourcentageAvancement: number;
}

export function summarizeAgriPlan(echeances: AgriPlanEcheance[]): AgriPlanSynthese {
  const actives = echeances.filter((e) => e.statut !== "annule");
  const totalPrevu = actives.reduce((s, e) => s + e.montant, 0);
  const totalPaye = actives.reduce((s, e) => s + (e.montant_paye || 0), 0);
  return {
    totalPrevu,
    totalPaye,
    totalRestant: Math.max(totalPrevu - totalPaye, 0),
    prochaines: actives.filter((e) => e.statut === "a_venir" || e.statut === "du").slice(0, 3),
    enRetard: actives.filter((e) => e.statut === "en_retard"),
    pourcentageAvancement: totalPrevu > 0 ? Math.round((totalPaye / totalPrevu) * 100) : 0,
  };
}

/** Prestations incluses / exclues du forfait AgriPlan (flyer) */
export const AGRIPLAN_INCLUS: string[] = [
  "Inspection de la parcelle",
  "Piquetage professionnel",
  "Trouaison professionnelle",
  "Fourniture des plants",
  "Transport des plants",
  "Assistance mise en place / plantation",
  "Suivi et encadrement pendant 36 mois",
];

export const AGRIPLAN_EXCLUS: string[] = [
  "Intrants (engrais, produits phytosanitaires, etc.)",
  "Fournitures supplémentaires",
  "Prestations supplémentaires hors forfait",
];

export const AGRIPLAN_ACCOMPAGNEMENT: string[] = [
  "Suivi de l'évolution de la plantation",
  "Visite de parcelle",
  "Conseils techniques",
  "Encadrement client",
  "Évaluation de l'état de la plantation",
  "Évolution du projet",
  "Compte rendu de visite",
  "Historique des suivis",
];

export const formatFCFA = (n: number) => `${Math.round(n).toLocaleString("fr-FR")} FCFA`;
