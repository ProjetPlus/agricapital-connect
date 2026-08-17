import { describe, it, expect } from "vitest";
import { hasPermission, PERMISSIONS, ROLES } from "@/lib/roles";

describe("RBAC — permissions par rôle", () => {
  it("super_admin a toutes permissions critiques", () => {
    const r = [ROLES.SUPER_ADMIN];
    expect(hasPermission(r, PERMISSIONS.CREATE_SOUSCRIPTION)).toBe(true);
    expect(hasPermission(r, PERMISSIONS.VALIDATE_PAYMENTS)).toBe(true);
    expect(hasPermission(r, PERMISSIONS.MANAGE_USERS)).toBe(true);
    expect(hasPermission(r, PERMISSIONS.DELETE_DATA)).toBe(true);
  });
  it("commercial: souscription oui, validation paiement non", () => {
    const r = [ROLES.COMMERCIAL];
    expect(hasPermission(r, PERMISSIONS.CREATE_SOUSCRIPTION)).toBe(true);
    expect(hasPermission(r, PERMISSIONS.VALIDATE_PAYMENTS)).toBe(false);
  });
  it("comptable: validation paiement oui, souscription non", () => {
    const r = [ROLES.COMPTABLE];
    expect(hasPermission(r, PERMISSIONS.VALIDATE_PAYMENTS)).toBe(true);
    expect(hasPermission(r, PERMISSIONS.CREATE_SOUSCRIPTION)).toBe(false);
  });
  it("chef d'équipe technique: plantations oui, paiements/souscriptions non", () => {
    const r = [ROLES.CHEF_EQUIPE_TECHNIQUE];
    expect(hasPermission(r, PERMISSIONS.VIEW_PLANTATIONS)).toBe(true);
    expect(hasPermission(r, PERMISSIONS.VIEW_PAIEMENTS)).toBe(false);
    expect(hasPermission(r, PERMISSIONS.VIEW_SOUSCRIPTIONS)).toBe(false);
  });
  it("rôle obsolète (souscripteur) sans permission staff", () => {
    const r = ["user"];
    expect(hasPermission(r, PERMISSIONS.CREATE_SOUSCRIPTION)).toBe(false);
    expect(hasPermission(r, PERMISSIONS.MANAGE_USERS)).toBe(false);
    expect(hasPermission(r, PERMISSIONS.VIEW_PARAMETRES)).toBe(false);
  });

  it("service_client: validation + tickets", () => {
    const r = [ROLES.SERVICE_CLIENT];
    expect(hasPermission(r, PERMISSIONS.VALIDATE_PAYMENTS)).toBe(true);
    expect(hasPermission(r, PERMISSIONS.VIEW_TICKETS)).toBe(true);
  });
});
