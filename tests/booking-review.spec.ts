import { test, expect } from "@playwright/test";
import { bookingCatalog, createDemoAvailability, demoPolicies } from "../data/booking-demo";
import { createBookingReducer, initialBookingState } from "../lib/booking/state";
import { availabilityKey, availabilityRequest, validSlot } from "../lib/booking/availability";
import { branchOffering, eligibleBarbers, servicesForBranch, validServices } from "../lib/booking/catalog";
import { calculateTotals } from "../lib/booking/calculations";
import { policyAppliesToDraft } from "../lib/booking/policies";
import { validateStep } from "../lib/booking/validation";
import type { BookingAction, BookingCatalog, BookingPolicyVersion, BookingState, DemoTimeSlot, LocalDate } from "../types/booking";

const min: LocalDate = "2026-10-30", max: LocalDate = "2026-12-28";
type Reducer = ReturnType<typeof createBookingReducer>;
function setup(catalog = bookingCatalog("demo"), policies = demoPolicies) {
  const reduce = createBookingReducer(min, max, { catalog: () => catalog, policies });
  let state = initialBookingState("hair");
  for (const action of [ { type: "branch", id: "poonak" }, { type: "pricing", mode: "demo" }, { type: "barber", id: "any" }, { type: "date", date: min } ] as BookingAction[]) state = reduce(state, action);
  return { catalog, reduce, state };
}
function response(reduce: Reducer, state: BookingState, catalog: BookingCatalog, slots?: DemoTimeSlot[]) {
  const request = availabilityRequest(state.draft, catalog)!;
  const key = availabilityKey(request), requestId = state.availability.requestId + 1;
  const slot: DemoTimeSlot = { id: "provider-slot", date: request.date, startTime: "11:30", timeZone: request.timeZone,
    durationMinutes: request.durationMinutes, barberIds: [request.barberIds[0]], selectable: true, source: "demo" };
  state = reduce(state, { type: "availabilityLoading", key, requestId });
  state = reduce(state, { type: "availabilityReady", key, requestId, slots: slots ?? [slot] });
  return { state, slot, key, requestId };
}
function pick(reduce: Reducer, loaded: ReturnType<typeof response>) {
  return reduce(loaded.state, { type: "slot", id: loaded.slot.id, key: loaded.key, requestId: loaded.requestId });
}

test("slot selection accepts only a provider ID; forged objects cannot become the draft slot", () => {
  const { reduce, catalog, state } = setup(), loaded = response(reduce, state, catalog);
  expect(reduce(state, { type: "slot", id: loaded.slot.id, key: loaded.key, requestId: loaded.requestId }).draft.slot).toBeNull();
  expect(reduce(loaded.state, { type: "slot", id: "invented", key: loaded.key, requestId: loaded.requestId }).draft.slot).toBeNull();
  const forged = { ...loaded.slot, startTime: "23:59" };
  expect(reduce(loaded.state, { type: "slot", slot: forged } as unknown as BookingAction).draft.slot).toBeNull();
  const action = { type: "slot" as const, id: loaded.slot.id, key: loaded.key, requestId: loaded.requestId, slot: forged };
  const selected = reduce(loaded.state, action);
  expect(selected.draft.slot?.startTime).toBe("11:30");
  expect(selected.draft.slot).toBe(loaded.state.availability.slots[0]);
  expect(Object.isFrozen(selected.draft.slot)).toBe(true);
  expect(Object.isFrozen(selected.draft.slot?.barberIds)).toBe(true);
  const mutableInput = { ...loaded.slot, barberIds: [...loaded.slot.barberIds] };
  const snapshot = response(reduce, state, catalog, [mutableInput]);
  mutableInput.startTime = "23:59"; mutableInput.barberIds.push("unrelated");
  expect(pick(reduce, snapshot).draft.slot).toMatchObject({ startTime: "11:30", barberIds: ["demo-a"] });
});

test("slot metadata, selectable status, staff and duplicate identities are checked again at final preview", () => {
  const { reduce, catalog, state } = setup(), loaded = response(reduce, state, catalog), selected = pick(reduce, loaded);
  expect(reduce(selected, { type: "preview" }).previewViewed).toBe(true);
  const changes: Partial<DemoTimeSlot>[] = [
    { id: "forged-id" }, { date: "2026-10-31" }, { startTime: "12:00" }, { timeZone: "UTC" },
    { durationMinutes: 999 }, { selectable: false }, { barberIds: ["demo-c"] }, { barberIds: ["demo-a", "demo-c"] },
    { source: "forged-source" as DemoTimeSlot["source"] },
  ];
  for (const change of changes) {
    const forgedDraft = { ...selected.draft, slot: { ...loaded.slot, ...change } };
    expect(validSlot(forgedDraft, catalog, loaded.state.availability), JSON.stringify(change)).toBe(false);
    const preview = reduce({ ...selected, draft: forgedDraft, previewViewed: true }, { type: "preview" });
    expect(preview.previewViewed).toBe(false); expect(preview.error).toContain("ساعت"); expect(preview.policyPreview).toBeNull();
  }
  for (const change of changes.slice(1).concat([{ startTime: "25:00" }, { barberIds: ["demo-a", "demo-a"] }])) {
    if (change.startTime === "12:00") continue; // A provider may legitimately return another valid time; a forged selected copy may not.
    const malformed = response(reduce, state, catalog, [{ ...loaded.slot, ...change }]);
    expect(pick(reduce, malformed).draft.slot, JSON.stringify(change)).toBeNull();
  }
  const duplicates = response(reduce, state, catalog, [loaded.slot, { ...loaded.slot, startTime: "12:00" }]);
  expect(duplicates.state.availability.slots).toEqual([]);
  expect(pick(reduce, duplicates).draft.slot).toBeNull();
});

test("late responses and clicks are rejected across A-B-A dates, same-key retries and errors", () => {
  const { reduce, catalog, state } = setup(), first = response(reduce, state, catalog);
  let current = reduce(pick(reduce, first), { type: "date", date: "2026-10-31" });
  const secondKey = availabilityKey(availabilityRequest(current.draft, catalog));
  current = reduce(current, { type: "availabilityLoading", key: secondKey, requestId: 2 });
  current = reduce(current, { type: "date", date: min });
  expect(reduce(current, { type: "availabilityLoading", key: first.key, requestId: 1 })).toBe(current);
  current = reduce(current, { type: "availabilityLoading", key: first.key, requestId: 3 });
  for (const stale of [
    { type: "availabilityReady", key: first.key, requestId: 1, slots: [first.slot] },
    { type: "availabilityReady", key: secondKey, requestId: 2, slots: [first.slot] },
    { type: "availabilityError", key: first.key, requestId: 1, message: "stale failure" },
  ] as BookingAction[]) expect(reduce(current, stale)).toBe(current);
  current = reduce(current, { type: "availabilityReady", key: first.key, requestId: 3, slots: [first.slot] });
  expect(reduce(current, { type: "slot", id: first.slot.id, key: first.key, requestId: 1 }).draft.slot).toBeNull();
  current = reduce(current, { type: "slot", id: first.slot.id, key: first.key, requestId: 3 });
  expect(current.draft.slot).not.toBeNull();
  current = reduce(current, { type: "availabilityLoading", key: first.key, requestId: 4 });
  expect(current.draft.slot).toBeNull(); expect(reduce(current, { type: "preview" }).previewViewed).toBe(false);
  expect(reduce(current, { type: "availabilityReady", key: first.key, requestId: 3, slots: [first.slot] })).toBe(current);
  current = reduce(current, { type: "availabilityError", key: first.key, requestId: 4, message: "current failure" });
  expect(current.availability.status).toBe("error");
  expect(reduce(current, { type: "availabilityReady", key: first.key, requestId: 4, slots: [first.slot] })).toBe(current);
  expect(reduce(current, { type: "slot", id: first.slot.id, key: first.key, requestId: 4 }).draft.slot).toBeNull();
});

test("every scheduling edit immediately invalidates the authoritative availability response", () => {
  const { reduce, catalog, state } = setup(), loaded = response(reduce, state, catalog), selected = pick(reduce, loaded);
  const edits: BookingAction[] = [{ type: "branch", id: null }, { type: "service", id: "facial" }, { type: "barber", id: "demo-a" }, { type: "date", date: "2026-10-31" }, { type: "pricing", mode: "unconfirmed" }];
  for (const edit of edits) {
    const changed = reduce(selected, edit);
    expect(changed.draft.slot, edit.type).toBeNull(); expect(changed.availability.status).toBe("idle");
    expect(reduce(changed, { type: "slot", id: loaded.slot.id, key: loaded.key, requestId: loaded.requestId }).draft.slot).toBeNull();
    expect(reduce(changed, { type: "availabilityReady", key: loaded.key, requestId: loaded.requestId, slots: [loaded.slot] })).toBe(changed);
    expect(reduce(changed, { type: "preview" }).previewViewed).toBe(false);
  }
  expect(reduce(selected, { type: "policy", id: "demo-none" }).draft.slot).toBe(selected.draft.slot);
});

function twoBranchCatalog() {
  const catalog = structuredClone(bookingCatalog("demo"));
  // Synthetic test configuration only; does not configure the real, unconfirmed second branch.
  catalog.branches.push({ id: "test-branch", name: "test-only branch", location: null, demoConfigured: true, timeZone: "Asia/Dubai", image: null });
  catalog.barbers.forEach(barber => barber.branchIds.push("test-branch"));
  catalog.offerings.push({ branchId: "test-branch", serviceId: "hair", active: true, priceToman: 900_000, durationMinutes: 60, bufferMinutes: 15, barberIds: ["demo-a"], valueSource: "demo" },
    { branchId: "test-branch", serviceId: "facial", active: false, priceToman: 800_000, durationMinutes: 40, bufferMinutes: 5, barberIds: ["demo-b"], valueSource: "demo" });
  return catalog;
}

test("branch-specific offerings drive rates, durations, buffers, active state and staff intersection", () => {
  const { reduce, catalog, state } = setup(twoBranchCatalog());
  const hair = (branch: string) => servicesForBranch(catalog, branch).filter(s => s.id === "hair");
  expect(calculateTotals(hair("poonak"))).toMatchObject({ priceToman: 400_000, durationMinutes: 30, bufferMinutes: 0 });
  expect(calculateTotals(hair("test-branch"))).toMatchObject({ priceToman: 900_000, durationMinutes: 60, bufferMinutes: 15 });
  let changed = reduce(state, { type: "branch", id: "test-branch" });
  expect(changed.draft).toMatchObject({ serviceIds: ["hair"], barberId: null, date: null, slot: null });
  expect(reduce(changed, { type: "service", id: "facial" }).draft.serviceIds).toEqual(["hair"]);
  expect(reduce(changed, { type: "service", id: "manicure" }).draft.serviceIds).toEqual(["hair"]);
  expect(eligibleBarbers(catalog, "test-branch", ["hair"]).map(b => b.id)).toEqual(["demo-a"]);
  expect(reduce(changed, { type: "barber", id: "demo-b" }).draft.barberId).toBeNull();
  changed = reduce(changed, { type: "barber", id: "any" }); changed = reduce(changed, { type: "date", date: min });
  const request = availabilityRequest(changed.draft, catalog)!;
  expect(request).toMatchObject({ branchId: "test-branch", durationMinutes: 60, bufferMinutes: 15, timeZone: "Asia/Dubai", barberIds: ["demo-a"] });
  expect(request.offerings[0]).toMatchObject({ priceToman: 900_000, durationMinutes: 60, bufferMinutes: 15 });
  expect(pick(reduce, response(reduce, changed, catalog)).draft.slot).toMatchObject({ durationMinutes: 60, timeZone: "Asia/Dubai", barberIds: ["demo-a"] });
  const incomplete = servicesForBranch(catalog, "test-branch").filter(s => ["hair", "facial"].includes(s.id));
  expect(calculateTotals(incomplete)).toMatchObject({ priceToman: null, durationMinutes: null });
});

test("missing, inactive, duplicate and invalid branch configuration fails closed without partial totals", () => {
  for (const mutate of [
    (c: BookingCatalog) => { c.offerings = c.offerings.filter(o => o.serviceId !== "hair"); },
    (c: BookingCatalog) => { c.offerings.find(o => o.serviceId === "hair")!.active = false; },
    (c: BookingCatalog) => { c.offerings.push({ ...c.offerings.find(o => o.serviceId === "hair")! }); },
    (c: BookingCatalog) => { c.offerings.find(o => o.serviceId === "hair")!.priceToman = -1; },
    (c: BookingCatalog) => { c.offerings.find(o => o.serviceId === "hair")!.durationMinutes = 0; },
    (c: BookingCatalog) => { c.offerings.find(o => o.serviceId === "hair")!.bufferMinutes = -1; },
  ]) {
    const { catalog, state } = setup(); mutate(catalog);
    expect(validServices(state.draft, catalog)).toBe(false); expect(availabilityRequest(state.draft, catalog)).toBeNull();
    expect(eligibleBarbers(catalog, "poonak", ["hair"])).toEqual([]);
    expect(calculateTotals(servicesForBranch(catalog, "poonak").filter(s => ["hair", "facial"].includes(s.id)))).toMatchObject({ priceToman: null, durationMinutes: null });
  }
});

test("configuration snapshots invalidate old slots when branch timezone or an offering changes", () => {
  const { catalog, state } = setup();
  let currentCatalog = catalog;
  const reduce = createBookingReducer(min, max, { catalog: () => currentCatalog });
  const loaded = response(reduce, state, catalog), selected = pick(reduce, loaded);
  for (const mutate of [
    (c: BookingCatalog) => { c.branches[0].timeZone = "UTC"; },
    (c: BookingCatalog) => { c.offerings.find(o => o.serviceId === "hair")!.bufferMinutes = 10; },
    (c: BookingCatalog) => { c.offerings.find(o => o.serviceId === "hair")!.durationMinutes = 60; },
    (c: BookingCatalog) => { c.offerings.find(o => o.serviceId === "hair")!.priceToman = 500_000; },
    (c: BookingCatalog) => { c.offerings.find(o => o.serviceId === "hair")!.barberIds = ["demo-b"]; },
  ]) {
    currentCatalog = structuredClone(catalog); mutate(currentCatalog);
    expect(availabilityKey(availabilityRequest(selected.draft, currentCatalog))).not.toBe(loaded.key);
    expect(validSlot(selected.draft, currentCatalog, selected.availability)).toBe(false);
    expect(reduce(selected, { type: "preview" }).previewViewed).toBe(false);
  }
  expect(branchOffering(catalog, "poonak", "hair")?.bufferMinutes).toBe(0);
});

test("policy context changes clear incompatible scenarios, optional deposits and preview snapshots", () => {
  const base = demoPolicies.find(p => p.id === "demo-optional")!;
  const servicePolicy: BookingPolicyVersion = { ...base, id: "test-hair-policy", scope: { kind: "service", serviceId: "hair", branchId: "poonak" } };
  const policies = [...demoPolicies, servicePolicy, { ...base, id: "other-branch", scope: { kind: "branch", branchId: "test-branch" } } as BookingPolicyVersion,
    { ...servicePolicy, id: "other-service", scope: { kind: "service", serviceId: "facial" } } as BookingPolicyVersion,
    { ...base, id: "package-policy", scope: { kind: "package", packageId: "unselected" } } as BookingPolicyVersion,
    { ...base, id: "booking-policy", scope: { kind: "booking", bookingId: "not-created" } } as BookingPolicyVersion];
  const { reduce, catalog, state } = setup(twoBranchCatalog(), policies);
  for (const policy of policies.slice(-4)) {
    expect(policyAppliesToDraft(policy, state.draft, catalog)).toBe(false);
    expect(reduce(state, { type: "policy", id: policy.id }).draft.policyId).toBeNull();
  }
  let selected = reduce(pick(reduce, response(reduce, state, catalog)), { type: "policy", id: servicePolicy.id });
  selected = reduce(selected, { type: "optionalDeposit", value: true }); selected = reduce(selected, { type: "preview" });
  expect(selected.policyPreview?.policyId).toBe(servicePolicy.id);
  selected = reduce(selected, { type: "service", id: "facial" });
  expect(selected.draft.policyId).toBe(servicePolicy.id); expect(selected.policyPreview).toBeNull();
  selected = reduce(selected, { type: "service", id: "hair" });
  expect(selected.draft).toMatchObject({ policyId: null, optionalDeposit: false }); expect(selected.previewViewed).toBe(false);
  const branchPolicy = reduce(reduce(state, { type: "policy", id: base.id }), { type: "optionalDeposit", value: true });
  expect(reduce(branchPolicy, { type: "service", id: "facial" }).draft).toMatchObject({ policyId: base.id, optionalDeposit: true });
  for (const id of [null, "test-branch"]) expect(reduce(branchPolicy, { type: "branch", id }).draft).toMatchObject({ policyId: null, optionalDeposit: false });
});

test("final validation rejects an injected unrelated policy even with an otherwise valid current slot", () => {
  const unrelated: BookingPolicyVersion = { ...demoPolicies[0], id: "unrelated", scope: { kind: "branch", branchId: "elsewhere" } };
  const policies = [...demoPolicies, unrelated], { catalog, state, reduce } = setup(bookingCatalog("demo"), policies);
  const selected = pick(reduce, response(reduce, state, catalog));
  const draft = { ...selected.draft, policyId: unrelated.id };
  expect(validateStep(draft, 5, catalog, selected.availability, min, max, policies)).toContain("سیاست");
  const result = reduce({ ...selected, draft }, { type: "preview" });
  expect(result.previewViewed).toBe(false); expect(result.policyPreview).toBeNull();
});

test("the actual cancellable demo provider supplies slots resolved against the same request", async () => {
  const { reduce, catalog, state } = setup();
  const request = availabilityRequest(state.draft, catalog)!, provider = createDemoAvailability("2026-10-29");
  const slots = await provider.loadSlots(request, new AbortController().signal);
  const loaded = response(reduce, state, catalog, slots);
  expect(reduce(loaded.state, { type: "slot", id: slots[0].id, key: loaded.key, requestId: loaded.requestId }).draft.slot).toBeNull();
  expect(reduce(loaded.state, { type: "slot", id: slots[1].id, key: loaded.key, requestId: loaded.requestId }).draft.slot).toMatchObject({ startTime: "11:30", durationMinutes: 30 });
  const abort = new AbortController(), pending = provider.loadSlots(request, abort.signal);
  abort.abort(); await expect(pending).rejects.toMatchObject({ name: "AbortError" });
});
