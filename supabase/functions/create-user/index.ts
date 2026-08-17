import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.75.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const VALID_ROLES = [
  "super_admin",
  "directeur_tc",
  "directeur_technico_commercial",
  "responsable_zone",
  "superviseur_tc",
  "chef_equipe",
  "comptable",
  "commercial",
  "technicien",
  "service_client",
  "operations",
  "agent_terrain",
  "user",
  "admin",
];

const jsonResponse = (payload: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(payload), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  });

const findAuthUserByEmail = async (supabase: any, email: string) => {
  const perPage = 1000;

  for (let page = 1; page <= 20; page += 1) {
    const { data, error } = await supabase.auth.admin.listUsers({ page, perPage });
    if (error) throw error;

    const match = data?.users?.find(
      (user: any) => user.email?.toLowerCase() === email.toLowerCase(),
    );

    if (match || !data?.users || data.users.length < perPage) {
      return match || null;
    }
  }

  return null;
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    );

    // --- Authentification et autorisation du caller (admin uniquement) ---
    const token = (req.headers.get("Authorization") ?? "").replace("Bearer ", "").trim();
    if (!token) return jsonResponse({ success: false, error: "Non authentifié" }, 401);
    const { data: callerData } = await supabase.auth.getUser(token);
    const caller = callerData?.user;
    if (!caller) return jsonResponse({ success: false, error: "Session invalide" }, 401);
    const { data: isAdmin } = await supabase.rpc("is_admin", { _user_id: caller.id });
    if (!isAdmin) {
      return jsonResponse({ success: false, error: "Accès réservé aux administrateurs" }, 403);
    }



    const { 
      email: rawEmail, 
      password, 
      nom_complet,
      telephone,
      equipe_id,
      photo_url,
      roles,
      username,
      whatsapp,
      departement,
      relation_rh,
      taux_commission,
      district_id,
      region_id,
      poste
    } = await req.json();
    const email = String(rawEmail || "").trim().toLowerCase();
    const requestedRoles = Array.isArray(roles) ? roles : [];
    const invalidRoles = requestedRoles.filter((role: string) => !VALID_ROLES.includes(role));
    const roleInserts = [...new Set(requestedRoles)]
      .filter((role: string) => VALID_ROLES.includes(role))
      .map((role: string) => ({ role }));

    // Input validation
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 255) {
      return jsonResponse({ success: false, error: "Email invalide" }, 400);
    }

    if (!password || password.length < 8 || password.length > 128) {
      return jsonResponse({ 
        success: false, 
        error: "Mot de passe invalide. Doit contenir entre 8 et 128 caractères." 
      }, 400);
    }

    if (!nom_complet || nom_complet.length < 2 || nom_complet.length > 100) {
      return jsonResponse({ 
        success: false, 
        error: "Nom complet invalide. Doit contenir entre 2 et 100 caractères." 
      }, 400);
    }

    if (requestedRoles.length === 0) {
      return jsonResponse({
        success: false,
        error: "Aucun rôle fourni. La création doit passer par user_roles avec au moins un rôle valide.",
      }, 400);
    }

    if (invalidRoles.length > 0 || roleInserts.length === 0) {
      return jsonResponse({
        success: false,
        error: `Configuration des rôles invalide: ${invalidRoles.join(", ") || "aucun rôle reconnu"}`,
      }, 400);
    }

    console.log("User creation initiated for:", email);

    // Check if a profile already exists by email. If it exists, the operation is idempotent:
    // update the Auth password/profile/roles instead of returning a blocking duplicate error.
    const { data: existingProfiles, error: existingProfileError } = await supabase
      .from("profiles")
      .select("id,user_id,email")
      .ilike("email", email)
      .limit(1);

    if (existingProfileError) {
      console.error("Existing profile lookup error:", existingProfileError);
      throw new Error("Impossible de vérifier l'existence du profil utilisateur");
    }

    const existingProfile = existingProfiles?.[0] || null;

    let authUser = null;
    let userAlreadyExisted = false;

    if (existingProfile?.user_id || existingProfile?.id) {
      const existingUserId = existingProfile.user_id || existingProfile.id;
      const { data: updatedAuthData, error: updateAuthError } = await supabase.auth.admin.updateUserById(
        existingUserId,
        {
          email,
          password,
          email_confirm: true,
          user_metadata: { nom_complet },
        },
      );

      if (updateAuthError) {
        console.error("Auth update error:", updateAuthError);
        throw new Error("Un profil existe pour cet email, mais le compte Auth associé est introuvable ou invalide.");
      }

      authUser = updatedAuthData.user;
      userAlreadyExisted = true;
      console.log("Existing user updated:", authUser.id);
    } else {
      // Create user in auth. If Auth already has the user but the profile lookup missed it,
      // recover by locating the Auth user and updating it.
      const { data: authData, error: authError } = await supabase.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { nom_complet },
      });

      if (authError) {
        const duplicateAuthUser = /already|registered|exists|duplicate/i.test(authError.message || "")
          ? await findAuthUserByEmail(supabase, email)
          : null;

        if (!duplicateAuthUser) {
          console.error("Auth error:", authError);
          throw authError;
        }

        const { data: updatedAuthData, error: updateAuthError } = await supabase.auth.admin.updateUserById(
          duplicateAuthUser.id,
          {
            password,
            email_confirm: true,
            user_metadata: { nom_complet },
          },
        );

        if (updateAuthError) {
          console.error("Auth duplicate recovery error:", updateAuthError);
          throw updateAuthError;
        }

        authUser = updatedAuthData.user;
        userAlreadyExisted = true;
        console.log("Existing auth user recovered:", authUser.id);
      } else {
        authUser = authData.user;
        console.log("User authentication record created:", authUser.id);
      }
    }

    if (!authUser?.id) {
      throw new Error("Compte Auth introuvable après création ou mise à jour");
    }

    // Upsert profile (handle_new_user trigger may have already created a base row)
    const profilePayload = {
        id: existingProfile?.id || authUser.id,
        user_id: authUser.id,
        email,
        nom_complet,
        telephone: telephone || null,
        whatsapp: whatsapp || null,
        departement: departement || null,
        relation_rh: relation_rh || 'Employé',
        taux_commission: taux_commission ? Number(taux_commission) : null,
        district_id: district_id || null,
        region_id: region_id || null,
        poste: poste || null,
        equipe_id: equipe_id || null,
        photo_url: photo_url || null,
        username: username || email.split('@')[0],
        actif: true,
    };

    const profileQuery = existingProfile?.id
      ? supabase.from("profiles").update(profilePayload).eq("id", existingProfile.id)
      : supabase.from("profiles").upsert(profilePayload, { onConflict: "id" });

    const { error: profileError } = await profileQuery;

    if (profileError) {
      console.error("Profile error:", profileError);
      if (!userAlreadyExisted) {
        // Try to delete the auth user if profile creation fails for a brand-new account
        await supabase.auth.admin.deleteUser(authUser.id);
      }
      throw profileError;
    }

    console.log(userAlreadyExisted ? "Profile updated successfully" : "Profile created successfully");

    // Roles are managed only through user_roles. Replace stale roles, then upsert the requested set.
    const { error: deleteRolesError } = await supabase
      .from("user_roles")
      .delete()
      .eq("user_id", authUser.id);

    if (deleteRolesError) {
      console.error("Roles delete error:", deleteRolesError);
      throw new Error("Configuration user_roles manquante ou inaccessible: impossible de réinitialiser les rôles.");
    }

    const { error: rolesError } = await supabase
      .from("user_roles")
      .upsert(
        roleInserts.map((role: { role: string }) => ({ user_id: authUser.id, role: role.role })),
        { onConflict: "user_id,role" },
      );

    if (rolesError) {
      console.error("Roles error:", rolesError);
      throw new Error("Configuration user_roles manquante ou invalide: impossible d'attribuer les rôles.");
    }

    console.log("User roles assigned successfully");

    return jsonResponse({
      success: true,
      message: userAlreadyExisted ? "Utilisateur existant mis à jour avec succès" : "Utilisateur créé avec succès",
      user_id: authUser.id,
      email,
      user_already_existed: userAlreadyExisted,
    });
  } catch (error: any) {
    console.error("Error:", error);
    return jsonResponse({ 
      success: false, 
      error: error?.message || "Une erreur est survenue lors de la création de l'utilisateur" 
    }, 400);
  }
});
