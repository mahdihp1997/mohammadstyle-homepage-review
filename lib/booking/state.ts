import { bookingCatalog, demoPolicies } from "@/data/booking-demo";
import type { BookingAction, BookingState, BookingStep, LocalDate } from "@/types/booking";
import type { ServiceId } from "@/data/site";
import { validBarber, validSlot, validateStep } from "./validation";
import { withinDates } from "./date-utils";
import { policyPreviewSnapshot } from "./calculations";

export function initialBookingState(serviceId: ServiceId | null): BookingState {
  return { step: 1, error: null, previewViewed: false, policyPreview: null, draft: {
    branchId: null, serviceIds: serviceId ? [serviceId] : [], barberId: null, date: null, slot: null,
    pricingMode: "unconfirmed", policyId: null, optionalDeposit: false,
  } };
}
export function createBookingReducer(min: LocalDate, max: LocalDate) {
  return (state: BookingState, action: BookingAction): BookingState => {
    const draft = state.draft, catalog = bookingCatalog(draft.pricingMode);
    const changed = (next: BookingState["draft"]): BookingState => ({ ...state, draft: next, error: null, previewViewed: false, policyPreview: null });
    switch (action.type) {
      case "branch": {
        if (action.id === draft.branchId) return state;
        if (action.id && !catalog.branches.some(b => b.id === action.id && b.demoConfigured)) return { ...state, error: "این شعبه هنوز پیکربندی نشده است." };
        return changed({ ...draft, branchId: action.id, serviceIds: draft.serviceIds.filter(id => catalog.services.some(s => s.id === id && !!action.id && s.branchIds.includes(action.id))), barberId: null, date: null, slot: null });
      }
      case "service": {
        if (!catalog.services.some(s => s.id === action.id && !!draft.branchId && s.branchIds.includes(draft.branchId))) return state;
        const ids = draft.serviceIds.includes(action.id) ? draft.serviceIds.filter(id => id !== action.id) : [...draft.serviceIds, action.id];
        const next = { ...draft, serviceIds: ids, slot: null };
        if (!validBarber(next, catalog)) next.barberId = null;
        return changed(next);
      }
      case "barber": {
        if (action.id === draft.barberId) return state;
        const next = { ...draft, barberId: action.id, slot: null };
        return validBarber(next, catalog) ? changed(next) : state;
      }
      case "date": return action.date !== draft.date && withinDates(action.date, min, max) ? changed({ ...draft, date: action.date, slot: null }) : state;
      case "slot": {
        const next = { ...draft, slot: action.slot };
        return validSlot(next, catalog, [action.slot]) ? changed(next) : state;
      }
      case "pricing": return action.mode === draft.pricingMode ? state : changed({ ...draft, pricingMode: action.mode, slot: null });
      case "policy": return changed({ ...draft, policyId: demoPolicies.some(p => p.id === action.id) ? action.id : null, optionalDeposit: false });
      case "optionalDeposit": return changed({ ...draft, optionalDeposit: action.value });
      case "back": return { ...state, step: Math.max(1, state.step - 1) as BookingStep, error: null, previewViewed: false };
      case "go": return action.step <= state.step ? { ...state, step: action.step, error: null, previewViewed: false } : state;
      case "next": {
        const error = validateStep(draft, state.step, catalog, action.slots, min, max);
        return error ? { ...state, error } : { ...state, step: Math.min(5, state.step + 1) as BookingStep, error: null };
      }
      case "preview": {
        const error = validateStep(draft, 5, catalog, action.slots, min, max);
        return error ? { ...state, error } : { ...state, error: null, previewViewed: true, policyPreview: policyPreviewSnapshot(demoPolicies.find(p => p.id === draft.policyId) ?? null) };
      }
    }
  };
}
