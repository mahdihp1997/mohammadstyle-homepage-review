> Public export note: architecture and private QA below describe source commit `2155872cc626d7463d94500b678d875bec0e4dc6`. Private photographs/fonts/screenshots/history are withheld. The sanitized public app retains public main's placeholders/system fonts; see `PHASE02_PUBLIC_REVIEW.md` for its separate current results and exact text/test-endpoint differences.

# Phase 02 — Smart booking UI

**Targeted review corrections:** [BOOKING_REVIEW_FIXES.md](BOOKING_REVIEW_FIXES.md) documents canonical slot validation, reducer-owned provider generations, branch-specific offerings, policy-context guards, regression evidence and the deferred service-segment multi-provider model. Homepage/Booking presentation is preserved. The earlier architecture descriptions below are supplemented by that current correction record.

This is an **internal frontend demonstration**, developed in the original local repository on `feature/booking-ui` from `ec033307f82ef1160b188fdd6e405ba7bcdde06f`. The owner explicitly authorized Phase 02 on 2026-10-29 and identified the Phase 1 Homepage as the approved visual baseline. The sanitized public review repository is not the development source and receives no private assets or history.

## Entry and scope

`/booking` is a dedicated App Router route. Existing Homepage booking buttons retain the accessible quick-preview drawer. Its new “شروع رزرو مرحله‌ای نمایشی” link enters the wizard and carries the selected service through a validated `?service=hair` (or other known service ID). Generic entry has no service preselected; unknown query values are ignored. This preserves the approved Homepage composition and every existing drawer interaction/test. A disabled real-booking continuation remains distinct from the enabled demo entry.

Five steps: branch → multiple services → eligible demo barber / any eligible barber → Jalali date and demo time → summary and policy preview. No customer identity, login, API, database, payment, messaging, real schedule, reservation, or financial transaction is created. Reload resets the ephemeral draft. No browser storage is used.

## Components

| File in `components/booking/` | Responsibility |
| --- | --- |
| `BookingWizard.tsx` | Single reducer owner, provider lifecycle, derived catalog/totals, validation/focus, desktop summary and mobile navigation |
| `BookingStepper.tsx` | Numbered RTL progress; current-step announcement and backward navigation |
| `BranchSelection.tsx` | Poonak demo configuration and disabled unconfigured second branch |
| `ServiceSelection.tsx` | Six exact services, native multi-select checkboxes, unknown-value/default and explicit fixture switch |
| `BarberSelection.tsx` | Reusable `BarberProfile`, fictional avatars, full-service eligibility and “any” option |
| `JalaliCalendar.tsx` | Date-only Persian calendar, month navigation, bounded dates and keyboard navigation |
| `DateTimeSelection.tsx` | Calendar and asynchronous loading/empty/error/selected demo slots |
| `BookingSummary.tsx` | Reusable derived overview, edits, policy-scenario controls |
| `BookingPolicySummary.tsx` | Policy presentation only; receives an already-calculated preview |
| `BookingNavigation.tsx` | Validated next/back and clearly named final preview action |

`app/booking/booking.css` is scoped to the booking page; the only Homepage CSS addition styles the new link inside the existing drawer. Colors, fonts, icons and button styles come from the existing design system. No dependency was added or upgraded.

## Data contracts and state

`types/booking.ts` defines branch configuration/timezone, service values and source, demo barber assignments, availability requests/responses, date/time types, draft, typed reducer actions and versioned policy contracts. `data/booking-demo.ts` is the only source of fictional staff, eligibility, prices/durations, slots and policy examples. Brochure names and business facts are reused from the existing source of truth; `data/business-facts.json` remains unchanged.

`BookingState.draft` is authoritative. Components receive selected values and dispatch callbacks, rather than owning duplicate selection state. Branch-service offerings supply values and eligibility; catalogs, totals, summaries and request keys are derived. The reducer owns current provider state outside the draft; calendar focus/month and retry triggers remain view state. Slot actions carry only an ID/key/generation, and next/preview validate reducer-owned responses.

| Action | Invalidation / preservation |
| --- | --- |
| Change branch | Reject unconfigured branch; retain only eligible services; clear barber/date/slot |
| Toggle service | Preserve still-eligible barber and valid date; clear incompatible barber and always invalidate slot |
| Change barber | Keep date; invalidate slot |
| Change date | Keep upstream choices; invalidate slot; reselecting the same date preserves its valid slot |
| Change price/duration fixture mode | Keep chosen services/barber/date; invalidate slot because duration may change |
| Change policy/optional deposit | Recalculate illustration; clear previous preview result/snapshot; do not invalidate scheduling choices |
| Back / previous step | Keep valid choices; validate again when proceeding |

`lib/booking/validation.ts` checks configured branch, nonempty/eligible service set, barber intersection, date horizon and a selected slot in the currently returned provider set. The reducer rejects disabled/stale staff/slot choices. The final preview validates the whole draft again. Financial unknowns are explicit, not silently replaced with zero or partial totals.

The SSR-rendered form is disabled until the client mounts. This prevents a fast click during hydration from performing the browser's native GET submission. A no-JavaScript explanation is supplied. Errors have inline group references, a focusable alert and a link back to the relevant controls; step changes focus the heading and final preview focuses its result.

## Dates, timezones and provider seam

Domain dates are Gregorian `YYYY-MM-DD` strings; local times are `HH:mm` plus an explicit IANA timezone. The server captures “today” once in `Asia/Tehran` for the initial render. There is no browser/OS-timezone dependency or client/server midnight recalculation. The demo window is tomorrow through today+60; outside-window dates are disabled, without implying the salon is closed on them.

Persian presentation uses `Intl.DateTimeFormat` with the `persian` calendar and `formatToParts`; local Gregorian day arithmetic uses a UTC-noon carrier that is never treated as an appointment instant. Month starts/lengths are derived from calendar parts, including leap Esfand. Tests cover Nowruz, 1403 Esfand 30, month transitions, Gregorian leap day, ISO validation and Tehran midnight. See [Intl.DateTimeFormat](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/DateTimeFormat) and [formatToParts](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/DateTimeFormat/formatToParts).

The calendar starts on Saturday; native day buttons use roving focus with RTL Left/Right, Up/Down, Home/End and Page Up/Down. Enter/Space select. Month buttons respect the horizon. Slots carry local date/time/timezone; no current UTC offset is hardcoded. A future backend must resolve and validate instants using branch timezone rules and handle ambiguous/nonexistent local times.

`AvailabilityProvider.loadSlots(request, signal)` is an asynchronous seam for future REST integration. The current implementation waits 450ms locally, supports cancellation and returns fixed **labeled demo** slots. The first slot is disabled; today+2 is deliberately empty. An exact request key gates rendering, aborted requests cannot replace current results, and upstream edits cannot retain a stale selected slot. Unknown durations do not yield a claimed end time or real capacity calculation. “Any barber” requests carry the eligible barber IDs; actual assignment/locking belongs to the future server.

## Policy preview architecture

Typed contracts support none/optional/required deposits; fixed amounts or integer basis-point percentages; full/non/partial refunds; cancellation windows; branch/service/package/booking scopes; override references; effective date ranges and versions. `AcceptedPolicySnapshot` is a future server contract, not something this demo creates.

The default policy is **unconfirmed**. The optional scenario selector offers plainly labeled fictional no-deposit, optional-fixed/full-refund, required-percent/time-window, required-fixed/nonrefundable and required-percent/full-refund examples. Optional deposit has an explicit demo toggle. No client clock or fixture is used to enforce a cancellation deadline, select the legally effective policy or decide precedence.

`lib/booking/calculations.ts` separates complete service totals, arithmetic-only deposit/remainder calculations and a cloned **preview-only** policy version snapshot from visual components. Missing inputs remain unknown. An oversized fixed deposit is reported as uncalculable rather than silently clamped or producing a negative remainder. No policy acceptance, signature, payment or real booking snapshot is recorded. The final action says “نمایش پیش‌نمایش نهایی”, and the result explicitly says no appointment/payment was registered.

## Visual decisions and limitations

- Carries forward charcoal surfaces, restrained champagne borders/CTAs, local Kahroba/IRANSans and photographic editorial context. No generic template, new palette, whole-board background or new font/image package.
- Uses the booking panels in boards A/B/C; the standalone `05-booking-stepper.png` is absent from the supplied `references/`, so no missing crop is claimed as inspected.
- The reference's four compressed phases become the requested five accessible steps. Payment/success screens are omitted. The required demo banner and explicit unknowns replace misleading AI labels and invented numbers.
- Desktop uses a main panel and derived sticky overview. Tablet stacks calendar/slots inside the panel. Mobile uses single-column choices, choice text before branch photography, 44px calendar day targets, a persistent safe-area action bar and a collapsible overview. Fixed navigation can appear across the middle of a stitched full-page mobile screenshot; the separate viewport captures show its actual placement at the viewport bottom.
- The Poonak card uses the supplied collection interior with an explicit notice that branch-specific photo attribution is unverified. No second-branch photo, real staff identity, rating or schedule was invented. Existing conceptual service-photo badges remain.
- All client assets/fonts remain private and byte-for-byte unchanged. The browser evidence is internal review material. Physical phones, Safari and screen-reader speech still require dedicated verification; no such coverage is claimed.
- Demo reload discards the draft; there is no persistence, concurrency guarantee, capacity engine, authoritative financial calculation, or effective-policy resolution.

## Validation and review

See the current Phase 02 section in `VISUAL_REVIEW.md` for observed command results, initial failures/fixes, screenshot links and approval status. Phase 1 historical evidence is retained separately. Stop after frontend delivery and request owner visual/technical review before backend/database/real booking/payment work. No private remote is configured; keep the feature branch local and do not push internal history to the public review repository.
