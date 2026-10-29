> Public export note: architecture and private QA below describe source commit `2155872cc626d7463d94500b678d875bec0e4dc6`. Private photographs/fonts/screenshots/history are withheld. The sanitized public app retains public main's placeholders/system fonts; see `PHASE02_PUBLIC_REVIEW.md` for its separate current results and exact text/test-endpoint differences.

# Phase 02 — targeted review corrections

The original private `feature/booking-ui` at `7e56ef7e584830f6a884e677f9002b9ab46ff294` is the development baseline. The owner authorized these corrections and a sanitized update to draft public PR #1. Homepage/Booking layout, CSS, images/fonts, dependencies and fixture values remain unchanged. No backend, database, payment, real enforcement or Phase 03.

## Canonical slots and current requests

The earlier reducer incorrectly checked a supplied slot against `[action.slot]`; the final validator also compared too few fields. Slot actions now contain only an opaque ID, request key and loading generation. They cannot supply a replacement object. The reducer resolves the ID from its **current ready provider response**, checking unique identity, date, valid `HH:mm` time, timezone, duration, selectable status, source and every advertised staff ID against the eligible intersection. One eligible staff ID cannot conceal an unrelated one.

`BookingState.availability` owns the response outside the draft. The request key includes branch, sorted services/staff, date/timezone, duration/buffer and snapshots of selected offerings. A monotonically increasing generation also rejects old clicks/responses after A→B→A edits or retries of the same request. Ready/error actions must match the currently loading generation and freshly derived key. Upstream scheduling edits invalidate the response immediately; reload/retry clears the previous selection. Provider abortion remains.

Responses are validated, copied and frozen, including staff arrays. Mutation of an adapter's original response cannot mutate the selected slot. Next/final-preview actions no longer accept arbitrary slot arrays. Both validate reducer-owned availability; final validation compares all selected fields to the canonical slot and checks the date horizon. Failure clears any old preview/snapshot.

This is frontend consistency, not authorization or capacity protection. The adapter reports availability; JavaScript controlled by a browser user cannot establish real capacity. A future server must revalidate the entire request, availability revision/expiry and financial terms and atomically lock resources. None is implemented here.

## Branch-service offerings

`BookingService` contains shared presentation metadata. `BranchServiceOffering` is authoritative for each `(branchId, serviceId)`: active status, nullable price/duration/buffer, eligible staff IDs and value source. `BookingCatalog.offerings` supplies rows; `servicesForBranch` joins them to the unchanged cards/overview. Missing, inactive, duplicate or malformed configuration fails closed. Eligibility intersects branch membership, staff capabilities and every selected offering's staff list.

Totals and requests use that branch's configuration. Unknown/missing values remain unknown; incomplete selections cannot yield partial totals. Service duration and buffer are separate request fields. Explicit demo mode uses the original prices/durations and a hypothetical zero buffer; real default buffer is unknown. Displayed duration remains service duration, with no claimed end time/capacity. A future provider must honor both duration and the relevant buffer rule. The real second branch remains unconfigured. A synthetic branch exists only in tests to prove differing rates/durations/buffers, activity, timezone and staff restrictions.

## Policy context compatibility

One matcher is shared by reducer, summary and final validator. Branch policies match the selected configured branch. Service policies require an active selected service, optionally restricted to a branch. A service scope without a branch restriction deliberately means that service across configured branches. Package/existing-booking scopes cannot match this MVP, which has neither identity. Unknown/incompatible scenarios cannot be selected or previewed.

Branch/service edits retain a scenario only while compatible; otherwise policy ID and optional deposit reset. Every context edit clears the prior preview snapshot. A still-compatible branch policy can survive service edits. Optional-deposit state is kept only for a compatible optional policy. The picker lists compatible fixtures. These guards do not resolve legal precedence, effective dates, refunds or acceptance.

## Deferred multi-provider model

The MVP retains **one provider for all selected services**, or any provider in the full-service intersection. Do not replace that intersection with a union. A future booking should contain ordered service segments referencing an offering/version, assigned staff/resources, start/end, duration/buffer and sequential/parallel relationship. The booking aggregate retains shared branch/timezone/customer and accepted terms. Availability must return a feasible whole plan, not unrelated per-service slots. Upstream changes invalidate dependent assignments/plans. The server must validate per-segment eligibility/overlap/handoffs and acquire all resource locks atomically so a partial assignment cannot become a partial booking.

Decisions deferred: allowed service ordering/overlap, handoff rules, whether buffers occupy staff/chair/customer, staff selection per segment, whole-booking versus per-segment prices/cancellation and policy precedence. No new selectors or UI complexity are needed now. Effective-policy selection/version acceptance and real scheduling remain future server work.

## Regression evidence

All original cases/assertions remain; existing domain setup was adapted to offerings and ID/provider-lifecycle actions. New cases cover forged objects/metadata, response mutation/duplicate IDs, stale keys/generations, retries/errors, upstream invalidation, actual provider cancellation, branch-specific configuration and incompatible scopes. A browser round trip verifies branch reset does not resurrect an optional deposit.

Initial focused results: typecheck exit 0; installed-Chrome `npm run test:ui -- tests/booking-domain.spec.ts tests/booking-review.spec.ts --project=desktop --reporter=list`: **13 passed**, 2.3s. Final private results are below; sanitized-public results belong to the public export report. Screenshots/logs stay local/private and are never copied to the public branch.


## Final private verification — 2026-10-29

- `npm run typecheck`: exit 0; no diagnostics.
- `npm run build`: exit 0; compiled in 2.7s, 5/5 static pages, dynamic /booking (13.9 kB / 117 kB first load).
- `npm run test:ui`: installed Chrome, CI=true, dedicated original Next.js app on port 3000: **92 passed**, zero failed/skipped/flaky, 192.7s. Four viewports: 1440×900, 1024×768, 390×844, 375×812. Includes 52 domain checks, 24 Booking browser checks and 16 unchanged Homepage browser checks. No console/JS/HTTP/image/overflow failures.
- Protected Homepage/CSS/layout/font/image/reference/business-fact/dependency paths are unchanged from the private baseline. 143/150 existing screenshot files are byte-identical; any differing captures are recorded in `BOOKING_REVIEW_RESULTS.json` for actual visual inspection. Captures and raw logs stay private/local; the public PR receives source/docs and normalized evidence only.
- No real booking, payment, policy enforcement, backend/database, merge or Phase 03. Draft public PR #1 is updated separately from this committed private source; its current public-copy results are recorded in the public export report.

Visual inspection of the differing staff/calendar captures confirms preserved design: the staff card differs only in hover border; five image regions have small compositing differences (maximum channel delta 14); the mobile full-page capture has 77 fewer bottom pixels while its entire common image area is byte-identical. 110 screenshots were regenerated in this actual run; 103 match their previous captures byte-for-byte. No source layout/CSS or content was changed. Historical screenshot files not regenerated are counted separately in the results record.
