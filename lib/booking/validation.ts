import type { AvailabilityState, BookingCatalog, BookingDraft, BookingPolicyVersion, BookingStep, LocalDate } from "@/types/booking";
import { withinDates } from "./date-utils";
import { validBarber, validServices } from "./catalog";
import { validSlot } from "./availability";
import { selectedPolicy } from "./policies";
export { eligibleBarbers, validBarber, validServices } from "./catalog";
export { validSlot } from "./availability";

export function validateStep(draft: BookingDraft, step: BookingStep, catalog: BookingCatalog, availability: AvailabilityState, min: LocalDate, max: LocalDate, policies: BookingPolicyVersion[]): string | null {
  if (!catalog.branches.some(b => b.id === draft.branchId && b.demoConfigured)) return "ابتدا شعبه قابل استفاده در پیش‌نمایش را انتخاب کنید.";
  if (step >= 2 && !validServices(draft, catalog)) return "حداقل یک خدمت متناسب با شعبه انتخاب کنید.";
  if (step >= 3 && !validBarber(draft, catalog)) return "آرایشگر واجد شرایط یا گزینه بدون ترجیح را انتخاب کنید.";
  if (step >= 4 && (!draft.date || !withinDates(draft.date, min, max))) return "یک تاریخ مجاز برای پیش‌نمایش انتخاب کنید.";
  if (step >= 4 && !validSlot(draft, catalog, availability)) return "یک ساعت قابل انتخاب از داده‌های نمایشی انتخاب کنید.";
  if (step >= 5 && draft.policyId && !selectedPolicy(policies, draft, catalog)) return "سناریوی سیاست با انتخاب‌های فعلی سازگار نیست؛ دوباره انتخاب کنید.";
  return null;
}
