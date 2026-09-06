import { forwardRef } from "react";
import { QRCodeCanvas } from "qrcode.react";
import { format } from "date-fns";
import { fr } from "date-fns/locale";
import logo from "@/assets/logo-agricapital-v2.png";
import symbole from "@/assets/symbole-agricapital.png";
import signature from "@/assets/signature-direction.png";
import cachet from "@/assets/cachet-agricapital.png";
import { useSignedUrl } from "@/hooks/useSignedUrl";
import { CARTE_BUCKET } from "@/lib/photoCarte";
import { roleLabel } from "@/lib/roles";

/**
 * Carte professionnelle AgriCapital — reproduction fidèle des maquettes
 * officielles recto / verso (champs, textes et mise en page identiques).
 * Format d'impression : 54 × 86 mm.
 */

const VERT = "#0B4A2E";
const VERT_CLAIR = "#137A45";
const ORANGE = "#E97A11";
const GRIS = "#4A4A4A";

export interface CarteData {
  id?: string;
  matricule: string;
  code_verification: string;
  nom_complet: string;
  poste?: string | null;
  departement?: string | null;
  role_code?: string | null;
  type_contrat?: string | null;
  statut_agent?: string | null;
  mission?: string | null;
  zone_intervention?: string | null;
  photo_url?: string | null;
  photo_bucket?: string | null;
  date_delivrance?: string | null;
  date_expiration?: string | null;
  statut?: string | null;
  telephone?: string | null;
  email?: string | null;
}

export const CONTRATS = [
  { v: "cdi", l: "CDI" },
  { v: "cdd", l: "CDD" },
  { v: "prestataire", l: "Prestataire" },
  { v: "stage", l: "Stage" },
];

export const STATUTS_AGENT = [
  { v: "employe", l: "EMPLOYÉ" },
  { v: "cadre", l: "CADRE" },
  { v: "prestataire", l: "PRESTATAIRE" },
  { v: "stagiaire", l: "STAGIAIRE" },
  { v: "partenaire", l: "PARTENAIRE" },
];

export const contratLabel = (v?: string | null) => CONTRATS.find((c) => c.v === v)?.l || "CDI";
export const statutAgentLabel = (v?: string | null) =>
  STATUTS_AGENT.find((s) => s.v === v)?.l || "EMPLOYÉ";

export const verificationUrl = (code: string) =>
  `${typeof window !== "undefined" ? window.location.origin : "https://app.agricapital.ci"}/verifier-carte/${code}`;

const fdate = (d?: string | null) => (d ? format(new Date(d), "dd/MM/yyyy", { locale: fr }) : "—");

const initiales = (nom: string) =>
  nom
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((n) => n[0]?.toUpperCase())
    .join("");

/** Décors d'angle (courbes vertes et orange) identiques aux maquettes. */
const DecorHaut = () => (
  <>
    <svg className="pointer-events-none absolute left-0 top-0 h-[16mm] w-[16mm]" viewBox="0 0 100 100" aria-hidden>
      <path d="M0 0 H62 C24 6 6 26 0 64 Z" fill={VERT} />
    </svg>
    <svg className="pointer-events-none absolute right-0 top-0 h-[14mm] w-[22mm]" viewBox="0 0 140 100" aria-hidden>
      <path d="M140 0 V54 C104 40 62 30 12 28 C64 16 108 8 140 0 Z" fill={ORANGE} />
    </svg>
  </>
);

const DecorBas = () => (
  <svg className="pointer-events-none absolute bottom-0 left-0 h-[13mm] w-full" viewBox="0 0 300 60" preserveAspectRatio="none" aria-hidden>
    <path d="M0 34 C90 6 210 14 300 2 V60 H0 Z" fill={ORANGE} />
    <path d="M0 44 C90 20 210 26 300 14 V60 H0 Z" fill={VERT} />
  </svg>
);

const Ligne = ({ label, valeur }: { label: string; valeur: string }) => (
  <div className="flex items-center gap-[1.2mm]">
    <span
      className="flex h-[4.4mm] w-[4.4mm] shrink-0 items-center justify-center rounded-full"
      style={{ backgroundColor: VERT }}
    >
      <img src={symbole} alt="" className="h-[2.6mm] w-[2.6mm] object-contain brightness-0 invert" />
    </span>
    <span className="h-[3.6mm] w-[0.5mm] shrink-0" style={{ backgroundColor: ORANGE }} />
    <span className="text-[5pt] font-bold uppercase leading-none" style={{ color: VERT }}>
      {label}
    </span>
    <span className="text-[5pt]" style={{ color: GRIS }}>:</span>
    <span className="min-w-0 flex-1 truncate border-b text-[5.5pt] leading-none" style={{ color: GRIS, borderColor: "#D6D6D6" }}>
      {valeur}
    </span>
  </div>
);

/** Recto — maquette officielle CARTE_PRO_AGRICAPITAL_RECTO. */
export const CarteRecto = forwardRef<HTMLDivElement, { carte: CarteData }>(({ carte }, ref) => {
  const photo = useSignedUrl(carte.photo_bucket || CARTE_BUCKET, carte.photo_url);
  return (
    <div
      ref={ref}
      className="relative h-[86mm] w-[54mm] shrink-0 overflow-hidden rounded-[3mm] bg-white"
      style={{ border: `0.4mm solid ${VERT}` }}
    >
      <DecorHaut />
      <DecorBas />

      <div className="relative flex h-full flex-col px-[3.5mm] pb-[13mm] pt-[3mm]">
        <img src={logo} alt="AgriCapital — Investir la terre. Cultiver l'avenir." className="mx-auto h-[11mm] object-contain" />

        <div className="mt-[2.5mm] flex items-start gap-[2.5mm]">
          <div
            className="h-[24mm] w-[17mm] shrink-0 overflow-hidden rounded-[1.5mm] bg-[#EDEDED]"
            style={{ border: `0.4mm solid ${VERT}` }}
          >
            {photo ? (
              <img src={photo} alt={carte.nom_complet} className="h-full w-full object-cover" />
            ) : (
              <div className="flex h-full w-full items-center justify-center text-[12pt] font-bold" style={{ color: "#8A8A8A" }}>
                {initiales(carte.nom_complet)}
              </div>
            )}
          </div>

          <div className="min-w-0 flex-1">
            <p className="break-words text-[9pt] font-extrabold uppercase leading-[1.05]" style={{ color: VERT }}>
              {carte.nom_complet}
            </p>
            <div className="my-[1mm] flex items-center gap-[1mm]">
              <span className="h-[0.3mm] flex-1" style={{ backgroundColor: "#C9C9C9" }} />
              <img src={symbole} alt="" className="h-[2.6mm] object-contain" />
              <span className="h-[0.3mm] flex-1" style={{ backgroundColor: "#C9C9C9" }} />
            </div>
            <p className="text-[7pt] font-bold uppercase leading-none" style={{ color: GRIS }}>Fonction</p>
            <p className="truncate text-[6pt] leading-tight" style={{ color: GRIS }}>
              {carte.poste || roleLabel(carte.role_code)}
            </p>
            <div className="mt-[1.5mm] flex items-center gap-[1.2mm]">
              <span
                className="rounded-[1mm] px-[1.5mm] py-[0.6mm] text-[5.5pt] font-bold uppercase text-white"
                style={{ backgroundColor: VERT }}
              >
                Statut
              </span>
              <span className="h-[3mm] w-[0.3mm]" style={{ backgroundColor: "#C9C9C9" }} />
              <span className="text-[6pt] font-bold uppercase" style={{ color: VERT_CLAIR }}>
                {statutAgentLabel(carte.statut_agent)}
              </span>
            </div>
          </div>
        </div>

        <div className="mt-[2.5mm] space-y-[1.4mm]">
          <Ligne label="Mission" valeur={carte.mission || "…………………………………"} />
          <Ligne label="Zone d'intervention" valeur={carte.zone_intervention || "…………………………"} />
          <Ligne
            label="Période de validité"
            valeur={`Du ${fdate(carte.date_delivrance)} au ${fdate(carte.date_expiration)}`}
          />
          <Ligne label="Identifiant officiel" valeur={carte.matricule} />
        </div>

        <div className="mt-auto flex items-end gap-[2mm]">
          <div className="rounded-[1mm] bg-white p-[0.6mm]" style={{ border: `0.25mm solid #D6D6D6` }}>
            <QRCodeCanvas value={verificationUrl(carte.code_verification)} size={54} includeMargin={false} level="M" />
          </div>
          <div className="min-w-0 flex-1">
            <p className="flex items-center gap-[1mm] text-[5.5pt] font-bold uppercase" style={{ color: VERT }}>
              <svg viewBox="0 0 24 24" className="h-[3.2mm] w-[3.2mm]" fill={VERT} aria-hidden>
                <path d="M12 2 4 5v6c0 5 3.4 9.3 8 11 4.6-1.7 8-6 8-11V5l-8-3Zm-1 14-3.5-3.5 1.4-1.4L11 13.2l4.1-4.1 1.4 1.4L11 16Z" />
              </svg>
              Vérification
            </p>
            <p className="text-[4.8pt] leading-[1.3]" style={{ color: GRIS }}>
              Scannez ce QR code<br />pour vérifier l'authenticité<br />et la validité de ce badge.
            </p>
          </div>
          <div className="w-[19mm] shrink-0 text-center">
            <p className="text-[5pt] font-bold uppercase" style={{ color: VERT }}>Signature direction</p>
            <div className="relative h-[7mm]">
              <img src={signature} alt="Signature de la direction" className="absolute inset-0 mx-auto h-[7mm] object-contain" />
              <img src={cachet} alt="" className="absolute inset-0 mx-auto h-[7mm] object-contain opacity-70" />
            </div>
            <span className="block h-[0.3mm] w-full" style={{ backgroundColor: "#9A9A9A" }} />
          </div>
        </div>
      </div>
    </div>
  );
});
CarteRecto.displayName = "CarteRecto";

/** Verso — maquette officielle CARTE_PRO_AGRICAPITAL_VERSO. */
export const CarteVerso = forwardRef<HTMLDivElement, { carte: CarteData }>(({ carte }, ref) => (
  <div
    ref={ref}
    className="relative h-[86mm] w-[54mm] shrink-0 overflow-hidden rounded-[3mm] bg-white"
    style={{ border: `0.4mm solid ${VERT}` }}
  >
    <DecorBas />

    <div className="relative flex h-full flex-col px-[4mm] pb-[13mm] pt-[3.5mm]">
      <img src={logo} alt="AgriCapital — Investir la terre. Cultiver l'avenir." className="mx-auto h-[12mm] object-contain" />
      <span className="mx-auto mt-[1.5mm] h-[0.3mm] w-[12mm]" style={{ backgroundColor: VERT }} />

      <p className="mt-[2mm] text-center text-[5.4pt] leading-[1.5]" style={{ color: "#333" }}>
        Cette carte est une pièce d'identification professionnelle délivrée par AgriCapital SARL.
        Elle atteste de l'appartenance ou de la collaboration de son titulaire avec l'entreprise
        dans le cadre de ses activités professionnelles.
      </p>

      <div className="mt-[2.5mm] rounded-[2mm] p-[2mm]" style={{ border: `0.3mm solid ${VERT}` }}>
        <div className="flex items-start gap-[2mm]">
          <svg viewBox="0 0 24 24" className="h-[7mm] w-[7mm] shrink-0" fill={VERT} aria-hidden>
            <path d="M12 2 4 5v6c0 5 3.4 9.3 8 11 4.6-1.7 8-6 8-11V5l-8-3Zm0 7a2 2 0 0 1 2 2v1h-4v-1a2 2 0 0 1 2-2Zm-3 4h6v4H9v-4Z" />
          </svg>
          <div className="min-w-0">
            <p className="text-[5.6pt] font-bold uppercase leading-tight" style={{ color: VERT }}>
              Carte personnelle – non transférable
            </p>
            <span className="my-[1mm] block h-[0.3mm] w-full" style={{ backgroundColor: ORANGE }} />
            <p className="text-[5pt] leading-[1.45]" style={{ color: "#333" }}>
              Toute perte, détérioration ou utilisation frauduleuse doit être signalée à AgriCapital SARL.
              Cette carte doit être restituée à l'entreprise à la fin de la collaboration ou sur demande.
            </p>
          </div>
        </div>
      </div>

      <div className="mt-[2.5mm] flex items-center gap-[2.5mm]">
        <div className="rounded-[1mm] bg-white p-[0.8mm]" style={{ border: `0.3mm solid #D6D6D6` }}>
          <QRCodeCanvas value={verificationUrl(carte.code_verification)} size={58} includeMargin={false} level="M" />
        </div>
        <div className="min-w-0 flex-1">
          <p className="flex items-center gap-[1.2mm] text-[5.6pt] font-bold uppercase" style={{ color: VERT }}>
            <svg viewBox="0 0 24 24" className="h-[3.6mm] w-[3.6mm]" fill={VERT} aria-hidden>
              <path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm-1 14.4-4-4 1.4-1.4 2.6 2.6 5.6-5.6L18 9.4l-7 7Z" />
            </svg>
            Vérification du badge
          </p>
          <p className="text-[5pt] leading-[1.4]" style={{ color: "#333" }}>
            Scannez ce QR code pour vérifier l'authenticité et la validité de ce badge.
          </p>
        </div>
      </div>

      <div className="my-[2mm] flex items-center gap-[1mm]">
        <span className="h-[0.3mm] flex-1" style={{ backgroundColor: "#C9C9C9" }} />
        <img src={symbole} alt="" className="h-[3mm] object-contain" />
        <span className="h-[0.3mm] flex-1" style={{ backgroundColor: "#C9C9C9" }} />
      </div>

      <div className="flex items-start gap-[2mm]">
        <div className="min-w-0 flex-1">
          <p className="text-[6pt] font-extrabold uppercase" style={{ color: VERT }}>AgriCapital SARL</p>
          <p className="text-[4.8pt] leading-[1.4]" style={{ color: "#333" }}>
            Société à Responsabilité Limitée<br />
            RCCM : CI-DAL-01-2025-B12-00035<br />
            Daloa-Gonaté, Côte d'Ivoire
          </p>
        </div>
        <div className="min-w-0 flex-1 space-y-[0.7mm]">
          {[
            { d: "M6.6 10.8a15 15 0 0 0 6.6 6.6l2.2-2.2 4.6 1v3.4A2 2 0 0 1 18 21.6 18 18 0 0 1 2.4 6 2 2 0 0 1 4.4 4h3.4l1 4.6-2.2 2.2Z", t: carte.telephone || "+225 07 50 56 60 87" },
            { d: "M2 5h20v14H2V5Zm10 8L3.5 6.6 12 12l8.5-5.4L12 13Z", t: "contact@agricapital.ci" },
            { d: "M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm0 2c1.6 2 2.4 4 2.4 6s-.8 4-2.4 6c-1.6-2-2.4-4-2.4-6s.8-4 2.4-6ZM4.3 9h3.3a16 16 0 0 0 0 6H4.3a8 8 0 0 1 0-6Zm12.1 0h3.3a8 8 0 0 1 0 6h-3.3a16 16 0 0 0 0-6Z", t: "www.agricapital.ci" },
            { d: "M12 2a7 7 0 0 0-7 7c0 5.2 7 13 7 13s7-7.8 7-13a7 7 0 0 0-7-7Zm0 9.5A2.5 2.5 0 1 1 12 6.5a2.5 2.5 0 0 1 0 5Z", t: "Cocody, Abidjan – Côte d'Ivoire" },
          ].map((c) => (
            <p key={c.t} className="flex items-center gap-[1mm] text-[4.6pt] leading-tight" style={{ color: "#333" }}>
              <span className="flex h-[3.2mm] w-[3.2mm] shrink-0 items-center justify-center rounded-full" style={{ backgroundColor: VERT }}>
                <svg viewBox="0 0 24 24" className="h-[2.1mm] w-[2.1mm]" fill="#fff" aria-hidden><path d={c.d} /></svg>
              </span>
              <span className="truncate">{c.t}</span>
            </p>
          ))}
        </div>
      </div>
    </div>
  </div>
));
CarteVerso.displayName = "CarteVerso";
