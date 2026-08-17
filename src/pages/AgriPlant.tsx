import { useMemo, useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import MainLayout from "@/components/layout/MainLayout";
import ProtectedRoute from "@/components/auth/ProtectedRoute";
import { supabase } from "@/integrations/supabase/client";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { useToast } from "@/hooks/use-toast";
import { useAuth } from "@/hooks/useAuth";
import { PERMISSIONS } from "@/lib/roles";
import { getSafeErrorMessage } from "@/lib/safeError";
import { format } from "date-fns";
import { fr } from "date-fns/locale";
import { Leaf, Plus, Upload, FileText, History, Loader2 } from "lucide-react";

const TYPES_SUIVI = [
  { v: "visite_terrain", l: "Visite terrain" },
  { v: "entretien", l: "Entretien" },
  { v: "traitement", l: "Traitement phytosanitaire" },
  { v: "fertilisation", l: "Fertilisation" },
  { v: "recolte", l: "Récolte" },
  { v: "incident", l: "Incident" },
];

const STATUTS = [
  { v: "planifie", l: "Planifié", variant: "outline" as const },
  { v: "en_cours", l: "En cours", variant: "secondary" as const },
  { v: "termine", l: "Terminé", variant: "default" as const },
  { v: "annule", l: "Annulé", variant: "destructive" as const },
];

const emptyForm = {
  id: "" as string,
  plantation_id: "",
  type_suivi: "visite_terrain",
  titre: "",
  observations: "",
  actions_recommandees: "",
  meteo: "",
  note_sante: "",
  date_visite: new Date().toISOString().slice(0, 10),
  prochaine_visite: "",
  statut: "planifie",
  responsable_id: "",
};

type FormState = typeof emptyForm;
type Fichier = { nom: string; chemin: string };

const labelOf = (list: { v: string; l: string }[], v?: string | null) =>
  list.find((i) => i.v === v)?.l || v || "—";

const AgriPlantPage = () => {
  const { toast } = useToast();
  const { user } = useAuth();
  const qc = useQueryClient();
  const [search, setSearch] = useState("");
  const [filtreStatut, setFiltreStatut] = useState("tous");
  const [form, setForm] = useState<FormState>(emptyForm);
  const [photos, setPhotos] = useState<Fichier[]>([]);
  const [documents, setDocuments] = useState<Fichier[]>([]);
  const [open, setOpen] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [historiqueDe, setHistoriqueDe] = useState<any>(null);

  const set = (k: keyof FormState, v: string) => setForm((p) => ({ ...p, [k]: v }));

  const { data: suivis = [], isLoading } = useQuery({
    queryKey: ["agriplant-suivis"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("agriplant_suivis")
        .select("*, plantations(nom_plantation, nom, id_unique), souscripteurs(nom_complet)")
        .order("date_visite", { ascending: false })
        .limit(500);
      if (error) throw error;
      return data || [];
    },
  });

  const { data: plantations = [] } = useQuery({
    queryKey: ["agriplant-plantations"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("plantations")
        .select("id, nom_plantation, nom, id_unique, souscripteur_id")
        .order("created_at", { ascending: false })
        .limit(500);
      if (error) throw error;
      return data || [];
    },
  });

  const { data: responsables = [] } = useQuery({
    queryKey: ["agriplant-responsables"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("profiles")
        .select("id, user_id, nom_complet")
        .eq("actif", true)
        .order("nom_complet");
      if (error) throw error;
      return data || [];
    },
  });

  const { data: historique = [] } = useQuery({
    queryKey: ["agriplant-historique", historiqueDe?.id],
    enabled: !!historiqueDe?.id,
    queryFn: async () => {
      const { data, error } = await supabase
        .from("agriplant_suivi_historique")
        .select("*")
        .eq("suivi_id", historiqueDe.id)
        .order("created_at", { ascending: false });
      if (error) throw error;
      return data || [];
    },
  });

  const nomPlantation = (p: any) =>
    p ? `${p.nom_plantation || p.nom || "Plantation"}${p.id_unique ? ` (${p.id_unique})` : ""}` : "—";
  const nomResponsable = (id?: string | null) =>
    responsables.find((r: any) => r.user_id === id || r.id === id)?.nom_complet || "—";

  const filtres = useMemo(() => {
    const q = search.trim().toLowerCase();
    return (suivis as any[]).filter((s) => {
      const okStatut = filtreStatut === "tous" || s.statut === filtreStatut;
      const hay = `${s.titre} ${s.observations || ""} ${nomPlantation(s.plantations)} ${s.souscripteurs?.nom_complet || ""}`.toLowerCase();
      return okStatut && (!q || hay.includes(q));
    });
  }, [suivis, search, filtreStatut]);

  const upload = async (file: File, dossier: "photos" | "documents") => {
    setUploading(true);
    const ext = file.name.split(".").pop();
    const chemin = `${dossier}/${crypto.randomUUID()}.${ext}`;
    const { error } = await supabase.storage.from("agriplant").upload(chemin, file, { upsert: false });
    setUploading(false);
    if (error) {
      toast({ variant: "destructive", title: "Envoi impossible", description: getSafeErrorMessage(error) });
      return;
    }
    const entry = { nom: file.name, chemin };
    if (dossier === "photos") setPhotos((p) => [...p, entry]);
    else setDocuments((p) => [...p, entry]);
    toast({ title: "Fichier ajouté" });
  };

  const openCreate = () => {
    setForm(emptyForm);
    setPhotos([]);
    setDocuments([]);
    setOpen(true);
  };

  const openEdit = (s: any) => {
    setForm({
      id: s.id,
      plantation_id: s.plantation_id || "",
      type_suivi: s.type_suivi || "visite_terrain",
      titre: s.titre || "",
      observations: s.observations || "",
      actions_recommandees: s.actions_recommandees || "",
      meteo: s.meteo || "",
      note_sante: s.note_sante != null ? String(s.note_sante) : "",
      date_visite: s.date_visite || new Date().toISOString().slice(0, 10),
      prochaine_visite: s.prochaine_visite || "",
      statut: s.statut || "planifie",
      responsable_id: s.responsable_id || "",
    });
    setPhotos(Array.isArray(s.photos) ? s.photos : []);
    setDocuments(Array.isArray(s.documents) ? s.documents : []);
    setOpen(true);
  };

  const save = useMutation({
    mutationFn: async () => {
      if (!form.plantation_id || !form.titre.trim()) throw new Error("Plantation et titre obligatoires");
      const plantation = (plantations as any[]).find((p) => p.id === form.plantation_id);
      const payload: any = {
        plantation_id: form.plantation_id,
        souscripteur_id: plantation?.souscripteur_id || null,
        type_suivi: form.type_suivi,
        titre: form.titre.trim(),
        observations: form.observations || null,
        actions_recommandees: form.actions_recommandees || null,
        meteo: form.meteo || null,
        note_sante: form.note_sante ? Number(form.note_sante) : null,
        date_visite: form.date_visite,
        prochaine_visite: form.prochaine_visite || null,
        statut: form.statut,
        responsable_id: form.responsable_id || null,
        photos,
        documents,
      };
      if (form.id) {
        const { error } = await supabase.from("agriplant_suivis").update(payload).eq("id", form.id);
        if (error) throw error;
      } else {
        const { error } = await supabase
          .from("agriplant_suivis")
          .insert({ ...payload, created_by: user?.id || null });
        if (error) throw error;
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["agriplant-suivis"] });
      setOpen(false);
      toast({ title: form.id ? "Suivi mis à jour" : "Suivi créé" });
    },
    onError: (e: any) =>
      toast({ variant: "destructive", title: "Erreur", description: getSafeErrorMessage(e) }),
  });

  return (
    <ProtectedRoute requiredPermission={PERMISSIONS.VIEW_PLANTATIONS}>
      <MainLayout>
        <div className="space-y-6">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h1 className="flex items-center gap-2 text-2xl font-bold">
                <Leaf className="h-6 w-6 text-primary" /> AgriPlant — suivi technique
              </h1>
              <p className="text-sm text-muted-foreground">
                Visites, observations, photos et documents de terrain par plantation.
              </p>
            </div>
            <Button onClick={openCreate}>
              <Plus className="mr-2 h-4 w-4" /> Nouveau suivi
            </Button>
          </div>

          <Card>
            <CardHeader className="gap-3 sm:flex-row sm:items-end sm:justify-between">
              <div>
                <CardTitle>Suivis</CardTitle>
                <CardDescription>{filtres.length} suivi(s)</CardDescription>
              </div>
              <div className="flex flex-wrap gap-2">
                <Input
                  placeholder="Rechercher..."
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  className="sm:w-64"
                />
                <Select value={filtreStatut} onValueChange={setFiltreStatut}>
                  <SelectTrigger className="sm:w-44"><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="tous">Tous les statuts</SelectItem>
                    {STATUTS.map((s) => <SelectItem key={s.v} value={s.v}>{s.l}</SelectItem>)}
                  </SelectContent>
                </Select>
              </div>
            </CardHeader>
            <CardContent className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Date</TableHead>
                    <TableHead>Plantation</TableHead>
                    <TableHead>Type</TableHead>
                    <TableHead>Titre</TableHead>
                    <TableHead>Responsable</TableHead>
                    <TableHead>Santé</TableHead>
                    <TableHead>Statut</TableHead>
                    <TableHead className="text-right">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {isLoading && (
                    <TableRow><TableCell colSpan={8} className="text-center text-muted-foreground">Chargement...</TableCell></TableRow>
                  )}
                  {!isLoading && filtres.length === 0 && (
                    <TableRow><TableCell colSpan={8} className="text-center text-muted-foreground">Aucun suivi</TableCell></TableRow>
                  )}
                  {filtres.map((s: any) => {
                    const st = STATUTS.find((x) => x.v === s.statut);
                    return (
                      <TableRow key={s.id}>
                        <TableCell>{s.date_visite ? format(new Date(s.date_visite), "dd/MM/yyyy", { locale: fr }) : "—"}</TableCell>
                        <TableCell>{nomPlantation(s.plantations)}</TableCell>
                        <TableCell>{labelOf(TYPES_SUIVI, s.type_suivi)}</TableCell>
                        <TableCell className="font-medium">{s.titre}</TableCell>
                        <TableCell>{nomResponsable(s.responsable_id)}</TableCell>
                        <TableCell>{s.note_sante != null ? `${s.note_sante}/10` : "—"}</TableCell>
                        <TableCell><Badge variant={st?.variant || "outline"}>{st?.l || s.statut}</Badge></TableCell>
                        <TableCell className="text-right space-x-2 whitespace-nowrap">
                          <Button variant="outline" size="sm" onClick={() => openEdit(s)}>Modifier</Button>
                          <Button variant="ghost" size="sm" onClick={() => setHistoriqueDe(s)}>
                            <History className="h-4 w-4" />
                          </Button>
                        </TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        </div>

        <Dialog open={open} onOpenChange={setOpen}>
          <DialogContent className="max-w-3xl max-h-[85vh] overflow-y-auto">
            <DialogHeader>
              <DialogTitle>{form.id ? "Modifier le suivi" : "Nouveau suivi AgriPlant"}</DialogTitle>
            </DialogHeader>
            <Tabs defaultValue="infos">
              <TabsList>
                <TabsTrigger value="infos">Informations</TabsTrigger>
                <TabsTrigger value="fichiers">Photos & documents</TabsTrigger>
              </TabsList>

              <TabsContent value="infos" className="grid gap-4 sm:grid-cols-2">
                <div className="sm:col-span-2">
                  <Label>Plantation *</Label>
                  <Select value={form.plantation_id} onValueChange={(v) => set("plantation_id", v)}>
                    <SelectTrigger><SelectValue placeholder="Sélectionner une plantation" /></SelectTrigger>
                    <SelectContent>
                      {(plantations as any[]).map((p) => (
                        <SelectItem key={p.id} value={p.id}>{nomPlantation(p)}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div>
                  <Label>Type de suivi</Label>
                  <Select value={form.type_suivi} onValueChange={(v) => set("type_suivi", v)}>
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent>
                      {TYPES_SUIVI.map((t) => <SelectItem key={t.v} value={t.v}>{t.l}</SelectItem>)}
                    </SelectContent>
                  </Select>
                </div>
                <div>
                  <Label>Statut</Label>
                  <Select value={form.statut} onValueChange={(v) => set("statut", v)}>
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent>
                      {STATUTS.map((s) => <SelectItem key={s.v} value={s.v}>{s.l}</SelectItem>)}
                    </SelectContent>
                  </Select>
                </div>
                <div className="sm:col-span-2">
                  <Label>Titre *</Label>
                  <Input value={form.titre} onChange={(e) => set("titre", e.target.value)} />
                </div>
                <div>
                  <Label>Date de visite</Label>
                  <Input type="date" value={form.date_visite} onChange={(e) => set("date_visite", e.target.value)} />
                </div>
                <div>
                  <Label>Prochaine visite</Label>
                  <Input type="date" value={form.prochaine_visite} onChange={(e) => set("prochaine_visite", e.target.value)} />
                </div>
                <div>
                  <Label>Responsable</Label>
                  <Select value={form.responsable_id} onValueChange={(v) => set("responsable_id", v)}>
                    <SelectTrigger><SelectValue placeholder="Sélectionner" /></SelectTrigger>
                    <SelectContent>
                      {(responsables as any[]).filter((r) => r.user_id).map((r) => (
                        <SelectItem key={r.id} value={r.user_id}>{r.nom_complet}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div>
                  <Label>Note de santé (0-10)</Label>
                  <Input type="number" min="0" max="10" value={form.note_sante} onChange={(e) => set("note_sante", e.target.value)} />
                </div>
                <div className="sm:col-span-2">
                  <Label>Météo</Label>
                  <Input value={form.meteo} onChange={(e) => set("meteo", e.target.value)} placeholder="Ex : ensoleillé, pluies fréquentes..." />
                </div>
                <div className="sm:col-span-2">
                  <Label>Observations</Label>
                  <Textarea rows={4} value={form.observations} onChange={(e) => set("observations", e.target.value)} />
                </div>
                <div className="sm:col-span-2">
                  <Label>Actions recommandées</Label>
                  <Textarea rows={3} value={form.actions_recommandees} onChange={(e) => set("actions_recommandees", e.target.value)} />
                </div>
              </TabsContent>

              <TabsContent value="fichiers" className="space-y-6">
                <div className="space-y-2">
                  <Label>Photos de terrain</Label>
                  <Input
                    type="file"
                    accept="image/*"
                    disabled={uploading}
                    onChange={(e) => { const f = e.target.files?.[0]; if (f) upload(f, "photos"); e.target.value = ""; }}
                  />
                  <ul className="space-y-1 text-sm">
                    {photos.map((p) => (
                      <li key={p.chemin} className="flex items-center justify-between rounded border px-3 py-2">
                        <span className="flex items-center gap-2"><Upload className="h-4 w-4" /> {p.nom}</span>
                        <Button variant="ghost" size="sm" onClick={() => setPhotos((l) => l.filter((x) => x.chemin !== p.chemin))}>Retirer</Button>
                      </li>
                    ))}
                  </ul>
                </div>
                <div className="space-y-2">
                  <Label>Documents</Label>
                  <Input
                    type="file"
                    disabled={uploading}
                    onChange={(e) => { const f = e.target.files?.[0]; if (f) upload(f, "documents"); e.target.value = ""; }}
                  />
                  <ul className="space-y-1 text-sm">
                    {documents.map((d) => (
                      <li key={d.chemin} className="flex items-center justify-between rounded border px-3 py-2">
                        <span className="flex items-center gap-2"><FileText className="h-4 w-4" /> {d.nom}</span>
                        <Button variant="ghost" size="sm" onClick={() => setDocuments((l) => l.filter((x) => x.chemin !== d.chemin))}>Retirer</Button>
                      </li>
                    ))}
                  </ul>
                </div>
              </TabsContent>
            </Tabs>
            <DialogFooter>
              <Button variant="outline" onClick={() => setOpen(false)}>Annuler</Button>
              <Button onClick={() => save.mutate()} disabled={save.isPending || uploading}>
                {save.isPending && <Loader2 className="mr-2 h-4 w-4 animate-spin" />} Enregistrer
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>

        <Dialog open={!!historiqueDe} onOpenChange={(o) => !o && setHistoriqueDe(null)}>
          <DialogContent className="max-w-2xl max-h-[80vh] overflow-y-auto">
            <DialogHeader><DialogTitle>Historique — {historiqueDe?.titre}</DialogTitle></DialogHeader>
            <div className="space-y-2">
              {historique.length === 0 && <p className="text-sm text-muted-foreground">Aucun évènement.</p>}
              {(historique as any[]).map((h) => (
                <Card key={h.id}>
                  <CardContent className="space-y-1 py-3 text-sm">
                    <p className="font-medium">{h.action}</p>
                    <p className="text-xs text-muted-foreground">
                      {format(new Date(h.created_at), "dd/MM/yyyy HH:mm", { locale: fr })} — {nomResponsable(h.acteur_id)}
                    </p>
                    {h.champ && (
                      <p className="text-xs">{h.champ} : {h.ancienne_valeur || "—"} → {h.nouvelle_valeur || "—"}</p>
                    )}
                    {h.commentaire && <p className="text-xs">{h.commentaire}</p>}
                  </CardContent>
                </Card>
              ))}
            </div>
          </DialogContent>
        </Dialog>
      </MainLayout>
    </ProtectedRoute>
  );
};

export default AgriPlantPage;
