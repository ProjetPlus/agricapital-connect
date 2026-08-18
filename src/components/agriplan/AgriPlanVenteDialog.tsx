import { useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/useAuth";
import { useAgriPlanGeo } from "@/hooks/useAgriPlanGeo";
import { useAgriPlanOffre } from "@/hooks/useAgriPlanOffre";
import { buildAgriPlanEcheancier, computeAgriPlanTotaux, formatFCFA } from "@/lib/agriplan";
import { uploadAgriPlanFile } from "@/lib/agriplanFiles";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Separator } from "@/components/ui/separator";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

export interface AgriPlanLeadLite {
  id: string;
  nom_complet: string;
  telephone: string;
  whatsapp: string | null;
  region_id: string | null;
  sous_prefecture_id: string | null;
  localite: string | null;
}

interface Props {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  onSaved: () => void;
  lead?: AgriPlanLeadLite | null;
}

const empty = {
  nom_complet: "",
  telephone: "",
  whatsapp: "",
  email: "",
  region_id: "",
  sous_prefecture_id: "",
  localite: "",
  champ_region_id: "",
  champ_sous_prefecture_id: "",
  champ_localite: "",
  superficie_ha: "1",
  contact_nom: "",
  contact_telephone: "",
  type_piece: "CNI",
  numero_piece: "",
  notes: "",
};

const TYPES_PIECE = ["CNI", "Passeport", "Attestation d'identité", "Carte consulaire", "Permis de conduire"];

/** Nouvelle Vente AgriPlan : crée automatiquement le Client AgriPlan, la vente et l'échéancier. */
export default function AgriPlanVenteDialog({ open, onOpenChange, onSaved, lead }: Props) {
  const { user, profile } = useAuth();
  const { regions, spByRegion } = useAgriPlanGeo();
  const { offre } = useAgriPlanOffre();
  const [form, setForm] = useState(empty);
  const [pieceFile, setPieceFile] = useState<File | null>(null);
  const [contratFile, setContratFile] = useState<File | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!open) return;
    setForm(
      lead
        ? {
            ...empty,
            nom_complet: lead.nom_complet,
            telephone: lead.telephone,
            whatsapp: lead.whatsapp || "",
            region_id: lead.region_id || "",
            sous_prefecture_id: lead.sous_prefecture_id || "",
            localite: lead.localite || "",
            champ_region_id: lead.region_id || "",
            champ_sous_prefecture_id: lead.sous_prefecture_id || "",
            champ_localite: lead.localite || "",
          }
        : empty,
    );
    setPieceFile(null);
    setContratFile(null);
  }, [open, lead]);

  const set = (k: keyof typeof empty, v: string) => setForm((f) => ({ ...f, [k]: v }));
  const superficie = Number(form.superficie_ha) > 0 ? Number(form.superficie_ha) : 1;
  const totaux = computeAgriPlanTotaux(offre, superficie);

  const submit = async () => {
    if (!form.nom_complet.trim() || !form.telephone.trim()) {
      toast.error("Nom et téléphone sont obligatoires");
      return;
    }
    setSaving(true);
    try {
      // 1. Client AgriPlan
      const { data: client, error: eClient } = await supabase
        .from("agriplan_clients")
        .insert({
          lead_id: lead?.id || null,
          nom_complet: form.nom_complet.trim(),
          telephone: form.telephone.trim(),
          whatsapp: form.whatsapp.trim() || null,
          email: form.email.trim() || null,
          region_id: form.region_id || null,
          sous_prefecture_id: form.sous_prefecture_id || null,
          localite: form.localite.trim() || null,
          contact_nom: form.contact_nom.trim() || null,
          contact_telephone: form.contact_telephone.trim() || null,
          type_piece: form.type_piece || null,
          numero_piece: form.numero_piece.trim() || null,
          notes: form.notes.trim() || null,
          statut_dossier: "vente_enregistree",
          statut: "actif",
          created_by: user?.id || null,
        })
        .select("id, numero_client")
        .single();
      if (eClient || !client) throw new Error(eClient?.message || "Création du client impossible");

      // 2. Fichiers (pièce d'identité + contrat)
      let pieceUrl: string | null = null;
      let contratUrl: string | null = null;
      if (pieceFile) {
        const up = await uploadAgriPlanFile(client.id, "piece_identite", pieceFile);
        pieceUrl = up.path;
      }
      if (contratFile) {
        const up = await uploadAgriPlanFile(client.id, "contrat", contratFile);
        contratUrl = up.path;
      }
      if (pieceUrl || contratUrl) {
        await supabase
          .from("agriplan_clients")
          .update({ piece_identite_url: pieceUrl, contrat_url: contratUrl })
          .eq("id", client.id);
        const docs = [
          pieceUrl && { type_document: "piece_identite", nom: pieceFile!.name, fichier_url: pieceUrl },
          contratUrl && { type_document: "contrat", nom: contratFile!.name, fichier_url: contratUrl },
        ].filter(Boolean) as Array<{ type_document: string; nom: string; fichier_url: string }>;
        if (docs.length) {
          await supabase.from("agriplan_documents").insert(
            docs.map((d) => ({ ...d, client_id: client.id, uploaded_by: user?.id || null })),
          );
        }
      }

      // 3. Vente
      const { data: vente, error: eVente } = await supabase
        .from("agriplan_ventes")
        .insert({
          client_id: client.id,
          offre_id: offre.id || null,
          superficie_ha: superficie,
          champ_region_id: form.champ_region_id || null,
          champ_sous_prefecture_id: form.champ_sous_prefecture_id || null,
          champ_localite: form.champ_localite.trim() || null,
          montant_total: totaux.total,
          montant_mise_en_place: totaux.miseEnPlace,
          montant_accompagnement: totaux.accompagnement,
          solde: totaux.total,
          statut: "en_cours",
          contrat_url: contratUrl,
          created_by: user?.id || null,
        })
        .select("id, reference")
        .single();
      if (eVente || !vente) throw new Error(eVente?.message || "Création de la vente impossible");

      // 4. Échéancier
      const plan = buildAgriPlanEcheancier(offre, new Date(), superficie);
      await supabase.from("agriplan_echeances").insert(
        plan.map((e) => ({
          vente_id: vente.id,
          client_id: client.id,
          numero_echeance: e.numero_echeance,
          type: e.type,
          libelle: e.libelle,
          declencheur: e.declencheur,
          date_echeance: e.date_echeance,
          montant: e.montant,
          statut: "a_venir",
        })),
      );

      // 5. Plantation 1 (nomenclature automatique)
      await supabase.from("agriplan_plantations").insert({
        client_id: client.id,
        vente_id: vente.id,
        region_id: form.champ_region_id || null,
        sous_prefecture_id: form.champ_sous_prefecture_id || null,
        localite: form.champ_localite.trim() || null,
        superficie_ha: superficie,
        statut: "en_preparation",
        created_by: user?.id || null,
      });

      // 6. Historique + conversion du lead
      await supabase.from("agriplan_evenements").insert({
        client_id: client.id,
        lead_id: lead?.id || null,
        entity_type: "vente",
        entity_id: vente.id,
        action: "vente_creee",
        details: `Vente ${vente.reference} — ${formatFCFA(totaux.total)} — ${superficie} ha`,
        acteur_id: user?.id || null,
        visible_client: true,
      });
      if (lead?.id) {
        await supabase
          .from("agriplan_leads")
          .update({ statut: "converti", converti_client_id: client.id, converti_at: new Date().toISOString() })
          .eq("id", lead.id);
      }

      toast.success(`Client AgriPlan ${client.numero_client} créé`);
      onOpenChange(false);
      onSaved();
    } catch (err) {
      toast.error((err as Error).message);
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[90vh] max-w-2xl overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Nouvelle Vente AgriPlan</DialogTitle>
          <DialogDescription>
            Crée automatiquement le dossier Client AgriPlan, la vente, l'échéancier et la première plantation.
            {profile?.nom_complet ? ` Commercial : ${profile.nom_complet}.` : ""}
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          <p className="text-sm font-semibold">Informations client</p>
          <div className="grid gap-3 sm:grid-cols-2">
            <div className="sm:col-span-2">
              <Label>Nom et prénom *</Label>
              <Input value={form.nom_complet} onChange={(e) => set("nom_complet", e.target.value)} />
            </div>
            <div><Label>Téléphone *</Label><Input value={form.telephone} onChange={(e) => set("telephone", e.target.value)} /></div>
            <div><Label>WhatsApp</Label><Input value={form.whatsapp} onChange={(e) => set("whatsapp", e.target.value)} /></div>
            <div><Label>Email (accès portail)</Label><Input value={form.email} onChange={(e) => set("email", e.target.value)} /></div>
            <div>
              <Label>Région de résidence</Label>
              <Select value={form.region_id} onValueChange={(v) => { set("region_id", v); set("sous_prefecture_id", ""); }}>
                <SelectTrigger><SelectValue placeholder="Sélectionner" /></SelectTrigger>
                <SelectContent className="max-h-72">{regions.map((r) => <SelectItem key={r.id} value={r.id}>{r.nom}</SelectItem>)}</SelectContent>
              </Select>
            </div>
            <div>
              <Label>Sous-préfecture</Label>
              <Select value={form.sous_prefecture_id} onValueChange={(v) => set("sous_prefecture_id", v)}>
                <SelectTrigger><SelectValue placeholder="Sélectionner" /></SelectTrigger>
                <SelectContent className="max-h-72">{spByRegion(form.region_id).map((s) => <SelectItem key={s.id} value={s.id}>{s.nom}</SelectItem>)}</SelectContent>
              </Select>
            </div>
            <div><Label>Localité / lieu de résidence</Label><Input value={form.localite} onChange={(e) => set("localite", e.target.value)} /></div>
          </div>

          <Separator />
          <p className="text-sm font-semibold">Localisation du champ</p>
          <div className="grid gap-3 sm:grid-cols-2">
            <div>
              <Label>Région</Label>
              <Select value={form.champ_region_id} onValueChange={(v) => { set("champ_region_id", v); set("champ_sous_prefecture_id", ""); }}>
                <SelectTrigger><SelectValue placeholder="Sélectionner" /></SelectTrigger>
                <SelectContent className="max-h-72">{regions.map((r) => <SelectItem key={r.id} value={r.id}>{r.nom}</SelectItem>)}</SelectContent>
              </Select>
            </div>
            <div>
              <Label>Sous-préfecture</Label>
              <Select value={form.champ_sous_prefecture_id} onValueChange={(v) => set("champ_sous_prefecture_id", v)}>
                <SelectTrigger><SelectValue placeholder="Sélectionner" /></SelectTrigger>
                <SelectContent className="max-h-72">{spByRegion(form.champ_region_id).map((s) => <SelectItem key={s.id} value={s.id}>{s.nom}</SelectItem>)}</SelectContent>
              </Select>
            </div>
            <div><Label>Localité / village</Label><Input value={form.champ_localite} onChange={(e) => set("champ_localite", e.target.value)} /></div>
            <div><Label>Superficie (ha)</Label><Input type="number" min="0.1" step="0.1" value={form.superficie_ha} onChange={(e) => set("superficie_ha", e.target.value)} /></div>
          </div>

          <Separator />
          <p className="text-sm font-semibold">Personne à contacter</p>
          <div className="grid gap-3 sm:grid-cols-2">
            <div><Label>Nom et prénom</Label><Input value={form.contact_nom} onChange={(e) => set("contact_nom", e.target.value)} /></div>
            <div><Label>Téléphone</Label><Input value={form.contact_telephone} onChange={(e) => set("contact_telephone", e.target.value)} /></div>
          </div>

          <Separator />
          <p className="text-sm font-semibold">Identification & contrat</p>
          <div className="grid gap-3 sm:grid-cols-2">
            <div>
              <Label>Type de pièce</Label>
              <Select value={form.type_piece} onValueChange={(v) => set("type_piece", v)}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>{TYPES_PIECE.map((t) => <SelectItem key={t} value={t}>{t}</SelectItem>)}</SelectContent>
              </Select>
            </div>
            <div><Label>Numéro de pièce / passeport</Label><Input value={form.numero_piece} onChange={(e) => set("numero_piece", e.target.value)} /></div>
            <div>
              <Label>Copie de la pièce d'identité</Label>
              <Input type="file" accept="image/*,application/pdf" onChange={(e) => setPieceFile(e.target.files?.[0] || null)} />
            </div>
            <div>
              <Label>Contrat client AgriPlan</Label>
              <Input type="file" accept="image/*,application/pdf" onChange={(e) => setContratFile(e.target.files?.[0] || null)} />
            </div>
            <div className="sm:col-span-2">
              <Label>Notes</Label>
              <Textarea rows={2} value={form.notes} onChange={(e) => set("notes", e.target.value)} />
            </div>
          </div>

          <div className="rounded-md border bg-muted/40 p-3 text-sm">
            <div className="flex justify-between"><span>Mise en place</span><span className="font-medium">{formatFCFA(totaux.miseEnPlace)}</span></div>
            <div className="flex justify-between"><span>Accompagnement ({offre.nb_periodes_accompagnement} × {formatFCFA(offre.montant_accompagnement_periode)})</span><span className="font-medium">{formatFCFA(totaux.accompagnement)}</span></div>
            <div className="mt-1 flex justify-between border-t pt-1 font-semibold"><span>Total de la vente</span><span>{formatFCFA(totaux.total)}</span></div>
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>Annuler</Button>
          <Button onClick={submit} disabled={saving}>{saving ? "Création..." : "Valider la vente"}</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
