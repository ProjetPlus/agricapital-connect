import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useToast } from "@/hooks/use-toast";
import { supabase } from "@/integrations/supabase/client";
import logoGreen from "@/assets/logo-green.png";
import { User, Mail, Phone, Briefcase, MapPin, FileText, KeyRound, AtSign } from "lucide-react";
import { getSafeErrorMessage } from "@/lib/safeError";

const ROLES = [
  { value: "commercial", label: "Commercial (Comm)" },
  { value: "technicien", label: "Technicien (Tech)" },
  { value: "chef_equipe_commercial", label: "Chef d'Équipe Commercial (CEC)" },
  { value: "chef_equipe_technique", label: "Chef d'Équipe Technique (CET)" },
  { value: "responsable_commercial", label: "Responsable Commercial (RCom)" },
  { value: "responsable_technique_agronomique", label: "Responsable Technique & Agronomique (RTA)" },
  { value: "responsable_zone", label: "Responsable de zone" },
  { value: "comptable", label: "Comptable" },
  { value: "service_client", label: "Service client / Support" },
  { value: "operations", label: "Opérations" }
];

const AccountRequest = () => {
  const [formData, setFormData] = useState({
    nom_complet: "",
    email: "",
    telephone: "",
    poste: "",
    region: "",
    departement: "",
    district: "",
    message: "",
    username: "",
    password: "",
    password_confirm: "",
  });
  const [ownerInfo, setOwnerInfo] = useState<any>(null);
  const [errorDetail, setErrorDetail] = useState<any>(null);
  
  const [regions, setRegions] = useState<any[]>([]);
  const [departements, setDepartements] = useState<any[]>([]);
  const [districts, setDistricts] = useState<any[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const { toast } = useToast();
  const navigate = useNavigate();

  // Fetch districts on mount
  useEffect(() => {
    const fetchDistricts = async () => {
      const { data } = await (supabase as any)
        .from('districts')
        .select('*')
        .eq('est_actif', true)
        .order('nom');
      setDistricts(data || []);
    };
    fetchDistricts();
  }, []);

  // Fetch regions when district changes
  useEffect(() => {
    const fetchRegions = async () => {
      if (formData.district) {
        const { data } = await (supabase as any)
          .from('regions')
          .select('*')
          .eq('district_id', formData.district)
          .eq('est_active', true)
          .order('nom');
        setRegions(data || []);
        setFormData(prev => ({ ...prev, region: "", departement: "" }));
        setDepartements([]);
      } else {
        setRegions([]);
      }
    };
    fetchRegions();
  }, [formData.district]);

  // Fetch departements when region changes
  useEffect(() => {
    const fetchDepartements = async () => {
      if (formData.region) {
        const { data } = await (supabase as any)
          .from('departements')
          .select('*')
          .eq('region_id', formData.region)
          .eq('est_actif', true)
          .order('nom');
        setDepartements(data || []);
        setFormData(prev => ({ ...prev, departement: "" }));
      } else {
        setDepartements([]);
      }
    };
    fetchDepartements();
  }, [formData.region]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setOwnerInfo(null);
    setErrorDetail(null);

    if (formData.password !== formData.password_confirm) {
      toast({ variant: "destructive", title: "Erreur", description: "Les mots de passe ne correspondent pas." });
      return;
    }
    if (formData.password.length < 8) {
      toast({ variant: "destructive", title: "Erreur", description: "Le mot de passe doit contenir au moins 8 caractères." });
      return;
    }

    setIsSubmitting(true);

    try {
      // Get region/department/district names for storage
      const regionName = regions.find(r => r.id === formData.region)?.nom || "";
      const deptName = departements.find(d => d.id === formData.departement)?.nom || "";

      // Création de la demande + du compte (inactif jusqu'à validation admin)
      const { data, error } = await supabase.functions.invoke('submit-account-request', {
        body: {
          nom_complet: formData.nom_complet,
          email: formData.email,
          telephone: formData.telephone,
          username: formData.username,
          password: formData.password,
          poste_souhaite: ROLES.find((role) => role.value === formData.poste)?.label || formData.poste,
          role_souhaite: formData.poste,
          region_id: formData.region || null,
          departement_geo_id: formData.departement || null,
          district_id: formData.district || null,
          departement: deptName || null,
          justification: formData.message || null,
        },
      });

      const payload: any = data;
      if (error || payload?.error) {
        if (payload?.owner) setOwnerInfo(payload.owner);
        let functionMessage = error?.message;
        let contextPayload: any = null;
        if (error && typeof (error as any).context?.json === "function") {
          try {
            contextPayload = await (error as any).context.json();
            functionMessage = contextPayload?.message || contextPayload?.error || functionMessage;
            if (contextPayload?.owner) setOwnerInfo(contextPayload.owner);
          } catch { /* la réponse n'est pas JSON */ }
        }
        const detail = contextPayload || payload || {};
        setErrorDetail({
          etape: detail?.step || "inconnue",
          raison: detail?.message || detail?.error || functionMessage || "Erreur inconnue",
          statut_http: (error as any)?.context?.status ?? null,
          donnees_envoyees: {
            username: formData.username,
            email: formData.email,
            telephone: formData.telephone,
            role_souhaite: formData.poste,
            region_id: formData.region || null,
            departement_geo_id: formData.departement || null,
            district_id: formData.district || null,
          },
          horodatage: new Date().toISOString(),
        });
        console.error("[demande-compte] échec", detail);
        throw new Error(payload?.message || payload?.error || functionMessage || "Envoi impossible");
      }

      // La notification aux administrateurs est envoyée côté serveur par submit-account-request.

      toast({
        title: payload?.immediate_access ? "Compte créé" : "Demande envoyée",
        description: payload?.immediate_access
          ? "Votre accès est actif : connectez-vous dès maintenant avec votre identifiant et votre mot de passe."
          : "Dès validation par l'administrateur, connectez-vous avec votre identifiant et votre mot de passe.",
      });

      navigate('/login');
    } catch (error: any) {
      console.error('Error:', error);
      toast({
        variant: "destructive",
        title: "Erreur",
        description: getSafeErrorMessage(error) || "Impossible d'envoyer la demande",
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-primary via-primary to-primary-hover p-3 sm:p-4">
      <Card className="w-full max-w-[95%] sm:max-w-2xl shadow-strong my-4">
        <CardHeader className="text-center px-4 sm:px-6 pb-4">
          <div className="flex justify-center mb-2 sm:mb-4">
            <img src={logoGreen} alt="AgriCapital Logo" className="h-16 sm:h-24 w-auto" />
          </div>
          <CardTitle className="text-xl sm:text-2xl">Demande de Création de Compte</CardTitle>
          <CardDescription className="text-xs sm:text-sm">
            Remplissez ce formulaire pour demander un accès à AgriCapital
          </CardDescription>
        </CardHeader>

        <CardContent className="px-4 sm:px-6">
          <form onSubmit={handleSubmit} className="space-y-4 sm:space-y-6">
            {/* Informations personnelles */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 sm:gap-4">
              <div className="space-y-1.5">
                <Label htmlFor="nom_complet" className="text-sm flex items-center gap-2">
                  <User className="h-3.5 w-3.5" /> Nom complet *
                </Label>
                <Input
                  id="nom_complet"
                  required
                  className="h-10"
                  value={formData.nom_complet}
                  onChange={(e) => setFormData({...formData, nom_complet: e.target.value})}
                  placeholder="Ex: KOUASSI Jean"
                />
              </div>

              <div className="space-y-1.5">
                <Label htmlFor="email" className="text-sm flex items-center gap-2">
                  <Mail className="h-3.5 w-3.5" /> Email *
                </Label>
                <Input
                  id="email"
                  type="email"
                  required
                  className="h-10"
                  value={formData.email}
                  onChange={(e) => setFormData({...formData, email: e.target.value})}
                  placeholder="votre@email.com"
                />
              </div>

              <div className="space-y-1.5">
                <Label htmlFor="telephone" className="text-sm flex items-center gap-2">
                  <Phone className="h-3.5 w-3.5" /> Téléphone *
                </Label>
                <Input
                  id="telephone"
                  type="tel"
                  required
                  className="h-10"
                  value={formData.telephone}
                  onChange={(e) => setFormData({...formData, telephone: e.target.value})}
                  placeholder="07 XX XX XX XX"
                />
              </div>

              <div className="space-y-1.5">
                <Label htmlFor="poste" className="text-sm flex items-center gap-2">
                  <Briefcase className="h-3.5 w-3.5" /> Poste souhaité *
                </Label>
                <Select
                  value={formData.poste}
                  onValueChange={(value) => setFormData({...formData, poste: value})}
                >
                  <SelectTrigger className="h-10">
                    <SelectValue placeholder="Sélectionner un poste" />
                  </SelectTrigger>
                  <SelectContent>
                    {ROLES.map(role => (
                      <SelectItem key={role.value} value={role.value}>
                        {role.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>

            {/* Localisation */}
            <div className="space-y-3">
              <Label className="text-sm font-medium flex items-center gap-2">
                <MapPin className="h-4 w-4" /> Localisation
              </Label>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <Select
                  value={formData.district}
                  onValueChange={(value) => setFormData({...formData, district: value})}
                >
                  <SelectTrigger className="h-10">
                    <SelectValue placeholder="District" />
                  </SelectTrigger>
                  <SelectContent>
                    {districts.map(dist => (
                      <SelectItem key={dist.id} value={dist.id}>
                        {dist.nom}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>

                <Select
                  value={formData.region}
                  onValueChange={(value) => setFormData({...formData, region: value})}
                  disabled={!formData.district}
                >
                  <SelectTrigger className="h-10">
                    <SelectValue placeholder="Région" />
                  </SelectTrigger>
                  <SelectContent>
                    {regions.map(region => (
                      <SelectItem key={region.id} value={region.id}>
                        {region.nom}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>

                <Select
                  value={formData.departement}
                  onValueChange={(value) => setFormData({...formData, departement: value})}
                  disabled={!formData.region}
                >
                  <SelectTrigger className="h-10">
                    <SelectValue placeholder="Département" />
                  </SelectTrigger>
                  <SelectContent>
                    {departements.map(dept => (
                      <SelectItem key={dept.id} value={dept.id}>
                        {dept.nom}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>

            {/* Identifiants de connexion */}
            <div className="space-y-3 rounded-lg border-2 border-primary/30 bg-primary/5 p-4">
              <Label className="text-sm font-semibold flex items-center gap-2">
                <KeyRound className="h-4 w-4" /> Identifiants de connexion *
              </Label>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div className="space-y-1.5">
                  <Label htmlFor="username" className="text-xs flex items-center gap-1">
                    <AtSign className="h-3 w-3" /> Nom d'utilisateur *
                  </Label>
                  <Input
                    id="username"
                    required
                    className="h-10"
                    autoComplete="username"
                    value={formData.username}
                    onChange={(e) => setFormData({ ...formData, username: e.target.value.toLowerCase().replace(/\s/g, '') })}
                    placeholder="ex: kouassi.jean"
                  />
                </div>
                <div className="space-y-1.5">
                  <Label htmlFor="password" className="text-xs">Mot de passe *</Label>
                  <Input
                    id="password"
                    type="password"
                    required
                    minLength={8}
                    className="h-10"
                    autoComplete="new-password"
                    value={formData.password}
                    onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                    placeholder="8 caractères minimum"
                  />
                </div>
                <div className="space-y-1.5">
                  <Label htmlFor="password_confirm" className="text-xs">Confirmer *</Label>
                  <Input
                    id="password_confirm"
                    type="password"
                    required
                    className="h-10"
                    autoComplete="new-password"
                    value={formData.password_confirm}
                    onChange={(e) => setFormData({ ...formData, password_confirm: e.target.value })}
                    placeholder="Répéter le mot de passe"
                  />
                </div>
              </div>
              <p className="text-xs text-muted-foreground">
                Commerciaux et techniciens : l'accès est activé immédiatement après l'envoi du formulaire.
                Les autres rôles restent en attente de validation par l'administrateur.
              </p>
            </div>

            {ownerInfo && (
              <div className="rounded-lg border-2 border-destructive/40 bg-destructive/5 p-4 space-y-2">
                <p className="text-sm font-semibold text-destructive">Cet email est déjà attribué</p>
                <div className="flex items-center gap-3">
                  {ownerInfo.photo_url && (
                    <img src={ownerInfo.photo_url} alt={ownerInfo.nom_complet} className="h-14 w-14 rounded-full object-cover" />
                  )}
                  <div className="text-sm">
                    <p className="font-medium">{ownerInfo.nom_complet}</p>
                    <p className="text-muted-foreground text-xs">{ownerInfo.email} • {ownerInfo.telephone || '—'}</p>
                    <p className="text-muted-foreground text-xs">{ownerInfo.poste || ''} {ownerInfo.username ? `(@${ownerInfo.username})` : ''}</p>
                  </div>
                </div>
              </div>
            )}

            {errorDetail && (
              <div className="rounded-lg border-2 border-destructive/40 bg-destructive/5 p-4 space-y-2">
                <p className="text-sm font-semibold text-destructive">
                  Échec de la demande — journal de diagnostic
                </p>
                <p className="text-sm">
                  <span className="font-medium">Étape :</span> {errorDetail.etape}
                </p>
                <p className="text-sm">
                  <span className="font-medium">Raison :</span> {errorDetail.raison}
                </p>
                {errorDetail.statut_http && (
                  <p className="text-sm"><span className="font-medium">Code HTTP :</span> {errorDetail.statut_http}</p>
                )}
                <pre className="text-[10px] overflow-x-auto rounded bg-muted p-2">
{JSON.stringify(errorDetail.donnees_envoyees, null, 2)}
                </pre>
                <p className="text-[10px] text-muted-foreground">{errorDetail.horodatage}</p>
              </div>
            )}

            {/* Message / Justification */}
            <div className="space-y-1.5">
              <Label htmlFor="message" className="text-sm flex items-center gap-2">
                <FileText className="h-3.5 w-3.5" /> Message / Justification
              </Label>
              <Textarea
                id="message"
                rows={3}
                className="text-sm"
                value={formData.message}
                onChange={(e) => setFormData({...formData, message: e.target.value})}
                placeholder="Expliquez pourquoi vous souhaitez rejoindre AgriCapital..."
              />
            </div>

            <p className="text-xs text-muted-foreground">
              Après validation par l'administrateur, votre accès est activé selon le rôle demandé. Vous pouvez alors vous connecter immédiatement.
            </p>

            {/* Boutons */}
            <div className="flex flex-col sm:flex-row gap-3 pt-2">
              <Button
                type="button"
                variant="outline"
                onClick={() => navigate('/login')}
                className="flex-1 h-10 sm:h-11"
              >
                Annuler
              </Button>
              <Button
                type="submit"
                disabled={isSubmitting}
                className="flex-1 h-10 sm:h-11"
              >
                {isSubmitting ? "Envoi en cours..." : "Envoyer la demande"}
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
};

export default AccountRequest;
