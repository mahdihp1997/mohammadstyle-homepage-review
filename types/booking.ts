import type { ServiceId } from "@/data/site";

/** Calendar/domain dates are Gregorian ISO local dates, never formatted Jalali strings. */
export type LocalDate = `${number}-${number}-${number}`;
export type LocalTime = `${number}:${number}`;
export type PricingMode = "unconfirmed" | "demo";
export type BookingStep = 1 | 2 | 3 | 4 | 5;
export type BarberChoice = "any" | string;
export interface BookingBranch {
  id: string; name: string; location: string | null; timeZone: string;
  demoConfigured: boolean;
  image: { src: string; alt: string; attribution: string } | null;
}
export interface BookingService {
  id: ServiceId; name: string; description: string; icon: string; image: string | null;
  conceptual: boolean; durationMinutes: number | null; priceToman: number | null;
  valueSource: "unconfirmed" | "demo";
  /** Demonstration eligibility only; server must supply verified assignments later. */
  branchIds: string[]; barberIds: string[];
}
export interface BookingBarber {
  id: string; displayName: string; branchIds: string[]; serviceIds: ServiceId[]; source: "demo";
}
export interface BookingCatalog { branches: BookingBranch[]; services: BookingService[]; barbers: BookingBarber[] }
export interface AvailabilityRequest {
  branchId: string; serviceIds: ServiceId[]; barberIds: string[];
  date: LocalDate; timeZone: string; durationMinutes: number | null;
}
export interface DemoTimeSlot {
  id: string; date: LocalDate; startTime: LocalTime; timeZone: string;
  barberIds: string[]; durationMinutes: number | null; selectable: boolean; source: "demo";
}
export interface AvailabilityProvider {
  loadSlots(request: AvailabilityRequest, signal: AbortSignal): Promise<DemoTimeSlot[]>;
}
export type AvailabilityState =
  | { status: "idle" | "loading"; key: string; slots: DemoTimeSlot[] }
  | { status: "ready"; key: string; slots: DemoTimeSlot[] }
  | { status: "error"; key: string; slots: DemoTimeSlot[]; message: string };

export type PolicyScope =
  | { kind: "branch"; branchId: string }
  | { kind: "service"; serviceId: ServiceId }
  | { kind: "package"; packageId: string }
  | { kind: "booking"; bookingId: string };
export type DepositAmount = { kind: "fixed"; amountToman: number } | { kind: "percentage"; basisPoints: number };
export type DepositContract =
  | { requirement: "none" }
  | { requirement: "optional" | "required"; amount: DepositAmount };
export interface CancellationWindow { beforeStartMinutes: number; refundBasisPoints: number }
export type DeepReadonly<T> = T extends readonly (infer Item)[] ? readonly DeepReadonly<Item>[] : T extends object ? { readonly [Key in keyof T]: DeepReadonly<T[Key]> } : T;
export interface BookingPolicyVersion {
  id: string; version: number; label: string; source: "demo";
  scope: PolicyScope; effectiveFrom: string; effectiveTo: string | null;
  deposit: DepositContract;
  cancellation: {
    refundability: "full" | "none" | "partial";
    windows: CancellationWindow[]; outsideWindowRefundBasisPoints: number;
  };
  overridesPolicyId: string | null;
}
/** Future server acceptance contract; not created by this frontend preview. */
export interface AcceptedPolicySnapshot {
  bookingId: string; acceptedAt: string; policyId: string; version: number;
  policy: DeepReadonly<BookingPolicyVersion>;
}
export interface PolicyPreviewSnapshot {
  kind: "preview-only"; policyId: string; version: number; policy: DeepReadonly<BookingPolicyVersion>;
}
export interface BookingDraft {
  branchId: string | null; serviceIds: ServiceId[]; barberId: BarberChoice | null;
  date: LocalDate | null; slot: DemoTimeSlot | null; pricingMode: PricingMode;
  policyId: string | null; optionalDeposit: boolean;
}
export interface BookingState {
  draft: BookingDraft; step: BookingStep; error: string | null;
  previewViewed: boolean; policyPreview: PolicyPreviewSnapshot | null;
}
export type BookingAction =
  | { type: "branch"; id: string | null }
  | { type: "service"; id: ServiceId }
  | { type: "barber"; id: BarberChoice }
  | { type: "date"; date: LocalDate }
  | { type: "slot"; slot: DemoTimeSlot }
  | { type: "pricing"; mode: PricingMode }
  | { type: "policy"; id: string | null }
  | { type: "optionalDeposit"; value: boolean }
  | { type: "next"; slots: DemoTimeSlot[] }
  | { type: "back" }
  | { type: "go"; step: BookingStep }
  | { type: "preview"; slots: DemoTimeSlot[] };
