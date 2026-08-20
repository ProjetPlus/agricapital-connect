import { useEffect, useMemo, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Plus, Mail, MessageSquare, Edit, Bell, Search, Smartphone } from "lucide-react";
import { toast } from "sonner";

interface Template {
  id: string;
  code: string;
  nom: string;
  canal: string;
  evenement: string;
  sujet: string | null;
  contenu: string;
  variables: string[];
  parcours: string;
  actif: boolean;
}

const CANAUX = [
  { v: "email", l: "Email" },
  { v: "sms", l: "SMS" },
  { v: "whatsapp", l: "WhatsApp" },
  { v: "push", l: "Notification app" },
];

const PARCOURS = [
  { v: "commun", l: "Commun" },
  { v: "palminvest", l: "PalmInvest" },
  { v: "terrapalm", l: "TerraPalm" },
  { v: "agriplan", l: "AgriPlan" },
];

const EVENEMENTS = [
  { v: "souscription_nouvelle", l: "Nouvelle souscription" },
  { v: "souscription_confirmee", l: "Souscription confirmée" },
  { v: "paiement_recu", l: "Paiement reçu" },
  { v: "paiement_valide", l: "Paiement validé" },
  { v: "paiement_rappel", l: "Rappel de paiement" },
  { v: "paiement_retard", l: "Retard de paiement" },
  { v: "echeance_proche", l: "Échéance proche" },
  { v: "solde_contrat", l: "Solde du contrat" },
  { v: "solde_palminvest", l: "Solde PalmInvest" },
  { v: "solde_terrapalm", l: "Solde TerraPalm" },
  { v: "visite_technique_rdv", l: "Rendez-vous de visite technique" },
  { v: "visite_technique_realisee", l: "Visite technique réalisée" },
  { v: "plantation_nouvelle", l: "Nouvelle plantation" },
  { v: "recolte_nouvelle", l: "Nouvelle récolte" },
  { v: "agriplan_vente_nouvelle", l: "Nouvelle vente AgriPlan" },
  { v: "agriplan_paiement", l: "Paiement AgriPlan" },
  { v: "agriplan_solde", l: "Solde AgriPlan" },
  { v: "agriplan_relance_lead", l: "Relance prospect AgriPlan" },
  { v: "compte_cree", l: "Compte utilisateur créé" },
  { v: "compte_approuve", l: "Demande de compte approuvée" },
  { v: "document_valide", l: "Documents validés" },
];

const VARIABLES_COURANTES = [
  "nom", "numero_contrat", "numero_client", "offre", "superficie", "montant", "montant_total",
  "total_paye", "solde", "depot_initial", "date", "date_echeance", "jours_retard", "reference",
  "plantation", "localite", "technicien", "date_visite", "etat", "recommandations", "quantite",
  "conseiller", "identifiant", "role", "poste", "libelle", "mise_en_place",
];

const vide = (): Partial<Template> => ({
  code: "", nom: "", canal: "email", evenement: "souscription_nouvelle",
  sujet: "", contenu: "", variables: [], parcours: "commun", actif: true,
});

const GestionNotifications = () => {
  const [templates, setTemplates] = useState<Template[]>([]);
  const [loading, setLoading] = useState(true);
  const [q, setQ] = useState("");
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState<Partial<Template>>(vide());

  const load = async () => {
    setLoading(true);
    const { data, error } = await (supabase as any)
      .from("notification_templates")
      .select("*")
      .order("parcours")
      .order("evenement");
    if (error) toast.error("Chargement impossible : " + error.message);
    setTemplates(((data || []) as any[]).map((t) => ({ ...t, variables: Array.isArray(t.variables) ? t.variables : [] })));
    setLoading(false);
  };

  useEffect(() => { load(); }, []);

  const visibles = useMemo(
    () => templates.filter((t) =>
      !q.trim() || [t.nom, t.code, t.evenement, t.contenu].join(" ").toLowerCase().includes(q.toLowerCase())),
    [templates, q],
  );

  const detecterVariables = (contenu: string, sujet?: string | null) => {
    const found = new Set<string>();
    for (const m of `${sujet || ""} ${contenu}`.matchAll(/\{([a-z0-9_]+)\}/gi)) found.add(m[1]);
    return Array.from(found);
  };

  const enregistrer = async () => {
    if (!form.nom?.trim() || !form.contenu?.trim()) {
      toast.error("Nom et contenu obligatoires");
      return;
    }
    const payload = {
      code: (form.code || form.evenement || form.nom)!.toLowerCase().replace(/[^a-z0-9_]+/g, "_"),
      nom: form.nom,
      canal: form.canal,
      evenement: form.evenement,
      sujet: form.sujet || null,
      contenu: form.contenu,
      parcours: form.parcours,
      actif: form.actif ?? true,
      variables: detecterVariables(form.contenu!, form.sujet),
    };
    const res = form.id
      ? await (supabase as any).from("notification_templates").update(payload).eq("id", form.id)
      : await (supabase as any).from("notification_templates").insert(payload);
    if (res.error) {
      toast.error(res.error.message);
      return;
    }
    toast.success(form.id ? "Template mis à jour" : "Template créé");
    setOpen(false);
    setForm(vide());
    load();
  };

  const basculer = async (t: Template) => {
    const { error } = await (supabase as any)
      .from("notification_templates").update({ actif: !t.actif }).eq("id", t.id);
    if (error) { toast.error(error.message); return; }
    load();
  };

  const icone = (canal: string) =>
    canal === "email" ? <Mail className="h-4 w-4" />
      : canal === "push" ? <Bell className="h-4 w-4" />
        : canal === "sms" ? <Smartphone className="h-4 w-4" />
          : <MessageSquare className="h-4 w-4" />;

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <CardTitle className="flex items-center gap-2"><Bell className="h-5 w-5" />Templates de notification</CardTitle>
              <CardDescription>
                Messages automatiques envoyés aux souscripteurs et clients (souscription, paiements, retards, visites, récoltes, AgriPlan…).
              </CardDescription>
            </div>
            <Button onClick={() => { setForm(vide()); setOpen(true); }}>
              <Plus className="mr-2 h-4 w-4" />Nouveau template
            </Button>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="relative w-full max-w-sm">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input className="pl-9" placeholder="Rechercher un template..." value={q} onChange={(e) => setQ(e.target.value)} />
          </div>

          <div className="overflow-x-auto rounded-lg border">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Template</TableHead>
                  <TableHead>Canal</TableHead>
                  <TableHead>Parcours</TableHead>
                  <TableHead>Événement</TableHead>
                  <TableHead className="min-w-[280px]">Message</TableHead>
                  <TableHead>Actif</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {visibles.map((t) => (
                  <TableRow key={t.id}>
                    <TableCell>
                      <div className="flex items-center gap-2">{icone(t.canal)}<span className="font-medium">{t.nom}</span></div>
                      <code className="text-xs text-muted-foreground">{t.code}</code>
                    </TableCell>
                    <TableCell><Badge variant="outline">{CANAUX.find((c) => c.v === t.canal)?.l || t.canal}</Badge></TableCell>
                    <TableCell><Badge variant="secondary">{PARCOURS.find((p) => p.v === t.parcours)?.l || t.parcours}</Badge></TableCell>
                    <TableCell className="text-sm text-muted-foreground">
                      {EVENEMENTS.find((e) => e.v === t.evenement)?.l || t.evenement}
                    </TableCell>
                    <TableCell className="max-w-[380px] text-sm text-muted-foreground">
                      <span className="line-clamp-2">{t.contenu}</span>
                    </TableCell>
                    <TableCell><Switch checked={t.actif} onCheckedChange={() => basculer(t)} /></TableCell>
                    <TableCell className="text-right">
                      <Button variant="ghost" size="sm" onClick={() => { setForm(t); setOpen(true); }}>
                        <Edit className="h-4 w-4" />
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
                {!loading && visibles.length === 0 && (
                  <TableRow><TableCell colSpan={7} className="py-8 text-center text-muted-foreground">Aucun template</TableCell></TableRow>
                )}
              </TableBody>
            </Table>
          </div>
        </CardContent>
      </Card>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-h-[90vh] max-w-2xl overflow-y-auto">
          <DialogHeader>
            <DialogTitle>{form.id ? "Modifier le template" : "Nouveau template"}</DialogTitle>
            <DialogDescription>Utilisez {"{variable}"} pour insérer des données dynamiques.</DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label>Nom du template</Label>
                <Input value={form.nom || ""} onChange={(e) => setForm({ ...form, nom: e.target.value })} placeholder="Ex : Rappel de paiement" />
              </div>
              <div className="space-y-2">
                <Label>Canal</Label>
                <Select value={form.canal} onValueChange={(v) => setForm({ ...form, canal: v })}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>{CANAUX.map((c) => <SelectItem key={c.v} value={c.v}>{c.l}</SelectItem>)}</SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label>Événement déclencheur</Label>
                <Select value={form.evenement} onValueChange={(v) => setForm({ ...form, evenement: v })}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>{EVENEMENTS.map((e) => <SelectItem key={e.v} value={e.v}>{e.l}</SelectItem>)}</SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label>Parcours / offre</Label>
                <Select value={form.parcours} onValueChange={(v) => setForm({ ...form, parcours: v })}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>{PARCOURS.map((p) => <SelectItem key={p.v} value={p.v}>{p.l}</SelectItem>)}</SelectContent>
                </Select>
              </div>
            </div>
            <div className="space-y-2">
              <Label>Sujet (email)</Label>
              <Input value={form.sujet || ""} onChange={(e) => setForm({ ...form, sujet: e.target.value })} />
            </div>
            <div className="space-y-2">
              <Label>Contenu du message</Label>
              <Textarea rows={6} value={form.contenu || ""} onChange={(e) => setForm({ ...form, contenu: e.target.value })}
                placeholder="Bonjour {nom}, bienvenue chez AgriCapital..." />
              <div className="flex flex-wrap gap-1">
                {VARIABLES_COURANTES.map((v) => (
                  <button key={v} type="button" className="rounded bg-muted px-1.5 py-0.5 text-xs hover:bg-muted/70"
                    onClick={() => setForm((f) => ({ ...f, contenu: `${f.contenu || ""}{${v}}` }))}>
                    {"{" + v + "}"}
                  </button>
                ))}
              </div>
            </div>
            <div className="flex items-center gap-2">
              <Switch checked={form.actif ?? true} onCheckedChange={(v) => setForm({ ...form, actif: v })} />
              <Label>Template actif</Label>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>Annuler</Button>
            <Button onClick={enregistrer}>Enregistrer</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
};

export default GestionNotifications;
