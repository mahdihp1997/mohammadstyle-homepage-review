import type { BookingCatalog, BookingDraft, BookingPolicyVersion } from "@/types/booking";
import { validServices } from "./catalog";

/** Context compatibility only, not policy precedence, effective-date selection or enforcement. */
export function policyAppliesToDraft(policy: BookingPolicyVersion, draft: BookingDraft, catalog: BookingCatalog): boolean {
  if (!catalog.branches.some(b => b.id === draft.branchId && b.demoConfigured)) return false;
  switch (policy.scope.kind) {
    case "branch": return policy.scope.branchId === draft.branchId;
    case "service": return (!policy.scope.branchId || policy.scope.branchId === draft.branchId)
      && draft.serviceIds.includes(policy.scope.serviceId) && validServices(draft, catalog);
    // The MVP has neither package identity nor an existing booking identity. Never infer a match.
    case "package": case "booking": return false;
  }
}
export function selectedPolicy(policies: BookingPolicyVersion[], draft: BookingDraft, catalog: BookingCatalog) {
  return policies.find(policy => policy.id === draft.policyId && policyAppliesToDraft(policy, draft, catalog)) ?? null;
}
