import type { BookingPolicyVersion, BookingServiceOption, PolicyPreviewSnapshot } from "@/types/booking";
import { faNumber } from "./date-utils";

export const formatToman = (value: number | null) => value === null ? "تأیید نشده" : `${faNumber(value)} تومان`;
export function calculateTotals(services: BookingServiceOption[]) {
  const unknownPrices = services.filter(s => s.offering?.priceToman == null).map(s => s.id);
  const unknownDurations = services.filter(s => s.offering?.durationMinutes == null).map(s => s.id);
  const unknownBuffers = services.filter(s => s.offering?.bufferMinutes == null).map(s => s.id);
  return {
    priceToman: services.length && !unknownPrices.length ? services.reduce((n, s) => n + s.offering!.priceToman!, 0) : null,
    durationMinutes: services.length && !unknownDurations.length ? services.reduce((n, s) => n + s.offering!.durationMinutes!, 0) : null,
    bufferMinutes: services.length && !unknownBuffers.length ? services.reduce((n, s) => n + s.offering!.bufferMinutes!, 0) : null,
    unknownPrices, unknownDurations,
  };
}
/** Arithmetic illustration only: no effective-policy resolution, cancellation enforcement or payment. */
export function calculatePolicyPreview(policy: BookingPolicyVersion | null, total: number | null, optionalDeposit: boolean) {
  if (!policy) return { deposit: null, remaining: null, error: null };
  const contract = policy.deposit;
  if (contract.requirement === "none" || (contract.requirement === "optional" && !optionalDeposit)) return { deposit: 0, remaining: total, error: null };
  let deposit: number | null;
  if (contract.amount.kind === "fixed") deposit = contract.amount.amountToman;
  else deposit = total === null ? null : Math.round(total * contract.amount.basisPoints / 10000);
  if (deposit !== null && total !== null && deposit > total) return { deposit: null, remaining: null, error: "بیعانه نمونه از جمع خدمات بیشتر است؛ این ترکیب قابل محاسبه نیست." };
  return { deposit, remaining: deposit !== null && total !== null ? total - deposit : null, error: null };
}
export function policyPreviewSnapshot(policy: BookingPolicyVersion | null): PolicyPreviewSnapshot | null {
  return policy ? { kind: "preview-only", policyId: policy.id, version: policy.version, policy: structuredClone(policy) } : null;
}
