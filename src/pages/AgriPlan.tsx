import { useCallback, useEffect, useMemo, useState } from "react";
import MainLayout from "@/components/layout/MainLayout";
import ProtectedRoute from "@/components/auth/ProtectedRoute";
import { supabase } from "@/integrations/supabase/client";
import { useAgriPlanGeo } from "@/hooks/useAgriPlanGeo";
import { useAgriPlanOffre } from "@/hooks/useAgriPlanOffre";
import { PERMISSIONS, hasPermission } from "@/lib/roles";
import { useAuth } from "@/hooks/useAuth";
import { AGRIPLAN_ETAPES, AGRIPLAN_LEAD_STATUTS, formatFCFA, labelOf } from "@/lib/agriplan";
import AgriPlanLeadDialog from "@/components/agriplan/AgriPlanLeadDialog";
import AgriPlanVenteDialog, { AgriPlanLeadLite } from "@/components/agriplan/AgriPlanVenteDialog";
import AgriPlanClientDetail from "@/components/agriplan/AgriPlanClientDetail";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import { Label } from "@/components/ui/label";
import { Plus, ShoppingCart, Search, Users, Target, Wallet } from "lucide-react";

type Row = Record<string, any>;

const AgriPlan = () => {
  const { userRoles } = useAuth();
  const { nomRegion, nomSousPrefecture } = useAgriPlanGeo();
  const { offre } = useAgriPlanOffre();
  const [leads, setLeads] = useState<Row[]>([]);
  const [clients, setClients] = useState<Row[]>([]);
  const [loading, setLoading] = useState(true);
  const [q, setQ] = useState("");
  const [showArchives, setShowArchives] = useState(false);
  const [leadOpen, setLeadOpen] = useState(false);
  const [venteOpen, setVenteOpen] = useState(false);
  const [venteLead, setVenteLead] = useState<AgriPlanLeadLite | null>(null);
  const [detailId, setDetailId] = useState<string | null>(null);

  const canSell = hasPermission(userRoles, PERMISSIONS.AGRIPLAN_VENTES);

  const load = useCallback(async () => {
    setLoading(true);
    const [l, c] = await Promise.all([
      supabase.from("agriplan_leads").select("*").order("created_at", { ascending: false }),
      supabase.from("agriplan_clients").select("*, agriplan_ventes(montant_total, total_paye, solde)").order("created_at", { ascending: false }),
    ]);
    setLeads((l.data || []) as Row[]);
    setClients((c.data || []) as Row[]);
    setLoading(false);
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const match = (r: Row) =>
    !q.trim() ||
    [r.nom_complet, r.telephone, r.whatsapp, r.localite, r.numero_client]
      .filter(Boolean)
      .some((v: string) => String(v).toLowerCase().includes(q.toLowerCase()));

  const leadsVisibles = useMemo(() => leads.filter((l) => l.statut !== "converti" && match(l)), [leads, q]);
  const clientsVisibles = useMemo(
    () => clients.filter((c) => (showArchives ? c.statut === "archive" : c.statut !== "archive") && match(c)),
    [clients, q, showArchives],
  );

  const totalVentes = clients.reduce(
    (s, c) => s + ((c.agriplan_ventes as Row[]) || []).reduce((a, v) => a + Number(v.montant_total || 0), 0),
    0,
  );
  const totalEncaisse = clients.reduce(
    (s, c) => s + ((c.agriplan_ventes as Row[]) || []).reduce((a, v) => a + Number(v.total_paye || 0), 0),
    0,
  );

  return (
    <ProtectedRoute requiredPermission={PERMISSIONS.VIEW_AGRIPLAN}>
      <MainLayout>
        <div className="space-y-6">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <h1 className="text-2xl font-bold sm:text-3xl">AgriPlan</h1>
              <p className="mt-1 text-sm text-muted-foreground sm:text-base">
                Parcours commercial AgriPlan : leads, ventes et dossiers clients — offre {offre.nom} ({formatFCFA(offre.prix_total)} / ha).
              </p>
            </div>
            {canSell && (
              <div className="flex flex-wrap gap-2">
                <Button variant="outline" onClick={() => setLeadOpen(true)}><Plus className="mr-1 h-4 w-4" />Nouveau Lead</Button>
                <Button onClick={() => { setVenteLead(null); setVenteOpen(true); }}><ShoppingCart className="mr-1 h-4 w-4" />Nouvelle Vente</Button>
              </div>
            )}
          </div>

          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <Card><CardHeader className="pb-2"><CardTitle className="flex items-center gap-2 text-sm font-medium text-muted-foreground"><Target className="h-4 w-4" />Leads actifs</CardTitle></CardHeader><CardContent><p className="text-2xl font-bold">{leads.filter((l) => l.statut !== "converti" && l.statut !== "perdu").length}</p></CardContent></Card>
            <Card><CardHeader className="pb-2"><CardTitle className="flex items-center gap-2 text-sm font-medium text-muted-foreground"><Users className="h-4 w-4" />Clients AgriPlan</CardTitle></CardHeader><CardContent><p className="text-2xl font-bold">{clients.filter((c) => c.statut !== "archive").length}</p></CardContent></Card>
            <Card><CardHeader className="pb-2"><CardTitle className="flex items-center gap-2 text-sm font-medium text-muted-foreground"><Wallet className="h-4 w-4" />Ventes AgriPlan</CardTitle></CardHeader><CardContent><p className="text-2xl font-bold">{formatFCFA(totalVentes)}</p></CardContent></Card>
            <Card><CardHeader className="pb-2"><CardTitle className="flex items-center gap-2 text-sm font-medium text-muted-foreground"><Wallet className="h-4 w-4" />Encaissé</CardTitle></CardHeader><CardContent><p className="text-2xl font-bold">{formatFCFA(totalEncaisse)}</p></CardContent></Card>
          </div>

          <div className="flex flex-wrap items-center gap-3">
            <div className="relative w-full max-w-sm">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input className="pl-9" placeholder="Rechercher un lead ou un client AgriPlan..." value={q} onChange={(e) => setQ(e.target.value)} />
            </div>
            <div className="flex items-center gap-2">
              <Switch id="archives" checked={showArchives} onCheckedChange={setShowArchives} />
              <Label htmlFor="archives" className="text-sm">Dossiers archivés</Label>
            </div>
          </div>

          <Tabs defaultValue="leads">
            <TabsList>
              <TabsTrigger value="leads">Leads ({leadsVisibles.length})</TabsTrigger>
              <TabsTrigger value="clients">Clients ({clientsVisibles.length})</TabsTrigger>
            </TabsList>

            <TabsContent value="leads" className="pt-4">
              <Card>
                <CardContent className="overflow-x-auto p-0">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>Nom et prénom</TableHead>
                        <TableHead>Téléphone</TableHead>
                        <TableHead>Région</TableHead>
                        <TableHead>Sous-préfecture</TableHead>
                        <TableHead>Localité</TableHead>
                        <TableHead>Statut</TableHead>
                        <TableHead></TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {leadsVisibles.map((l) => (
                        <TableRow key={l.id}>
                          <TableCell className="font-medium">{l.nom_complet}</TableCell>
                          <TableCell>{l.telephone}{l.whatsapp ? ` / ${l.whatsapp}` : ""}</TableCell>
                          <TableCell>{nomRegion(l.region_id)}</TableCell>
                          <TableCell>{nomSousPrefecture(l.sous_prefecture_id)}</TableCell>
                          <TableCell>{l.localite || "—"}</TableCell>
                          <TableCell><Badge variant="outline">{labelOf(AGRIPLAN_LEAD_STATUTS as never, l.statut)}</Badge></TableCell>
                          <TableCell className="text-right">
                            {canSell && (
                              <Button size="sm" onClick={() => { setVenteLead(l as AgriPlanLeadLite); setVenteOpen(true); }}>
                                Convertir en vente
                              </Button>
                            )}
                          </TableCell>
                        </TableRow>
                      ))}
                      {!loading && leadsVisibles.length === 0 && (
                        <TableRow><TableCell colSpan={7} className="py-8 text-center text-muted-foreground">Aucun lead AgriPlan</TableCell></TableRow>
                      )}
                    </TableBody>
                  </Table>
                </CardContent>
              </Card>
            </TabsContent>

            <TabsContent value="clients" className="pt-4">
              <Card>
                <CardContent className="overflow-x-auto p-0">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>N° client</TableHead>
                        <TableHead>Nom et prénom</TableHead>
                        <TableHead>Téléphone</TableHead>
                        <TableHead>Localité</TableHead>
                        <TableHead>Total vente</TableHead>
                        <TableHead>Solde</TableHead>
                        <TableHead>Dossier</TableHead>
                        <TableHead></TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {clientsVisibles.map((c) => {
                        const v = ((c.agriplan_ventes as Row[]) || [])[0] || {};
                        return (
                          <TableRow key={c.id} className="cursor-pointer" onClick={() => setDetailId(c.id)}>
                            <TableCell>{c.numero_client}</TableCell>
                            <TableCell className="font-medium">{c.nom_complet}</TableCell>
                            <TableCell>{c.telephone}</TableCell>
                            <TableCell>{c.localite || "—"}</TableCell>
                            <TableCell>{formatFCFA(v.montant_total)}</TableCell>
                            <TableCell>{formatFCFA(v.solde)}</TableCell>
                            <TableCell><Badge variant="outline">{labelOf(AGRIPLAN_ETAPES as never, c.statut_dossier)}</Badge></TableCell>
                            <TableCell className="text-right"><Button size="sm" variant="outline">Ouvrir</Button></TableCell>
                          </TableRow>
                        );
                      })}
                      {!loading && clientsVisibles.length === 0 && (
                        <TableRow><TableCell colSpan={8} className="py-8 text-center text-muted-foreground">Aucun client AgriPlan</TableCell></TableRow>
                      )}
                    </TableBody>
                  </Table>
                </CardContent>
              </Card>
            </TabsContent>
          </Tabs>
        </div>

        <AgriPlanLeadDialog open={leadOpen} onOpenChange={setLeadOpen} onSaved={load} />
        <AgriPlanVenteDialog open={venteOpen} onOpenChange={setVenteOpen} onSaved={load} lead={venteLead} />
        <AgriPlanClientDetail clientId={detailId} onOpenChange={(v) => !v && setDetailId(null)} onChanged={load} />
      </MainLayout>
    </ProtectedRoute>
  );
};

export default AgriPlan;
