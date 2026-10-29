import type { BookingCatalog, BookingDraft, BookingStep, DemoTimeSlot, LocalDate } from "@/types/booking";
import { withinDates } from "./date-utils";

export function eligibleBarbers(catalog: BookingCatalog, branchId: string | null, ids: BookingDraft["serviceIds"]) {
  if (!branchId || !ids.length || !catalog.branches.some(b => b.id === branchId && b.demoConfigured)) return [];
  return catalog.barbers.filter(b => b.branchIds.includes(branchId) && ids.every(id => b.serviceIds.includes(id) && catalog.services.some(service => service.id === id && service.branchIds.includes(branchId) && service.barberIds.includes(b.id))));
}
export function validServices(draft: BookingDraft, catalog: BookingCatalog) {
  return !!draft.branchId && draft.serviceIds.length > 0 && new Set(draft.serviceIds).size === draft.serviceIds.length && draft.serviceIds.every(id => catalog.services.some(s => s.id === id && s.branchIds.includes(draft.branchId!)));
}
export function validBarber(draft: BookingDraft, catalog: BookingCatalog) {
  const eligible = eligibleBarbers(catalog, draft.branchId, draft.serviceIds);
  return draft.barberId === "any" ? eligible.length > 0 : eligible.some(b => b.id === draft.barberId);
}
export function validSlot(draft: BookingDraft, catalog: BookingCatalog, slots: DemoTimeSlot[]) {
  const chosen = draft.slot;
  if (!chosen || chosen.date !== draft.date || !validBarber(draft, catalog)) return false;
  const branch = catalog.branches.find(b => b.id === draft.branchId);
  const eligible = eligibleBarbers(catalog, draft.branchId, draft.serviceIds);
  const ids = draft.barberId === "any" ? eligible.map(b => b.id) : [draft.barberId];
  return chosen.timeZone === branch?.timeZone && slots.some(s => s.id === chosen.id && s.selectable && s.date === draft.date && s.barberIds.some(id => ids.includes(id)));
}
export function validateStep(draft: BookingDraft, step: BookingStep, catalog: BookingCatalog, slots: DemoTimeSlot[], min: LocalDate, max: LocalDate): string | null {
  if (!catalog.branches.some(b => b.id === draft.branchId && b.demoConfigured)) return "ابتدا شعبه قابل استفاده در پیش‌نمایش را انتخاب کنید.";
  if (step >= 2 && !validServices(draft, catalog)) return "حداقل یک خدمت متناسب با شعبه انتخاب کنید.";
  if (step >= 3 && !validBarber(draft, catalog)) return "آرایشگر واجد شرایط یا گزینه بدون ترجیح را انتخاب کنید.";
  if (step >= 4 && (!draft.date || !withinDates(draft.date, min, max))) return "یک تاریخ مجاز برای پیش‌نمایش انتخاب کنید.";
  if (step >= 4 && !validSlot(draft, catalog, slots)) return "یک ساعت قابل انتخاب از داده‌های نمایشی انتخاب کنید.";
  return null;
}
