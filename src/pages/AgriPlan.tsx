import { useMemo, useState } from "react";
import MainLayout from "@/components/layout/MainLayout";
import ProtectedRoute from "@/components/auth/ProtectedRoute";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Progress } from "@/components/ui/progress";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { useToast } from "@/hooks/use-toast";
import { usePermissions } from "@/hooks/usePermissions";
import { useAgriPlan } from "@/hooks/useAgriPlan";
import { getSafeErrorMessage } from "@/lib/safeError";
import {
  AGRIPLAN_ACCOMPAGNEMENT,
  AGRIPLAN_EXCLUS,
  AGRIPLAN_INCLUS,
  AgriPlanEcheanceStatut,
  formatFCFA,
} from "@/lib/agriplan";
import { CalendarClock, CheckCircle2, Save, TriangleAlert, XCircle } from "lucide-react";

const STATUT_LABEL: Record<AgriPlanEcheanceStatut, { label: string; variant: any }> = {
  a_venir: { label: "À venir", variant: "outline" },
  du: { label: "Dû", variant: "secondary" },
  paye: { label: "Payé", variant: "default" },
  en_retard: { label: "En retard", variant: "destructive" },
  annule: { label: "Annulé", variant: "outline" },
};

const AgriPlanPage = () => {
  const { toast } = useToast();
  const { can, isSuperAdmin } = usePermissions();
  const [dateDebut, setDateDebut] = useState<string>(new Date().toISOString().slice(0, 10));
  const { config, setConfig, totaux, echeancier, synthese, fromDatabase, save } = useAgriPlan(dateDebut);
  const [saving, setSaving] = useState(false);

  const peutAdministrer = isSuperAdmin || can("offres.gerer") || can("parametres.gerer");

  const mep = useMemo(() => echeancier.filter((e) => e.type === "mise_en_place"), [echeancier]);
  const suivi = useMemo(() => echeancier.filter((e) => e.type === "accompagnement"), [echeancier]);

  const handleSave = async () => {
    setSaving(true);
    const { error } = await save(config);
    setSaving(false);
    if (error) {
      toast({ variant: "destructive", title: "Erreur", description: getSafeErrorMessage(error) });
      return;
    }
    toast({ title: "Configuration AgriPlan enregistrée" });
  };

  const renderEcheances = (rows: typeof echeancier) => (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>N°</TableHead>
          <TableHead>Échéance</TableHead>
          <TableHead>Déclencheur</TableHead>
          <TableHead>Date</TableHead>
          <TableHead className="text-right">Montant</TableHead>
          <TableHead className="text-right">Payé</TableHead>
          <TableHead className="text-right">Solde</TableHead>
          <TableHead>Retard</TableHead>
          <TableHead>Statut</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {rows.map((e) => (
          <TableRow key={e.id}>
            <TableCell>{e.numero_echeance}</TableCell>
            <TableCell className="font-medium">{e.libelle}</TableCell>
            <TableCell className="text-muted-foreground text-sm">{e.declencheur}</TableCell>
            <TableCell>{new Date(e.date_echeance).toLocaleDateString("fr-FR")}</TableCell>
            <TableCell className="text-right">{formatFCFA(e.montant)}</TableCell>
            <TableCell className="text-right">{formatFCFA(e.montant_paye)}</TableCell>
            <TableCell className="text-right">{formatFCFA(e.solde)}</TableCell>
            <TableCell>{e.jours_retard > 0 ? `${e.jours_retard} j` : "—"}</TableCell>
            <TableCell>
              <Badge variant={STATUT_LABEL[e.statut].variant}>{STATUT_LABEL[e.statut].label}</Badge>
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );

  return (
    <ProtectedRoute>
      <MainLayout>
        <div className="space-y-6">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h1 className="text-2xl font-bold">AgriPlan</h1>
              <p className="text-muted-foreground text-sm">
                L'offre clé en main pour vos plantations de palmier à huile — suivi professionnel sur {config.dureeMois} mois.
              </p>
            </div>
            <Badge variant={fromDatabase ? "default" : "outline"}>
              {fromDatabase ? "Configuration base de données" : "Configuration par défaut"}
            </Badge>
          </div>

          <div className="grid gap-4 md:grid-cols-4">
            <Card>
              <CardHeader className="pb-2"><CardDescription>Prix global de l'offre</CardDescription></CardHeader>
              <CardContent className="text-2xl font-bold text-primary">{formatFCFA(totaux.total)}</CardContent>
            </Card>
            <Card>
              <CardHeader className="pb-2"><CardDescription>A. Mise en place</CardDescription></CardHeader>
              <CardContent className="text-2xl font-bold">{formatFCFA(totaux.miseEnPlace)}</CardContent>
            </Card>
            <Card>
              <CardHeader className="pb-2"><CardDescription>B. Suivi & encadrement</CardDescription></CardHeader>
              <CardContent className="text-2xl font-bold">{formatFCFA(totaux.accompagnement)}</CardContent>
            </Card>
            <Card>
              <CardHeader className="pb-2"><CardDescription>Reste à payer</CardDescription></CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{formatFCFA(synthese.totalRestant)}</div>
                <Progress value={synthese.pourcentageAvancement} className="mt-2" />
                <p className="text-xs text-muted-foreground mt-1">{synthese.pourcentageAvancement}% payé</p>
              </CardContent>
            </Card>
          </div>

          <Tabs defaultValue="echeancier">
            <TabsList>
              <TabsTrigger value="echeancier">Échéancier</TabsTrigger>
              <TabsTrigger value="synthese">Synthèse</TabsTrigger>
              <TabsTrigger value="prestations">Inclus / Non inclus</TabsTrigger>
              <TabsTrigger value="tarification">Tarification</TabsTrigger>
            </TabsList>

            <TabsContent value="echeancier" className="space-y-4">
              <Card>
                <CardHeader>
                  <CardTitle>A. Mise en place de la plantation</CardTitle>
                  <CardDescription>{formatFCFA(totaux.miseEnPlace)} — {mep.length} échéances</CardDescription>
                </CardHeader>
                <CardContent className="overflow-x-auto">
                  <div className="max-w-xs mb-4">
                    <Label>Date de démarrage</Label>
                    <Input type="date" value={dateDebut} onChange={(e) => setDateDebut(e.target.value)} />
                  </div>
                  {renderEcheances(mep)}
                </CardContent>
              </Card>
              <Card>
                <CardHeader>
                  <CardTitle>B. Suivi et encadrement</CardTitle>
                  <CardDescription>
                    {formatFCFA(config.montantTrimestre)} / trimestre pendant {config.dureeMois} mois ({config.nbTrimestres} trimestres) — {formatFCFA(totaux.accompagnement)}
                  </CardDescription>
                </CardHeader>
                <CardContent className="overflow-x-auto">{renderEcheances(suivi)}</CardContent>
              </Card>
            </TabsContent>

            <TabsContent value="synthese" className="space-y-4">
              <div className="grid gap-4 md:grid-cols-3">
                <Card>
                  <CardHeader className="pb-2"><CardDescription>Total prévu</CardDescription></CardHeader>
                  <CardContent className="text-xl font-bold">{formatFCFA(synthese.totalPrevu)}</CardContent>
                </Card>
                <Card>
                  <CardHeader className="pb-2"><CardDescription>Total payé</CardDescription></CardHeader>
                  <CardContent className="text-xl font-bold">{formatFCFA(synthese.totalPaye)}</CardContent>
                </Card>
                <Card>
                  <CardHeader className="pb-2"><CardDescription>Total restant</CardDescription></CardHeader>
                  <CardContent className="text-xl font-bold">{formatFCFA(synthese.totalRestant)}</CardContent>
                </Card>
              </div>
              <Card>
                <CardHeader><CardTitle className="flex items-center gap-2"><CalendarClock className="h-4 w-4" /> Prochaines échéances</CardTitle></CardHeader>
                <CardContent className="overflow-x-auto">
                  {synthese.prochaines.length ? renderEcheances(synthese.prochaines) : <p className="text-muted-foreground text-sm">Aucune échéance à venir.</p>}
                </CardContent>
              </Card>
              <Card>
                <CardHeader><CardTitle className="flex items-center gap-2"><TriangleAlert className="h-4 w-4 text-destructive" /> Échéances en retard</CardTitle></CardHeader>
                <CardContent className="overflow-x-auto">
                  {synthese.enRetard.length ? renderEcheances(synthese.enRetard) : <p className="text-muted-foreground text-sm">Aucun retard.</p>}
                </CardContent>
              </Card>
            </TabsContent>

            <TabsContent value="prestations" className="grid gap-4 md:grid-cols-3">
              <Card>
                <CardHeader><CardTitle className="text-base">Ce qui est inclus</CardTitle></CardHeader>
                <CardContent className="space-y-2 text-sm">
                  {AGRIPLAN_INCLUS.map((i) => (
                    <p key={i} className="flex gap-2"><CheckCircle2 className="h-4 w-4 text-primary shrink-0 mt-0.5" />{i}</p>
                  ))}
                </CardContent>
              </Card>
              <Card>
                <CardHeader><CardTitle className="text-base">Non inclus (facturable séparément)</CardTitle></CardHeader>
                <CardContent className="space-y-2 text-sm">
                  {AGRIPLAN_EXCLUS.map((i) => (
                    <p key={i} className="flex gap-2"><XCircle className="h-4 w-4 text-destructive shrink-0 mt-0.5" />{i}</p>
                  ))}
                </CardContent>
              </Card>
              <Card>
                <CardHeader><CardTitle className="text-base">Accompagnement trimestriel</CardTitle></CardHeader>
                <CardContent className="space-y-2 text-sm">
                  {AGRIPLAN_ACCOMPAGNEMENT.map((i) => <p key={i}>• {i}</p>)}
                </CardContent>
              </Card>
            </TabsContent>

            <TabsContent value="tarification">
              <Card>
                <CardHeader>
                  <CardTitle>Tarification administrable</CardTitle>
                  <CardDescription>
                    Les montants sont stockés dans la configuration système (catégorie <code>agriplan</code>). Aucune valeur codée en dur.
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="grid gap-4 md:grid-cols-3">
                    <div>
                      <Label>Montant par trimestre (FCFA)</Label>
                      <Input
                        type="number" min={0} disabled={!peutAdministrer}
                        value={config.montantTrimestre}
                        onChange={(e) => setConfig({ ...config, montantTrimestre: Number(e.target.value) })}
                      />
                    </div>
                    <div>
                      <Label>Nombre de trimestres</Label>
                      <Input
                        type="number" min={1} disabled={!peutAdministrer}
                        value={config.nbTrimestres}
                        onChange={(e) => setConfig({ ...config, nbTrimestres: Number(e.target.value) })}
                      />
                    </div>
                    <div>
                      <Label>Durée (mois)</Label>
                      <Input
                        type="number" min={1} disabled={!peutAdministrer}
                        value={config.dureeMois}
                        onChange={(e) => setConfig({ ...config, dureeMois: Number(e.target.value) })}
                      />
                    </div>
                  </div>

                  <div className="space-y-3">
                    <Label>Tranches de mise en place</Label>
                    {config.tranchesMiseEnPlace.map((t, idx) => (
                      <div key={t.numero} className="grid gap-2 md:grid-cols-[2fr_1fr_3fr]">
                        <Input
                          value={t.libelle} disabled={!peutAdministrer}
                          onChange={(e) => {
                            const next = [...config.tranchesMiseEnPlace];
                            next[idx] = { ...t, libelle: e.target.value };
                            setConfig({ ...config, tranchesMiseEnPlace: next });
                          }}
                        />
                        <Input
                          type="number" min={0} value={t.montant} disabled={!peutAdministrer}
                          onChange={(e) => {
                            const next = [...config.tranchesMiseEnPlace];
                            next[idx] = { ...t, montant: Number(e.target.value) };
                            setConfig({ ...config, tranchesMiseEnPlace: next });
                          }}
                        />
                        <Input
                          value={t.declencheur} disabled={!peutAdministrer}
                          onChange={(e) => {
                            const next = [...config.tranchesMiseEnPlace];
                            next[idx] = { ...t, declencheur: e.target.value };
                            setConfig({ ...config, tranchesMiseEnPlace: next });
                          }}
                        />
                      </div>
                    ))}
                  </div>

                  <div className="rounded-md border p-3 text-sm">
                    Mise en place <b>{formatFCFA(totaux.miseEnPlace)}</b> + Accompagnement <b>{formatFCFA(totaux.accompagnement)}</b> ={" "}
                    <b className="text-primary">{formatFCFA(totaux.total)}</b>
                  </div>

                  {peutAdministrer && (
                    <Button onClick={handleSave} disabled={saving}>
                      <Save className="h-4 w-4 mr-2" />
                      {saving ? "Enregistrement..." : "Enregistrer la configuration"}
                    </Button>
                  )}
                </CardContent>
              </Card>
            </TabsContent>
          </Tabs>
        </div>
      </MainLayout>
    </ProtectedRoute>
  );
};

export default AgriPlanPage;
