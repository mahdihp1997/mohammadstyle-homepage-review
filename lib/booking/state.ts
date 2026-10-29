import { bookingCatalog, demoPolicies } from "@/data/booking-demo";
import type { BookingAction, BookingCatalog, BookingPolicyVersion, BookingState, BookingStep, LocalDate, PricingMode } from "@/types/booking";
import type { ServiceId } from "@/data/site";
import { validateStep } from "./validation";
import { branchOffering, validBarber } from "./catalog";
import { availabilityKey, availabilityRequest, resolveSlot, snapshotSlots } from "./availability";
import { selectedPolicy } from "./policies";
import { withinDates } from "./date-utils";
import { policyPreviewSnapshot } from "./calculations";

export function initialBookingState(serviceId: ServiceId | null): BookingState {
  return { step: 1, error: null, previewViewed: false, policyPreview: null, availability: { status: "idle", key: "", requestId: 0, slots: [] }, draft: {
    branchId: null, serviceIds: serviceId ? [serviceId] : [], barberId: null, date: null, slot: null,
    pricingMode: "unconfirmed", policyId: null, optionalDeposit: false,
  } };
}
export function createBookingReducer(min: LocalDate, max: LocalDate, dependencies: { catalog?: (mode: PricingMode) => BookingCatalog; policies?: BookingPolicyVersion[] } = {}) {
  const catalogFor = dependencies.catalog ?? bookingCatalog, policies = dependencies.policies ?? demoPolicies;
  return (state: BookingState, action: BookingAction): BookingState => {
    const draft = state.draft, catalog = catalogFor(draft.pricingMode);
    const changed = (next: BookingState["draft"], invalidateAvailability = false): BookingState => {
      const policy = selectedPolicy(policies, next, catalogFor(next.pricingMode));
      return { ...state, draft: { ...next, policyId: policy?.id ?? null, optionalDeposit: policy?.deposit.requirement === "optional" && next.optionalDeposit },
        availability: invalidateAvailability ? { status: "idle", key: "", requestId: state.availability.requestId, slots: [] } : state.availability,
        error: null, previewViewed: false, policyPreview: null };
    };
    switch (action.type) {
      case "branch": {
        if (action.id === draft.branchId) return state;
        if (action.id && !catalog.branches.some(b => b.id === action.id && b.demoConfigured)) return { ...state, error: "این شعبه هنوز پیکربندی نشده است." };
        return changed({ ...draft, branchId: action.id, serviceIds: draft.serviceIds.filter(id => branchOffering(catalog, action.id, id)?.active), barberId: null, date: null, slot: null }, true);
      }
      case "service": {
        if (!catalog.services.some(s => s.id === action.id) || !branchOffering(catalog, draft.branchId, action.id)?.active) return state;
        const ids = draft.serviceIds.includes(action.id) ? draft.serviceIds.filter(id => id !== action.id) : [...draft.serviceIds, action.id];
        const next = { ...draft, serviceIds: ids, slot: null };
        if (!validBarber(next, catalog)) next.barberId = null;
        return changed(next, true);
      }
      case "barber": {
        if (action.id === draft.barberId) return state;
        const next = { ...draft, barberId: action.id, slot: null };
        return validBarber(next, catalog) ? changed(next, true) : state;
      }
      case "date": return action.date !== draft.date && withinDates(action.date, min, max) ? changed({ ...draft, date: action.date, slot: null }, true) : state;
      case "slot": {
        const slot = resolveSlot(draft, catalog, state.availability, action.id, action.key, action.requestId);
        return slot && draft.date && withinDates(draft.date, min, max) ? changed({ ...draft, slot }) : state;
      }
      case "availabilityLoading": {
        const key = availabilityKey(availabilityRequest(draft, catalog));
        if (!key || action.key !== key || !Number.isSafeInteger(action.requestId) || action.requestId <= state.availability.requestId) return state;
        return { ...changed({ ...draft, slot: null }), availability: { status: "loading", key, requestId: action.requestId, slots: [] } };
      }
      case "availabilityReady": case "availabilityError": {
        const request = availabilityRequest(draft, catalog), current = state.availability;
        if (!request || current.status !== "loading" || action.key !== current.key || action.key !== availabilityKey(request) || action.requestId !== current.requestId) return state;
        return { ...state, availability: action.type === "availabilityReady"
          ? { status: "ready", key: action.key, requestId: action.requestId, slots: snapshotSlots(action.slots, request) }
          : { status: "error", key: action.key, requestId: action.requestId, slots: [], message: action.message } };
      }
      case "pricing": return action.mode === draft.pricingMode ? state : changed({ ...draft, pricingMode: action.mode, slot: null }, true);
      case "policy": return changed({ ...draft, policyId: action.id, optionalDeposit: false });
      case "optionalDeposit": return changed({ ...draft, optionalDeposit: action.value });
      case "back": return { ...state, step: Math.max(1, state.step - 1) as BookingStep, error: null, previewViewed: false };
      case "go": return action.step <= state.step ? { ...state, step: action.step, error: null, previewViewed: false } : state;
      case "next": {
        const error = validateStep(draft, state.step, catalog, state.availability, min, max, policies);
        return error ? { ...state, error } : { ...state, step: Math.min(5, state.step + 1) as BookingStep, error: null };
      }
      case "preview": {
        const error = validateStep(draft, 5, catalog, state.availability, min, max, policies);
        return error ? { ...state, error, previewViewed: false, policyPreview: null } : { ...state, error: null, previewViewed: true, policyPreview: policyPreviewSnapshot(selectedPolicy(policies, draft, catalog)) };
      }
    }
  };
}
