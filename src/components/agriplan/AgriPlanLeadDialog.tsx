import { useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/useAuth";
import { useAgriPlanGeo } from "@/hooks/useAgriPlanGeo";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

interface Props {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  onSaved: () => void;
}

const empty = {
  nom_complet: "",
  telephone: "",
  whatsapp: "",
  region_id: "",
  sous_prefecture_id: "",
  localite: "",
  localisation: "",
  commentaire: "",
};

/** Formulaire Lead AgriPlan : uniquement des données commerciales de prospection. */
export default function AgriPlanLeadDialog({ open, onOpenChange, onSaved }: Props) {
  const { user } = useAuth();
  const { regions, spByRegion } = useAgriPlanGeo();
  const [form, setForm] = useState(empty);
  const [saving, setSaving] = useState(false);

  const set = (k: keyof typeof empty, v: string) => setForm((f) => ({ ...f, [k]: v }));

  const submit = async () => {
    if (!form.nom_complet.trim() || !form.telephone.trim()) {
      toast.error("Nom et téléphone sont obligatoires");
      return;
    }
    setSaving(true);
    const { error } = await supabase.from("agriplan_leads").insert({
      nom_complet: form.nom_complet.trim(),
      telephone: form.telephone.trim(),
      whatsapp: form.whatsapp.trim() || null,
      region_id: form.region_id || null,
      sous_prefecture_id: form.sous_prefecture_id || null,
      localite: form.localite.trim() || null,
      localisation: form.localisation.trim() || null,
      commentaire: form.commentaire.trim() || null,
      statut: "nouveau",
      assigned_to: user?.id || null,
      created_by: user?.id || null,
    });
    setSaving(false);
    if (error) {
      toast.error("Enregistrement impossible : " + error.message);
      return;
    }
    toast.success("Lead AgriPlan enregistré");
    setForm(empty);
    onOpenChange(false);
    onSaved();
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle>Nouveau Lead AgriPlan</DialogTitle>
          <DialogDescription>Prospection commerciale AgriPlan uniquement.</DialogDescription>
        </DialogHeader>

        <div className="space-y-3">
          <div>
            <Label>Nom et prénom *</Label>
            <Input value={form.nom_complet} onChange={(e) => set("nom_complet", e.target.value)} />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <Label>Téléphone *</Label>
              <Input value={form.telephone} onChange={(e) => set("telephone", e.target.value)} />
            </div>
            <div>
              <Label>WhatsApp</Label>
              <Input value={form.whatsapp} onChange={(e) => set("whatsapp", e.target.value)} />
            </div>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <Label>Région</Label>
              <Select value={form.region_id} onValueChange={(v) => { set("region_id", v); set("sous_prefecture_id", ""); }}>
                <SelectTrigger><SelectValue placeholder="Sélectionner" /></SelectTrigger>
                <SelectContent className="max-h-72">
                  {regions.map((r) => <SelectItem key={r.id} value={r.id}>{r.nom}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
            <div>
              <Label>Sous-préfecture</Label>
              <Select value={form.sous_prefecture_id} onValueChange={(v) => set("sous_prefecture_id", v)}>
                <SelectTrigger><SelectValue placeholder="Sélectionner" /></SelectTrigger>
                <SelectContent className="max-h-72">
                  {spByRegion(form.region_id).map((s) => <SelectItem key={s.id} value={s.id}>{s.nom}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <Label>Localité / lieu de résidence</Label>
              <Input value={form.localite} onChange={(e) => set("localite", e.target.value)} />
            </div>
            <div>
              <Label>Localisation</Label>
              <Input value={form.localisation} onChange={(e) => set("localisation", e.target.value)} placeholder="Repère, quartier, GPS..." />
            </div>
          </div>
          <div>
            <Label>Commentaire</Label>
            <Textarea rows={2} value={form.commentaire} onChange={(e) => set("commentaire", e.target.value)} />
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>Annuler</Button>
          <Button onClick={submit} disabled={saving}>{saving ? "Enregistrement..." : "Enregistrer le lead"}</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
