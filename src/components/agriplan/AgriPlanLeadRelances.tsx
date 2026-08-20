import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/useAuth";
import { AGRIPLAN_LEAD_STATUTS, labelOf } from "@/lib/agriplan";
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Separator } from "@/components/ui/separator";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { PhoneCall, Plus } from "lucide-react";
import { toast } from "sonner";
import { format } from "date-fns";
import { fr } from "date-fns/locale";

const CANAUX = [
  { v: "appel", l: "Appel téléphonique" },
  { v: "whatsapp", l: "WhatsApp" },
  { v: "sms", l: "SMS" },
  { v: "visite", l: "Visite physique" },
  { v: "email", l: "Email" },
];

const RESULTATS = [
  { v: "interesse", l: "Intéressé" },
  { v: "a_rappeler", l: "À rappeler" },
  { v: "injoignable", l: "Injoignable" },
  { v: "reflexion", l: "En réflexion" },
  { v: "rdv_fixe", l: "Rendez-vous fixé" },
  { v: "non_interesse", l: "Non intéressé" },
];

type Row = Record<string, any>;

interface Props {
  lead: Row | null;
  onOpenChange: (v: boolean) => void;
  onChanged: () => void;
}

export default function AgriPlanLeadRelances({ lead, onOpenChange, onChanged }: Props) {
  const { user } = useAuth();
  const [relances, setRelances] = useState<Row[]>([]);
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ canal: "appel", resultat: "interesse", commentaire: "", prochaine_relance: "" });
  const [statut, setStatut] = useState<string>("");

  const load = useCallback(async () => {
    if (!lead?.id) return;
    const { data } = await (supabase as any)
      .from("agriplan_lead_relances")
      .select("*")
      .eq("lead_id", lead.id)
      .order("date_relance", { ascending: false });
    setRelances((data || []) as Row[]);
    setStatut(lead.statut || "nouveau");
  }, [lead]);

  useEffect(() => { load(); }, [load]);

  const enregistrer = async () => {
    if (!lead?.id) return;
    const { error } = await (supabase as any).from("agriplan_lead_relances").insert({
      lead_id: lead.id,
      commercial_id: user?.id || null,
      canal: form.canal,
      resultat: form.resultat,
      commentaire: form.commentaire || null,
      prochaine_relance: form.prochaine_relance || null,
    });
    if (error) { toast.error(error.message); return; }
    toast.success("Relance enregistrée");
    setOpen(false);
    setForm({ canal: "appel", resultat: "interesse", commentaire: "", prochaine_relance: "" });
    load();
    onChanged();
  };

  const majStatut = async (v: string) => {
    if (!lead?.id) return;
    setStatut(v);
    const { error } = await supabase.from("agriplan_leads").update({ statut: v }).eq("id", lead.id);
    if (error) { toast.error(error.message); return; }
    toast.success("Statut du prospect mis à jour");
    onChanged();
  };

  return (
    <Sheet open={!!lead} onOpenChange={onOpenChange}>
      <SheetContent side="right" className="w-full overflow-y-auto sm:max-w-xl">
        <SheetHeader>
          <SheetTitle className="flex items-center gap-2">
            {lead?.nom_complet}
            <Badge variant="outline">{labelOf(AGRIPLAN_LEAD_STATUTS as never, lead?.statut)}</Badge>
          </SheetTitle>
          <SheetDescription>
            {lead?.telephone}{lead?.whatsapp ? ` / ${lead.whatsapp}` : ""} — {lead?.localite || "localité non renseignée"}
          </SheetDescription>
        </SheetHeader>

        <div className="mt-4 space-y-4">
          <div className="grid gap-3 sm:grid-cols-2">
            <div>
              <Label>Statut du prospect</Label>
              <Select value={statut} onValueChange={majStatut}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {AGRIPLAN_LEAD_STATUTS.map((s) => <SelectItem key={s.code} value={s.code}>{s.label}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
            <div className="flex items-end">
              <Button className="w-full" onClick={() => setOpen(true)}>
                <Plus className="mr-1 h-4 w-4" />Nouvelle relance
              </Button>
            </div>
          </div>

          <div className="grid gap-2 rounded-md border p-3 text-sm sm:grid-cols-2">
            <div><span className="text-muted-foreground">Relances : </span>{lead?.nb_relances || 0}</div>
            <div>
              <span className="text-muted-foreground">Dernière : </span>
              {lead?.derniere_relance_at ? format(new Date(lead.derniere_relance_at), "dd/MM/yyyy", { locale: fr }) : "—"}
            </div>
            <div>
              <span className="text-muted-foreground">Prochaine relance : </span>
              {lead?.prochaine_relance_at ? format(new Date(lead.prochaine_relance_at), "dd/MM/yyyy", { locale: fr }) : "—"}
            </div>
            <div><span className="text-muted-foreground">Commentaire initial : </span>{lead?.commentaire || "—"}</div>
          </div>

          <Separator />
          <p className="flex items-center gap-2 text-sm font-semibold"><PhoneCall className="h-4 w-4" />Historique des relances ({relances.length})</p>
          <div className="space-y-2">
            {relances.map((r) => (
              <div key={r.id} className="rounded-md border p-3 text-sm">
                <div className="flex justify-between">
                  <b>{CANAUX.find((c) => c.v === r.canal)?.l || r.canal}</b>
                  <span className="text-xs text-muted-foreground">
                    {format(new Date(r.date_relance), "dd/MM/yyyy HH:mm", { locale: fr })}
                  </span>
                </div>
                <p className="text-muted-foreground">{RESULTATS.find((x) => x.v === r.resultat)?.l || r.resultat}</p>
                {r.commentaire && <p className="mt-1">{r.commentaire}</p>}
                {r.prochaine_relance && (
                  <p className="mt-1 text-xs text-muted-foreground">
                    Prochaine : {format(new Date(r.prochaine_relance), "dd/MM/yyyy", { locale: fr })}
                  </p>
                )}
              </div>
            ))}
            {relances.length === 0 && <p className="text-sm text-muted-foreground">Aucune relance enregistrée</p>}
          </div>
        </div>

        <Dialog open={open} onOpenChange={setOpen}>
          <DialogContent>
            <DialogHeader><DialogTitle>Nouvelle relance</DialogTitle></DialogHeader>
            <div className="space-y-3">
              <div>
                <Label>Canal</Label>
                <Select value={form.canal} onValueChange={(v) => setForm({ ...form, canal: v })}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>{CANAUX.map((c) => <SelectItem key={c.v} value={c.v}>{c.l}</SelectItem>)}</SelectContent>
                </Select>
              </div>
              <div>
                <Label>Résultat</Label>
                <Select value={form.resultat} onValueChange={(v) => setForm({ ...form, resultat: v })}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>{RESULTATS.map((r) => <SelectItem key={r.v} value={r.v}>{r.l}</SelectItem>)}</SelectContent>
                </Select>
              </div>
              <div>
                <Label>Commentaire</Label>
                <Textarea value={form.commentaire} onChange={(e) => setForm({ ...form, commentaire: e.target.value })} />
              </div>
              <div>
                <Label>Prochaine relance</Label>
                <Input type="date" value={form.prochaine_relance} onChange={(e) => setForm({ ...form, prochaine_relance: e.target.value })} />
              </div>
            </div>
            <DialogFooter>
              <Button variant="outline" onClick={() => setOpen(false)}>Annuler</Button>
              <Button onClick={enregistrer}>Enregistrer</Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </SheetContent>
    </Sheet>
  );
}
