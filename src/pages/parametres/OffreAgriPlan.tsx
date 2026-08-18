import { useState } from "react";
import { useAgriPlanOffre } from "@/hooks/useAgriPlanOffre";
import { computeAgriPlanTotaux, formatFCFA, AgriPlanTranche } from "@/lib/agriplan";
import { PERMISSIONS, hasPermission } from "@/lib/roles";
import { useAuth } from "@/hooks/useAuth";
import { toast } from "sonner";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Switch } from "@/components/ui/switch";
import { Separator } from "@/components/ui/separator";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Plus, Save, Trash2 } from "lucide-react";

/** Paramètres → Offres → AgriPlan : configuration commerciale de l'offre unique AgriPlan */
export default function OffreAgriPlan() {
  const { userRoles } = useAuth();
  const { offre, setOffre, loading, saving, save } = useAgriPlanOffre();
  const [dirty, setDirty] = useState(false);
  const canManage = hasPermission(userRoles, PERMISSIONS.MANAGE_OFFERS);

  const patch = (p: Partial<typeof offre>) => {
    setOffre({ ...offre, ...p });
    setDirty(true);
  };

  const patchTranche = (i: number, p: Partial<AgriPlanTranche>) => {
    const tranches = offre.tranches.map((t, idx) => (idx === i ? { ...t, ...p } : t));
    patch({ tranches });
  };

  const addTranche = () =>
    patch({
      tranches: [...offre.tranches, { numero: offre.tranches.length + 1, libelle: "Nouvelle tranche", montant: 0, declencheur: "" }],
    });

  const removeTranche = (i: number) =>
    patch({ tranches: offre.tranches.filter((_, idx) => idx !== i).map((t, idx) => ({ ...t, numero: idx + 1 })) });

  const totaux = computeAgriPlanTotaux(offre, 1);
  const coherent = Math.round(totaux.total) === Math.round(offre.prix_total);

  const submit = async () => {
    const { error } = await save({ ...offre, montant_mise_en_place: totaux.miseEnPlace });
    if (error) {
      toast.error("Enregistrement impossible : " + error.message);
      return;
    }
    setDirty(false);
    toast.success("Offre AgriPlan mise à jour");
  };

  if (loading) return <p className="text-sm text-muted-foreground">Chargement de l'offre AgriPlan...</p>;

  return (
    <div className="space-y-4">
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center justify-between">
            <span>Offre {offre.nom}</span>
            <div className="flex items-center gap-2 text-sm font-normal">
              <span className="text-muted-foreground">Active</span>
              <Switch checked={offre.actif} disabled={!canManage} onCheckedChange={(v) => patch({ actif: v })} />
            </div>
          </CardTitle>
          <CardDescription>
            Offre unique AgriPlan. Ces paramètres alimentent automatiquement les ventes, l'échéancier et le portail client.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid gap-3 sm:grid-cols-2">
            <div>
              <Label>Nom de l'offre</Label>
              <Input value={offre.nom} disabled={!canManage} onChange={(e) => patch({ nom: e.target.value })} />
            </div>
            <div>
              <Label>Prix de l'offre (FCFA / ha)</Label>
              <Input type="number" value={offre.prix_total} disabled={!canManage} onChange={(e) => patch({ prix_total: Number(e.target.value) })} />
            </div>
            <div className="sm:col-span-2">
              <Label>Description</Label>
              <Textarea rows={2} value={offre.description || ""} disabled={!canManage} onChange={(e) => patch({ description: e.target.value })} />
            </div>
          </div>

          <Separator />
          <p className="text-sm font-semibold">Répartition des paiements (mise en place)</p>
          <div className="space-y-2">
            {offre.tranches.map((t, i) => {
              const pct = offre.prix_total > 0 ? Math.round((Number(t.montant) / offre.prix_total) * 100) : 0;
              return (
                <div key={i} className="grid items-end gap-2 rounded-md border p-2 sm:grid-cols-12">
                  <div className="sm:col-span-3">
                    <Label className="text-xs">Libellé</Label>
                    <Input value={t.libelle} disabled={!canManage} onChange={(e) => patchTranche(i, { libelle: e.target.value })} />
                  </div>
                  <div className="sm:col-span-2">
                    <Label className="text-xs">Montant</Label>
                    <Input type="number" value={t.montant} disabled={!canManage} onChange={(e) => patchTranche(i, { montant: Number(e.target.value) })} />
                  </div>
                  <div className="sm:col-span-1">
                    <Label className="text-xs">%</Label>
                    <Input value={`${pct}%`} readOnly disabled />
                  </div>
                  <div className="sm:col-span-5">
                    <Label className="text-xs">Déclencheur / échéance</Label>
                    <Input value={t.declencheur || ""} disabled={!canManage} onChange={(e) => patchTranche(i, { declencheur: e.target.value })} />
                  </div>
                  <div className="sm:col-span-1">
                    {canManage && (
                      <Button variant="ghost" size="icon" onClick={() => removeTranche(i)}><Trash2 className="h-4 w-4" /></Button>
                    )}
                  </div>
                </div>
              );
            })}
            {canManage && (
              <Button variant="outline" size="sm" onClick={addTranche}><Plus className="mr-1 h-4 w-4" />Ajouter une tranche</Button>
            )}
          </div>

          <Separator />
          <p className="text-sm font-semibold">Accompagnement technique</p>
          <div className="grid gap-3 sm:grid-cols-3">
            <div>
              <Label>Montant par période (FCFA)</Label>
              <Input type="number" value={offre.montant_accompagnement_periode} disabled={!canManage} onChange={(e) => patch({ montant_accompagnement_periode: Number(e.target.value) })} />
            </div>
            <div>
              <Label>Périodicité</Label>
              <Select value={offre.periodicite_accompagnement} onValueChange={(v) => patch({ periodicite_accompagnement: v })} disabled={!canManage}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {["mensuel", "trimestriel", "semestriel", "annuel"].map((p) => <SelectItem key={p} value={p}>{p}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
            <div>
              <Label>Nombre de périodes</Label>
              <Input type="number" value={offre.nb_periodes_accompagnement} disabled={!canManage} onChange={(e) => patch({ nb_periodes_accompagnement: Number(e.target.value) })} />
            </div>
            <div>
              <Label>Durée totale (mois)</Label>
              <Input type="number" value={offre.duree_mois} disabled={!canManage} onChange={(e) => patch({ duree_mois: Number(e.target.value) })} />
            </div>
          </div>

          <div className="rounded-md border bg-muted/40 p-3 text-sm">
            <div className="flex justify-between"><span>Total mise en place</span><span className="font-medium">{formatFCFA(totaux.miseEnPlace)}</span></div>
            <div className="flex justify-between"><span>Total accompagnement</span><span className="font-medium">{formatFCFA(totaux.accompagnement)}</span></div>
            <div className="mt-1 flex justify-between border-t pt-1 font-semibold"><span>Total calculé / ha</span><span>{formatFCFA(totaux.total)}</span></div>
            {!coherent && (
              <p className="mt-2 text-xs text-destructive">
                Attention : le total calculé ({formatFCFA(totaux.total)}) diffère du prix de l'offre saisi ({formatFCFA(offre.prix_total)}).
              </p>
            )}
          </div>

          {canManage && (
            <Button onClick={submit} disabled={saving || !dirty}>
              <Save className="mr-1 h-4 w-4" />{saving ? "Enregistrement..." : "Enregistrer l'offre AgriPlan"}
            </Button>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
