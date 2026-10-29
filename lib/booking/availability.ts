import type { AvailabilityRequest, AvailabilityState, BookingCatalog, BookingDraft, DemoTimeSlot } from "@/types/booking";
import { calculateTotals } from "./calculations";
import { eligibleBarbers, servicesForBranch, validBarber, validServices } from "./catalog";

export function availabilityRequest(draft: BookingDraft, catalog: BookingCatalog): AvailabilityRequest | null {
  if (!draft.branchId || !draft.date || !validServices(draft, catalog) || !validBarber(draft, catalog)) return null;
  const branch = catalog.branches.find(b => b.id === draft.branchId && b.demoConfigured);
  if (!branch) return null;
  const selected = servicesForBranch(catalog, branch.id).filter(s => draft.serviceIds.includes(s.id));
  const totals = calculateTotals(selected);
  return {
    branchId: branch.id, serviceIds: [...draft.serviceIds].sort(),
    barberIds: eligibleBarbers(catalog, branch.id, draft.serviceIds).filter(b => draft.barberId === "any" || b.id === draft.barberId).map(b => b.id).sort(),
    date: draft.date, timeZone: branch.timeZone, durationMinutes: totals.durationMinutes, bufferMinutes: totals.bufferMinutes,
    offerings: selected.map(s => ({ ...s.offering!, barberIds: [...s.offering!.barberIds].sort() })).sort((a, b) => a.serviceId.localeCompare(b.serviceId)),
  };
}
export const availabilityKey = (request: AvailabilityRequest | null) => request ? JSON.stringify(request) : "";

function matchesRequest(slot: DemoTimeSlot, request: AvailabilityRequest) {
  return !!slot && typeof slot.id === "string" && slot.id.length > 0 && slot.date === request.date && slot.timeZone === request.timeZone
    && /^(?:[01]\d|2[0-3]):[0-5]\d$/.test(slot.startTime) && slot.durationMinutes === request.durationMinutes
    && typeof slot.selectable === "boolean" && slot.source === "demo" && Array.isArray(slot.barberIds) && slot.barberIds.length > 0
    && new Set(slot.barberIds).size === slot.barberIds.length && slot.barberIds.every(id => request.barberIds.includes(id));
}
/** Snapshot the adapter response; callers cannot mutate a selected slot through the original array. */
export function snapshotSlots(slots: readonly DemoTimeSlot[], request: AvailabilityRequest): readonly DemoTimeSlot[] {
  return Object.freeze(slots.filter(slot => matchesRequest(slot, request) && slots.filter(s => s?.id === slot.id).length === 1)
    .map(slot => Object.freeze({ ...slot, barberIds: Object.freeze([...slot.barberIds]) })));
}
export function resolveSlot(draft: BookingDraft, catalog: BookingCatalog, availability: AvailabilityState, id: string, key: string, requestId: number): DemoTimeSlot | null {
  const request = availabilityRequest(draft, catalog);
  if (!request || availability.status !== "ready" || availability.key !== availabilityKey(request) || key !== availability.key || requestId !== availability.requestId) return null;
  const matches = availability.slots.filter(slot => slot.id === id);
  const slot = matches.length === 1 ? matches[0] : null;
  return slot?.selectable && matchesRequest(slot, request) ? slot : null;
}
export function validSlot(draft: BookingDraft, catalog: BookingCatalog, availability: AvailabilityState) {
  const chosen = draft.slot;
  if (!chosen) return false;
  const canonical = resolveSlot(draft, catalog, availability, chosen.id, availability.key, availability.requestId);
  return !!canonical && chosen.id === canonical.id && chosen.date === canonical.date && chosen.startTime === canonical.startTime
    && chosen.timeZone === canonical.timeZone && chosen.durationMinutes === canonical.durationMinutes && chosen.selectable === canonical.selectable
    && chosen.source === canonical.source && Array.isArray(chosen.barberIds) && chosen.barberIds.length === canonical.barberIds.length && chosen.barberIds.every((id, i) => id === canonical.barberIds[i]);
}
