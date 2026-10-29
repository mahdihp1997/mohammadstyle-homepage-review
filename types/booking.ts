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
  conceptual: boolean;
}
/** One configuration per branch/service pair; never a global service tariff. */
export interface BranchServiceOffering {
  branchId: string; serviceId: ServiceId; active: boolean;
  priceToman: number | null; durationMinutes: number | null; bufferMinutes: number | null;
  barberIds: string[]; valueSource: PricingMode;
}
export interface BookingServiceOption extends BookingService { offering: BranchServiceOffering | null }
export interface BookingBarber {
  id: string; displayName: string; branchIds: string[]; serviceIds: ServiceId[]; source: "demo";
}
export interface BookingCatalog { branches: BookingBranch[]; services: BookingService[]; offerings: BranchServiceOffering[]; barbers: BookingBarber[] }
export interface AvailabilityRequest {
  branchId: string; serviceIds: ServiceId[]; barberIds: string[];
  date: LocalDate; timeZone: string; durationMinutes: number | null; bufferMinutes: number | null;
  /** Snapshot makes branch-specific configuration changes invalidate availability. */
  offerings: BranchServiceOffering[];
}
export interface DemoTimeSlot {
  readonly id: string; readonly date: LocalDate; readonly startTime: LocalTime; readonly timeZone: string;
  readonly barberIds: readonly string[]; readonly durationMinutes: number | null; readonly selectable: boolean; readonly source: "demo";
}
export interface AvailabilityProvider {
  loadSlots(request: AvailabilityRequest, signal: AbortSignal): Promise<DemoTimeSlot[]>;
}
export type AvailabilityState =
  | { status: "idle" | "loading"; key: string; requestId: number; slots: readonly DemoTimeSlot[] }
  | { status: "ready"; key: string; requestId: number; slots: readonly DemoTimeSlot[] }
  | { status: "error"; key: string; requestId: number; slots: readonly DemoTimeSlot[]; message: string };

export type PolicyScope =
  | { kind: "branch"; branchId: string }
  | { kind: "service"; serviceId: ServiceId; branchId?: string }
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
  /** Only provider lifecycle actions populate this response; selections carry IDs only. */
  availability: AvailabilityState;
}
export type BookingAction =
  | { type: "branch"; id: string | null }
  | { type: "service"; id: ServiceId }
  | { type: "barber"; id: BarberChoice }
  | { type: "date"; date: LocalDate }
  | { type: "slot"; id: string; key: string; requestId: number }
  | { type: "availabilityLoading"; key: string; requestId: number }
  | { type: "availabilityReady"; key: string; requestId: number; slots: readonly DemoTimeSlot[] }
  | { type: "availabilityError"; key: string; requestId: number; message: string }
  | { type: "pricing"; mode: PricingMode }
  | { type: "policy"; id: string | null }
  | { type: "optionalDeposit"; value: boolean }
  | { type: "next" }
  | { type: "back" }
  | { type: "go"; step: BookingStep }
  | { type: "preview" };
