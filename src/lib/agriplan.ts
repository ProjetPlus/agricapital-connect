/**
 * AGRIPLAN — SOURCE DE VÉRITÉ UNIQUE (côté client)
 *
 * Parcours AgriPlan : Lead → Vente → Client AgriPlan → Plantation(s) → Paiements → Suivi technique
 *
 * La configuration commerciale (prix, tranches, accompagnement) provient EXCLUSIVEMENT
 * de la table `agriplan_offre` (Paramètres → Offres → AgriPlan).
 * Les valeurs ci-dessous ne servent que de repli d'affichage.
 */

export const AGRIPLAN_PARCOURS = "AGRIPLAN" as const;
export const AGRIPLAN_BUCKET = "agriplan" as const;

export interface AgriPlanTranche {
  numero: number;
  libelle: string;
  montant: number;
  declencheur?: string;
}

export interface AgriPlanOffre {
  id?: string;
  code: string;
  nom: string;
  description: string | null;
  prix_total: number;
  montant_mise_en_place: number;
  montant_accompagnement_periode: number;
  periodicite_accompagnement: string;
  nb_periodes_accompagnement: number;
  duree_mois: number;
  tranches: AgriPlanTranche[];
  actif: boolean;
}

export const AGRIPLAN_OFFRE_FALLBACK: AgriPlanOffre = {
  code: "agriplan",
  nom: "AgriPlan",
  description: "Offre unique AgriPlan",
  prix_total: 350_000,
  montant_mise_en_place: 230_000,
  montant_accompagnement_periode: 10_000,
  periodicite_accompagnement: "trimestriel",
  nb_periodes_accompagnement: 12,
  duree_mois: 36,
  tranches: [
    { numero: 1, libelle: "Acompte", montant: 50_000, declencheur: "À la commande" },
    { numero: 2, libelle: "Mise en œuvre", montant: 80_000, declencheur: "Après piquetage / avant mobilisation" },
    { numero: 3, libelle: "Paiement intermédiaire", montant: 50_000, declencheur: "Échéance suivante" },
    { numero: 4, libelle: "Solde de mise en place", montant: 50_000, declencheur: "Dernière échéance" },
  ],
  actif: true,
};

export const formatFCFA = (n?: number | null) =>
  `${Math.round(Number(n || 0)).toLocaleString("fr-FR")} FCFA`;

export interface AgriPlanTotaux {
  miseEnPlace: number;
  accompagnement: number;
  total: number;
}

/** Totaux de l'offre pour une superficie donnée (par défaut 1 ha) */
export function computeAgriPlanTotaux(offre: AgriPlanOffre, superficie = 1): AgriPlanTotaux {
  const s = Number(superficie) > 0 ? Number(superficie) : 1;
  const miseEnPlace =
    (offre.tranches?.length
      ? offre.tranches.reduce((acc, t) => acc + Number(t.montant || 0), 0)
      : Number(offre.montant_mise_en_place || 0)) * s;
  const accompagnement =
    Number(offre.montant_accompagnement_periode || 0) * Number(offre.nb_periodes_accompagnement || 0) * s;
  return { miseEnPlace, accompagnement, total: miseEnPlace + accompagnement };
}

export interface AgriPlanEcheancePlan {
  numero_echeance: number;
  type: "mise_en_place" | "accompagnement";
  libelle: string;
  declencheur: string | null;
  date_echeance: string;
  montant: number;
}

const iso = (d: Date) => d.toISOString().slice(0, 10);

function addMonths(date: Date, months: number): Date {
  const d = new Date(date.getTime());
  const day = d.getDate();
  d.setMonth(d.getMonth() + months);
  if (d.getDate() < day) d.setDate(0);
  return d;
}

const PERIODE_MOIS: Record<string, number> = {
  mensuel: 1,
  trimestriel: 3,
  semestriel: 6,
  annuel: 12,
};

/** Échéancier généré à la création d'une vente AgriPlan */
export function buildAgriPlanEcheancier(
  offre: AgriPlanOffre,
  dateDebut: Date | string = new Date(),
  superficie = 1,
): AgriPlanEcheancePlan[] {
  const start = typeof dateDebut === "string" ? new Date(dateDebut) : dateDebut;
  const s = Number(superficie) > 0 ? Number(superficie) : 1;
  const pas = PERIODE_MOIS[offre.periodicite_accompagnement] ?? 3;
  const rows: AgriPlanEcheancePlan[] = [];

  const tranches = offre.tranches?.length ? offre.tranches : AGRIPLAN_OFFRE_FALLBACK.tranches;
  tranches.forEach((t, i) => {
    rows.push({
      numero_echeance: i + 1,
      type: "mise_en_place",
      libelle: t.libelle,
      declencheur: t.declencheur || null,
      date_echeance: iso(addMonths(start, i)),
      montant: Number(t.montant || 0) * s,
    });
  });

  for (let i = 1; i <= Number(offre.nb_periodes_accompagnement || 0); i++) {
    rows.push({
      numero_echeance: tranches.length + i,
      type: "accompagnement",
      libelle: `Accompagnement ${i}`,
      declencheur: `${offre.periodicite_accompagnement} — période ${i}`,
      date_echeance: iso(addMonths(start, i * pas)),
      montant: Number(offre.montant_accompagnement_periode || 0) * s,
    });
  }

  return rows;
}

/** Étapes de progression du dossier AgriPlan (affichées aussi dans le portail) */
export const AGRIPLAN_ETAPES = [
  { code: "vente_enregistree", label: "Vente enregistrée" },
  { code: "dossier_valide", label: "Dossier validé" },
  { code: "plantation_enregistree", label: "Plantation enregistrée" },
  { code: "suivi_en_cours", label: "Suivi en cours" },
  { code: "cloture", label: "Clôturé" },
] as const;

export const AGRIPLAN_LEAD_STATUTS = [
  { code: "nouveau", label: "Nouveau" },
  { code: "en_discussion", label: "En discussion" },
  { code: "interesse", label: "Intéressé" },
  { code: "converti", label: "Converti" },
  { code: "perdu", label: "Perdu" },
] as const;

export const AGRIPLAN_VISITE_STATUTS = [
  { code: "planifiee", label: "Planifiée" },
  { code: "en_cours", label: "En cours" },
  { code: "realisee", label: "Réalisée" },
  { code: "annulee", label: "Annulée" },
] as const;

export const AGRIPLAN_TYPES_VISITE = [
  "inspection",
  "piquetage",
  "trouaison",
  "plantation",
  "suivi",
  "intervention",
  "evaluation",
] as const;

export const AGRIPLAN_TYPES_DOCUMENT = [
  "piece_identite",
  "contrat",
  "rapport_technique",
  "photo",
  "video",
  "autre",
] as const;

export function labelOf(list: readonly { code: string; label: string }[], code?: string | null) {
  return list.find((i) => i.code === code)?.label || code || "—";
}
