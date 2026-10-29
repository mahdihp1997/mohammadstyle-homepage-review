import { test, expect } from "@playwright/test";
import { bookingCatalog, demoPolicies } from "../data/booking-demo";
import { addDays, calendarWeeks, isLocalDate, jalaliParts, localToday, monthStart, shiftMonth } from "../lib/booking/date-utils";
import { calculatePolicyPreview, calculateTotals, policyPreviewSnapshot } from "../lib/booking/calculations";
import { createBookingReducer, initialBookingState } from "../lib/booking/state";
import { eligibleBarbers } from "../lib/booking/validation";
import { servicesForBranch } from "../lib/booking/catalog";
import { availabilityKey, availabilityRequest } from "../lib/booking/availability";
import type { DemoTimeSlot, LocalDate } from "../types/booking";

test("Jalali Nowruz/leap boundaries, ISO date validation and Tehran midnight", () => {
  expect(jalaliParts("2024-03-20")).toEqual({ year: 1403, month: 1, day: 1 });
  expect(jalaliParts("2025-03-20")).toEqual({ year: 1403, month: 12, day: 30 });
  expect(jalaliParts("2025-03-21")).toEqual({ year: 1404, month: 1, day: 1 });
  expect(shiftMonth(monthStart("2025-03-20"), 1)).toBe("2025-03-21");
  expect(shiftMonth("2025-03-21", -1)).toBe("2025-02-19");
  const weeks = calendarWeeks("2025-03-21");
  expect(weeks.flat()).toHaveLength(42);
  expect(new Date(`${weeks[0][0]}T12:00:00Z`).getUTCDay()).toBe(6);
  expect(isLocalDate("2025-02-30")).toBe(false);
  expect(isLocalDate("۱۴۰۴/۰۱/۰۱")).toBe(false);
  expect(localToday("Asia/Tehran", new Date("2026-10-28T21:00:00Z"))).toBe("2026-10-29");
  expect(addDays("2024-02-28", 1)).toBe("2024-02-29");
});

test("unknown totals stay unknown; explicit demo arithmetic and policy cases", () => {
  expect(calculateTotals(servicesForBranch(bookingCatalog("unconfirmed"), "poonak").slice(0, 2))).toMatchObject({ priceToman: null, durationMinutes: null });
  const selected = servicesForBranch(bookingCatalog("demo"), "poonak").filter(s => ["hair", "facial"].includes(s.id));
  expect(calculateTotals(selected)).toMatchObject({ priceToman: 1_000_000, durationMinutes: 75 });
  const percent = demoPolicies.find(p => p.id === "demo-percent")!;
  expect(calculatePolicyPreview(percent, 1_000_000, false)).toEqual({ deposit: 200_000, remaining: 800_000, error: null });
  expect(calculatePolicyPreview(percent, null, false)).toEqual({ deposit: null, remaining: null, error: null });
  const optional = demoPolicies.find(p => p.id === "demo-optional")!;
  expect(calculatePolicyPreview(optional, 1_000_000, false).deposit).toBe(0);
  expect(calculatePolicyPreview(optional, 1_000_000, true).deposit).toBe(100_000);
  expect(calculatePolicyPreview(demoPolicies[0], null, false)).toEqual({ deposit: 0, remaining: null, error: null });
  expect(calculatePolicyPreview(optional, 50_000, true).error).toContain("بیشتر");
  const snapshot = policyPreviewSnapshot(percent)!;
  expect(snapshot.kind).toBe("preview-only");
  expect(snapshot.policy).not.toBe(percent);
  expect(snapshot.policy.cancellation.windows).not.toBe(percent.cancellation.windows);
});

test("eligibility and reducer reject unconfigured branches and stale selections", () => {
  const min: LocalDate = "2026-10-30", max: LocalDate = "2026-12-28";
  const reduce = createBookingReducer(min, max), catalog = bookingCatalog("unconfirmed");
  let state = initialBookingState("hair");
  expect(reduce(state, { type: "next" }).step).toBe(1);
  expect(reduce(state, { type: "branch", id: "pending" }).draft.branchId).toBeNull();
  state = reduce(state, { type: "branch", id: "poonak" });
  expect(state.draft.serviceIds).toEqual(["hair"]);
  state = reduce(state, { type: "barber", id: "demo-a" });
  state = reduce(state, { type: "date", date: min });
  const slot: DemoTimeSlot = { id: "test", date: min, startTime: "11:30", timeZone: "Asia/Tehran", barberIds: ["demo-a"], durationMinutes: null, selectable: true, source: "demo" };
  const key = availabilityKey(availabilityRequest(state.draft, catalog));
  state = reduce(state, { type: "availabilityLoading", key, requestId: 1 });
  state = reduce(state, { type: "availabilityReady", key, requestId: 1, slots: [slot] });
  state = reduce(state, { type: "slot", id: slot.id, key, requestId: 1 });
  expect(state.draft.slot).toEqual(slot);
  expect(reduce(state, { type: "date", date: min }).draft.slot).toEqual(slot);
  state = reduce(state, { type: "service", id: "massage" });
  expect(state.draft).toMatchObject({ barberId: null, slot: null, date: min });
  expect(eligibleBarbers(catalog, "poonak", state.draft.serviceIds).map(b => b.id)).toEqual(["demo-b"]);
  expect(reduce(state, { type: "barber", id: "demo-a" }).draft.barberId).toBeNull();
  state = reduce(state, { type: "barber", id: "any" });
  expect(reduce(state, { type: "slot", id: slot.id, key, requestId: 1 }).draft.slot).toBeNull();
  state = reduce(state, { type: "branch", id: null });
  expect(state.draft).toMatchObject({ branchId: null, serviceIds: [], barberId: null, date: null, slot: null });
});
