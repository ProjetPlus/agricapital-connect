import { useState, useEffect, useMemo } from "react";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/useAuth";
import { useToast } from "@/hooks/use-toast";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Search, UserCheck, Sprout } from "lucide-react";
import { getSafeErrorMessage } from "@/lib/safeError";

interface PlantationFormProps {
  plantation?: any;
  onSuccess: () => void;
  onCancel: () => void;
}

/**
 * Conversion d'un Souscripteur (déjà associé à une parcelle) en Plantation.
 * — Recherche & sélection du souscripteur (auto-remplissage)
 * — Champs manuels uniquement pour : nom plantation, date plantation, variété, notes
 */
const PlantationForm = ({ plantation, onSuccess, onCancel }: PlantationFormProps) => {
  const { user } = useAuth();
  const { toast } = useToast();
  const [loading, setLoading] = useState(false);

  // Recherche souscripteur
  const [search, setSearch] = useState("");
  const [souscripteurs, setSouscripteurs] = useState<any[]>([]);
  const [selected, setSelected] = useState<any>(null);

  // Champs manuels
  const [nomPlantation, setNomPlantation] = useState(plantation?.nom_plantation || "");
  const [datePlantation, setDatePlantation] = useState(plantation?.date_plantation || "");
  const [typeCulture, setTypeCulture] = useState(plantation?.type_culture || "Palmier à huile");
  const [variete, setVariete] = useState(plantation?.variete || "Tenera");
  const [notes, setNotes] = useState(plantation?.notes_internes || "");

  // Préchargement en mode édition
  useEffect(() => {
    if (plantation?.souscripteur_id) {
      (async () => {
        const { data } = await (supabase as any)
          .from("souscripteurs")
          .select("*, offres(nom, code), parcelles:parcelle_id(id, id_unique, nom, village, surface_disponible_ha, district_id, region_id, departement_id, sous_prefecture_id)")
          .eq("id", plantation.souscripteur_id)
          .single();
        if (data) setSelected(data);
      })();
    }
  }, [plantation?.souscripteur_id]);

  // Recherche debouncée
  useEffect(() => {
    if (selected) return;
    const t = setTimeout(async () => {
      let query = (supabase as any)
        .from("souscripteurs")
        .select("id, id_unique, nom, prenoms, nom_complet, telephone, parcelle_id, offre_id, district_id, region_id, departement_id, sous_prefecture_id")
        .order("created_at", { ascending: false })
        .limit(20);
      if (search.trim()) {
        query = query.or(
          `id_unique.ilike.%${search}%,nom.ilike.%${search}%,prenoms.ilike.%${search}%,nom_complet.ilike.%${search}%,telephone.ilike.%${search}%`
        );
      }
      const { data } = await query;
      setSouscripteurs(data || []);
    }, 250);
    return () => clearTimeout(t);
  }, [search, selected]);

  const handleSelect = async (s: any) => {
    // Charger les détails de la parcelle associée si présente
    let parcelle: any = null;
    if (s.parcelle_id) {
      const { data } = await (supabase as any)
        .from("parcelles")
        .select("id, id_unique, nom, village, surface_disponible_ha, surface_agricapital_ha, district_id, region_id, departement_id, sous_prefecture_id, localisation_gps_lat, localisation_gps_lng")
        .eq("id", s.parcelle_id)
        .single();
      parcelle = data;
    }
    setSelected({ ...s, parcelles: parcelle });
    setNomPlantation(`Plantation ${s.nom_complet || s.nom}`);
  };

  const autofilled = useMemo(() => {
    if (!selected) return null;
    const p = selected.parcelles;
    return {
      souscripteur_id: selected.id,
      parcelle_id: selected.parcelle_id || null,
      district_id: p?.district_id || selected.district_id || null,
      region_id: p?.region_id || selected.region_id || null,
      departement_id: p?.departement_id || selected.departement_id || null,
      sous_prefecture_id: p?.sous_prefecture_id || selected.sous_prefecture_id || null,
      village_nom: p?.village || null,
      latitude: p?.localisation_gps_lat || null,
      longitude: p?.localisation_gps_lng || null,
      superficie_ha: p?.surface_disponible_ha || 1,
    };
  }, [selected]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;
    if (!selected) {
      toast({ variant: "destructive", title: "Souscripteur requis", description: "Recherchez et sélectionnez un souscripteur avant de convertir." });
      return;
    }
    setLoading(true);
    try {
      const payload = {
        ...autofilled,
        nom: nomPlantation,
        nom_plantation: nomPlantation,
        date_plantation: datePlantation || null,
        type_culture: typeCulture,
        variete: variete || null,
        notes_internes: notes || null,
      };

      if (plantation) {
        const { error } = await (supabase as any)
          .from("plantations")
          .update(payload)
          .eq("id", plantation.id);
        if (error) throw error;
        toast({ title: "Plantation modifiée" });
      } else {
        const { error } = await (supabase as any)
          .from("plantations")
          .insert({
            ...payload,
            created_by: user.id,
            statut: "actif",
            statut_global: "en_attente_da",
          });
        if (error) throw error;
        toast({ title: "✅ Souscripteur converti en plantation", description: nomPlantation });
      }
      onSuccess();
    } catch (error: any) {
      toast({ variant: "destructive", title: "Erreur", description: getSafeErrorMessage(error) });
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      {/* 1. Sélection du souscripteur */}
      <Card className="border-primary/40">
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-base">
            <UserCheck className="h-5 w-5 text-primary" /> 1. Sélectionner le souscripteur à convertir
          </CardTitle>
          <CardDescription>
            Recherchez par ID, nom, téléphone. Les informations de la parcelle associée seront auto-remplies.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          {!selected ? (
            <>
              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                <Input
                  className="pl-9"
                  placeholder="Rechercher un souscripteur..."
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  autoFocus
                />
              </div>
              <div className="border rounded-lg max-h-72 overflow-y-auto divide-y">
                {souscripteurs.length === 0 ? (
                  <div className="p-4 text-center text-sm text-muted-foreground">
                    Aucun souscripteur trouvé
                  </div>
                ) : souscripteurs.map((s) => (
                  <button
                    type="button"
                    key={s.id}
                    onClick={() => handleSelect(s)}
                    className="w-full text-left p-3 hover:bg-accent/50 transition-colors flex items-center justify-between gap-3"
                  >
                    <div className="min-w-0">
                      <div className="font-medium truncate">
                        {s.nom_complet || `${s.nom} ${s.prenoms || ""}`}
                      </div>
                      <div className="text-xs text-muted-foreground">
                        {s.id_unique} · {s.telephone || "—"}
                      </div>
                    </div>
                    {s.parcelle_id ? (
                      <Badge variant="outline" className="shrink-0">Parcelle ✓</Badge>
                    ) : (
                      <Badge variant="secondary" className="shrink-0">Sans parcelle</Badge>
                    )}
                  </button>
                ))}
              </div>
            </>
          ) : (
            <div className="rounded-lg border bg-primary/5 p-3 flex items-start justify-between gap-3">
              <div className="text-sm space-y-0.5">
                <div className="font-semibold">{selected.nom_complet || `${selected.nom} ${selected.prenoms || ""}`}</div>
                <div className="text-xs text-muted-foreground">
                  {selected.id_unique} · {selected.telephone}
                </div>
                {selected.parcelles && (
                  <div className="text-xs mt-1">
                    Parcelle : <span className="font-mono">{selected.parcelles.id_unique}</span>
                    {selected.parcelles.village ? ` · ${selected.parcelles.village}` : ""}
                    {selected.parcelles.surface_disponible_ha ? ` · ${selected.parcelles.surface_disponible_ha} ha dispo` : ""}
                  </div>
                )}
              </div>
              <Button type="button" variant="ghost" size="sm" onClick={() => { setSelected(null); setNomPlantation(""); }}>
                Changer
              </Button>
            </div>
          )}
        </CardContent>
      </Card>

      {/* 2. Informations spécifiques à la plantation */}
      {selected && (
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-base">
              <Sprout className="h-5 w-5 text-primary" /> 2. Informations de la plantation
            </CardTitle>
            <CardDescription>Seuls les champs propres à la plantation restent à saisir.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label>Nom de la plantation *</Label>
                <Input value={nomPlantation} onChange={(e) => setNomPlantation(e.target.value)} required />
              </div>
              <div className="space-y-2">
                <Label>Date de plantation</Label>
                <Input type="date" value={datePlantation} onChange={(e) => setDatePlantation(e.target.value)} />
              </div>
              <div className="space-y-2">
                <Label>Type de culture</Label>
                <Select value={typeCulture} onValueChange={setTypeCulture}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="Palmier à huile">Palmier à huile</SelectItem>
                    <SelectItem value="Hévéa">Hévéa</SelectItem>
                    <SelectItem value="Cacao">Cacao</SelectItem>
                    <SelectItem value="Café">Café</SelectItem>
                    <SelectItem value="Autre">Autre</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label>Variété</Label>
                <Input value={variete} onChange={(e) => setVariete(e.target.value)} placeholder="Ex: Tenera" />
              </div>
            </div>

            <div className="space-y-2">
              <Label>Notes internes</Label>
              <Textarea value={notes} onChange={(e) => setNotes(e.target.value)} rows={3} />
            </div>

            {autofilled && (
              <div className="rounded-lg bg-muted/50 p-3 text-xs space-y-1">
                <div className="font-semibold mb-1">Auto-rempli depuis le souscripteur :</div>
                <div>Superficie : {autofilled.superficie_ha} ha</div>
                {autofilled.village_nom && <div>Village : {autofilled.village_nom}</div>}
                {autofilled.latitude && <div>GPS : {autofilled.latitude}, {autofilled.longitude}</div>}
              </div>
            )}
          </CardContent>
        </Card>
      )}

      <div className="flex justify-end gap-3">
        <Button type="button" variant="outline" onClick={onCancel}>Annuler</Button>
        <Button type="submit" disabled={loading || !selected}>
          {loading ? "Conversion..." : plantation ? "Modifier" : "Convertir en plantation"}
        </Button>
      </div>
    </form>
  );
};

export default PlantationForm;