import { business, services } from "@/data/site";
import { addDays } from "@/lib/booking/date-utils";
import type { AvailabilityProvider, BookingBarber, BookingBranch, BookingCatalog, BookingPolicyVersion, LocalDate, LocalTime, PricingMode } from "@/types/booking";

export const bookingBranches: BookingBranch[] = [
  { id: "poonak", name: "شعبه پونک", location: business.location, timeZone: "Asia/Tehran", demoConfigured: true,
    image: { src: "/images/salon-interior.webp", alt: "جای‌نگهدار نسخه عمومی برای تصویر فضای مجموعه", attribution: "جای‌نگهدار بررسی کد؛ عکس خصوصی و انتساب آن نمایش داده نمی‌شود." } },
  { id: "pending", name: "شعبه دوم", location: null, timeZone: "Asia/Tehran", demoConfigured: false, image: null },
];
/** All identities, capabilities, branch assignments and values below are fictional fixtures. */
export const demoBarbers: BookingBarber[] = [
  { id: "demo-a", displayName: "آرایشگر نمایشی الف", branchIds: ["poonak", "pending"], serviceIds: ["hair", "groom", "facial"], source: "demo" },
  { id: "demo-b", displayName: "آرایشگر نمایشی ب", branchIds: ["poonak"], serviceIds: ["hair", "groom", "facial", "massage", "manicure", "pedicure"], source: "demo" },
  { id: "demo-c", displayName: "آرایشگر نمایشی ج", branchIds: ["pending"], serviceIds: ["hair"], source: "demo" },
];
const illustrativeValues = {
  groom: { durationMinutes: 120, priceToman: 2_000_000 }, hair: { durationMinutes: 30, priceToman: 400_000 },
  facial: { durationMinutes: 45, priceToman: 600_000 }, massage: { durationMinutes: 45, priceToman: 700_000 },
  manicure: { durationMinutes: 30, priceToman: 300_000 }, pedicure: { durationMinutes: 45, priceToman: 450_000 },
} as const;
export function bookingCatalog(mode: PricingMode): BookingCatalog {
  return { branches: bookingBranches, barbers: demoBarbers, services: services.map(s => ({
    id: s.id, name: s.name, description: s.subtitle, icon: s.icon, image: s.image ?? null,
    conceptual: s.conceptual ?? false,
  })), offerings: services.map(s => ({
    branchId: "poonak", serviceId: s.id, active: true, valueSource: mode,
    barberIds: demoBarbers.filter(barber => barber.branchIds.includes("poonak") && barber.serviceIds.includes(s.id)).map(barber => barber.id),
    durationMinutes: mode === "demo" ? illustrativeValues[s.id].durationMinutes : null,
    priceToman: mode === "demo" ? illustrativeValues[s.id].priceToman : null,
    bufferMinutes: mode === "demo" ? 0 : null,
  })) };
}
const basePolicy = { source: "demo" as const, scope: { kind: "branch" as const, branchId: "poonak" }, effectiveFrom: "2026-01-01T00:00:00Z", effectiveTo: null, overridesPolicyId: null, version: 1 };
export const demoPolicies: BookingPolicyVersion[] = [
  { ...basePolicy, id: "demo-none", label: "نمونه — بدون بیعانه", deposit: { requirement: "none" }, cancellation: { refundability: "full", windows: [], outsideWindowRefundBasisPoints: 10000 } },
  { ...basePolicy, id: "demo-optional", label: "نمونه — بیعانه اختیاری و بازگشت کامل", deposit: { requirement: "optional", amount: { kind: "fixed", amountToman: 100_000 } }, cancellation: { refundability: "full", windows: [], outsideWindowRefundBasisPoints: 10000 } },
  { ...basePolicy, id: "demo-percent", label: "نمونه — بیعانه ۲۰٪ و بازگشت پلکانی", deposit: { requirement: "required", amount: { kind: "percentage", basisPoints: 2000 } }, cancellation: { refundability: "partial", windows: [{ beforeStartMinutes: 1440, refundBasisPoints: 10000 }, { beforeStartMinutes: 120, refundBasisPoints: 5000 }], outsideWindowRefundBasisPoints: 0 } },
  { ...basePolicy, id: "demo-fixed", label: "نمونه — بیعانه ثابت و غیرقابل‌استرداد", deposit: { requirement: "required", amount: { kind: "fixed", amountToman: 150_000 } }, cancellation: { refundability: "none", windows: [], outsideWindowRefundBasisPoints: 0 } },
  { ...basePolicy, id: "demo-full", label: "نمونه — بیعانه ۱۰٪ و بازگشت کامل", deposit: { requirement: "required", amount: { kind: "percentage", basisPoints: 1000 } }, cancellation: { refundability: "full", windows: [], outsideWindowRefundBasisPoints: 10000 } },
];

export function createDemoAvailability(today: LocalDate): AvailabilityProvider {
  return {
    async loadSlots(request, signal) {
      // A cancellable local delay illustrates an asynchronous provider, without an API call.
      await new Promise<void>((resolve, reject) => {
        if (signal.aborted) { reject(new DOMException("Aborted", "AbortError")); return; }
        const abort = () => { clearTimeout(timer); reject(new DOMException("Aborted", "AbortError")); };
        const timer = setTimeout(() => { signal.removeEventListener("abort", abort); resolve(); }, 450);
        signal.addEventListener("abort", abort, { once: true });
      });
      if (request.date === addDays(today, 2) || request.barberIds.length === 0) return [];
      const times: LocalTime[] = ["10:00", "11:30", "13:00", "15:30", "17:00"];
      return times.map((time, i) => ({
        id: `${request.branchId}/${request.date}/${time}/${request.barberIds.join("+")}/${request.durationMinutes ?? "unknown"}`,
        date: request.date, startTime: time, timeZone: request.timeZone,
        barberIds: request.barberIds.filter((_, index) => i % 2 === 0 || index === 0),
        durationMinutes: request.durationMinutes, selectable: i !== 0, source: "demo" as const,
      }));
    },
  };
}
