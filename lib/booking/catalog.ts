import type { BookingCatalog, BookingDraft, BookingServiceOption, BranchServiceOffering } from "@/types/booking";
import type { ServiceId } from "@/data/site";

/** Duplicate/malformed configuration fails closed instead of picking an arbitrary tariff. */
export function branchOffering(catalog: BookingCatalog, branchId: string | null, serviceId: ServiceId): BranchServiceOffering | null {
  const matches = catalog.offerings.filter(o => o.branchId === branchId && o.serviceId === serviceId);
  if (matches.length !== 1) return null;
  const offering = matches[0];
  const validNumber = (value: number | null, minimum: number) => value === null || (Number.isSafeInteger(value) && value >= minimum);
  return typeof offering.active === "boolean" && (offering.valueSource === "unconfirmed" || offering.valueSource === "demo")
    && validNumber(offering.priceToman, 0) && validNumber(offering.durationMinutes, 1) && validNumber(offering.bufferMinutes, 0)
    && Array.isArray(offering.barberIds) && offering.barberIds.every(id => typeof id === "string" && id.length > 0)
    && new Set(offering.barberIds).size === offering.barberIds.length ? offering : null;
}
export function servicesForBranch(catalog: BookingCatalog, branchId: string | null): BookingServiceOption[] {
  return catalog.services.map(service => {
    const offering = branchOffering(catalog, branchId, service.id);
    return { ...service, offering: offering?.active ? offering : null };
  });
}
export function validServices(draft: BookingDraft, catalog: BookingCatalog) {
  return catalog.branches.some(b => b.id === draft.branchId && b.demoConfigured) && draft.serviceIds.length > 0 && new Set(draft.serviceIds).size === draft.serviceIds.length
    && draft.serviceIds.every(id => catalog.services.some(s => s.id === id) && branchOffering(catalog, draft.branchId, id)?.active);
}
export function eligibleBarbers(catalog: BookingCatalog, branchId: string | null, ids: BookingDraft["serviceIds"]) {
  if (!branchId || !ids.length || !catalog.branches.some(b => b.id === branchId && b.demoConfigured)) return [];
  return catalog.barbers.filter(barber => barber.branchIds.includes(branchId) && ids.every(id => {
    const offering = branchOffering(catalog, branchId, id);
    return catalog.services.some(s => s.id === id) && offering?.active && offering.barberIds.includes(barber.id) && barber.serviceIds.includes(id);
  }));
}
export function validBarber(draft: BookingDraft, catalog: BookingCatalog) {
  const eligible = eligibleBarbers(catalog, draft.branchId, draft.serviceIds);
  return draft.barberId === "any" ? eligible.length > 0 : eligible.some(b => b.id === draft.barberId);
}
