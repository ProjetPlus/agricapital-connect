import { forwardRef } from "react";
import { QRCodeCanvas } from "qrcode.react";
import { format } from "date-fns";
import { fr } from "date-fns/locale";
import logo from "@/assets/logo-agricapital-v2.png";
import { useSignedUrl } from "@/hooks/useSignedUrl";
import { CARTE_BUCKET } from "@/lib/photoCarte";
import { roleLabel } from "@/lib/roles";

export interface CarteData {
  id?: string;
  matricule: string;
  code_verification: string;
  nom_complet: string;
  poste?: string | null;
  departement?: string | null;
  role_code?: string | null;
  type_contrat?: string | null;
  photo_url?: string | null;
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

export const contratLabel = (v?: string | null) => CONTRATS.find((c) => c.v === v)?.l || "CDI";

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

/** Recto — format officiel 54 × 86 mm (portrait). */
export const CarteRecto = forwardRef<HTMLDivElement, { carte: CarteData }>(({ carte }, ref) => {
  const photo = useSignedUrl(CARTE_BUCKET, carte.photo_url);
  return (
    <div
      ref={ref}
      className="relative h-[86mm] w-[54mm] overflow-hidden rounded-[3mm] border border-border bg-card text-card-foreground shadow-sm"
    >
      <div className="flex flex-col items-center gap-1 bg-primary px-2 py-2 text-primary-foreground">
        <img src={logo} alt="AgriCapital" className="h-[8mm] object-contain" />
        <p className="text-[6pt] font-semibold uppercase tracking-[0.15em]">Carte professionnelle</p>
      </div>

      <div className="flex flex-col items-center px-3 pt-3">
        <div className="h-[26mm] w-[20mm] overflow-hidden rounded-[1.5mm] border-2 border-primary bg-muted">
          {photo ? (
            <img src={photo} alt={carte.nom_complet} className="h-full w-full object-cover" />
          ) : (
            <div className="flex h-full w-full items-center justify-center text-[14pt] font-bold text-muted-foreground">
              {initiales(carte.nom_complet)}
            </div>
          )}
        </div>

        <p className="mt-2 text-center text-[9pt] font-bold uppercase leading-tight">{carte.nom_complet}</p>
        <p className="text-center text-[7pt] text-primary">{carte.poste || roleLabel(carte.role_code)}</p>

        <div className="mt-2 w-full space-y-[0.6mm] text-[6.5pt] leading-tight">
          <p><span className="text-muted-foreground">Matricule : </span><b>{carte.matricule}</b></p>
          <p><span className="text-muted-foreground">Département : </span>{carte.departement || "—"}</p>
          <p><span className="text-muted-foreground">Contrat : </span>{contratLabel(carte.type_contrat)}</p>
          <p><span className="text-muted-foreground">Valide jusqu'au : </span>{fdate(carte.date_expiration)}</p>
        </div>
      </div>

      <div className="absolute bottom-0 left-0 right-0 flex items-center justify-between bg-primary/10 px-2 py-1">
        <span className="text-[5.5pt] uppercase tracking-wide text-muted-foreground">Investir la terre. Cultiver l'avenir.</span>
        <QRCodeCanvas value={verificationUrl(carte.code_verification)} size={38} includeMargin={false} />
      </div>
    </div>
  );
});
CarteRecto.displayName = "CarteRecto";

/** Verso — mentions légales, QR de vérification et signature. */
export const CarteVerso = forwardRef<HTMLDivElement, { carte: CarteData }>(({ carte }, ref) => (
  <div
    ref={ref}
    className="relative flex h-[86mm] w-[54mm] flex-col overflow-hidden rounded-[3mm] border border-border bg-card p-3 text-card-foreground shadow-sm"
  >
    <p className="text-center text-[6.5pt] font-semibold uppercase tracking-[0.12em] text-primary">
      AgriCapital Côte d'Ivoire
    </p>

    <div className="mt-2 space-y-[0.7mm] text-[6pt] leading-snug">
      <p><span className="text-muted-foreground">Délivrée le : </span>{fdate(carte.date_delivrance)}</p>
      <p><span className="text-muted-foreground">Expire le : </span>{fdate(carte.date_expiration)}</p>
      <p><span className="text-muted-foreground">Statut : </span>{carte.statut === "active" ? "Active" : carte.statut === "suspendue" ? "Suspendue" : "Révoquée"}</p>
      {carte.telephone && <p><span className="text-muted-foreground">Tél. : </span>{carte.telephone}</p>}
      {carte.email && <p className="truncate"><span className="text-muted-foreground">Email : </span>{carte.email}</p>}
    </div>

    <div className="mt-2 flex flex-col items-center">
      <QRCodeCanvas value={verificationUrl(carte.code_verification)} size={96} includeMargin={false} />
      <p className="mt-1 break-all text-center text-[5pt] text-muted-foreground">
        {verificationUrl(carte.code_verification)}
      </p>
      <p className="text-center text-[5.5pt] text-muted-foreground">Scannez pour vérifier l'authenticité</p>
    </div>

    <p className="mt-2 text-[5pt] leading-tight text-muted-foreground">
      Cette carte est strictement personnelle et demeure la propriété d'AgriCapital. Elle doit être présentée
      à toute réquisition et restituée en cas de fin de collaboration. Toute utilisation frauduleuse expose
      son porteur à des poursuites.
    </p>

    <div className="mt-auto flex items-end justify-between">
      <div className="text-[5.5pt] text-muted-foreground">
        <p className="border-t border-border pt-[0.5mm]">Le porteur</p>
      </div>
      <div className="text-[5.5pt] text-muted-foreground">
        <p className="border-t border-border pt-[0.5mm]">La Direction</p>
      </div>
    </div>
  </div>
));
CarteVerso.displayName = "CarteVerso";
