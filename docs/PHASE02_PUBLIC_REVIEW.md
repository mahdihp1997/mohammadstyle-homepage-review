# Phase 02 — current sanitized review export

Private development source: `2155872cc626d7463d94500b678d875bec0e4dc6` on `feature/booking-ui`. Original review baseline: `7e56ef7e584830f6a884e677f9002b9ab46ff294`. The correction commit was developed/tested in the original private project, then transferred as source files into the public review branch. Public base remains `f35a5cc20ebd497b0d8fb7b96c207549f147799f`; the earlier public export is `9d284a659fc997e56167e1318fec83b7944d708f`.

Branch: `review/phase02-booking`; [draft PR #1](https://github.com/mahdihp1997/mohammadstyle-homepage-review/pull/1) targets public main. **No merge, private history transfer or Phase 03.**

## Targeted review corrections

- Slot selection passes an ID/key/loading generation only. The reducer resolves the current provider response and checks unique identity, date, valid clock time, timezone, duration, selectable/source flags and every staff ID. Frozen response snapshots prevent mutation. Old responses/clicks are rejected after edits, A→B→A or same-key retries; next/final preview use reducer-owned availability.
- `BranchServiceOffering` carries per-branch price, duration, buffer, activity and eligible staff. Shared service metadata is separate. Cards, totals and requests consume the same selected offering; invalid/duplicate/missing configuration fails closed. Existing demo values/unknown defaults and the unconfigured real second branch remain.
- Shared policy compatibility clears unrelated scenarios and optional deposits after context changes, filters the scenario picker and validates again before final preview. No real policy enforcement is added.
- The single-provider MVP is preserved. Future per-service staff segments, ordering/overlap/buffer/resource-lock decisions are documented in `BOOKING_REVIEW_FIXES.md`.
- Ten new domain cases and one new browser case augment every original test. Existing domain setup was adapted to the new contract without removing assertions. Homepage/layout/CSS/photos/fonts and dependencies remain unchanged in the private implementation.

## Exact public-only differences

All fourteen Phase 01 placeholder WebPs, four labeled AI concepts, system-font layout/CSS, public notice, business facts, dependency manifest/lockfile and public Homepage test configuration remain unchanged from public main. The Homepage keeps its original sanitized descriptions plus the original Phase 02 drawer link.

Only four transferred application/test files have public-specific edits: `BookingWizard.tsx` sidebar alt text; `ServiceSelection.tsx` non-concept image alt template; `booking-demo.ts` branch image alt/caption; and the no-JavaScript test in `booking.spec.ts`, which receives the configured public baseURL rather than private port 3000. These are the same seven reversible substitutions as the initial export. Every other transferred application/test file matches current private source after LF normalization. No Booking rule, fixture number, assertion, calculation or interaction is modified for export.

`data/phase02-public-export-manifest.json` records all 24 transferred application/test files: 20 exact matches and four with the documented text/test-address substitutions. The exact Homepage/CSS delta still matches private Phase 02 over the sanitized public baseline. The full public graph descends only from sanitized public main; private commit objects are absent. All inherited public image and system-font files are checked against main.

Documentation identifies private architecture/QA as such. `BOOKING_REVIEW_FIXES.md` retains the private development/visual-review narrative; the private `BOOKING_REVIEW_RESULTS.json` it mentions is intentionally withheld. Current public-copy evidence is `PHASE02_PUBLIC_REVIEW_RESULTS.json`. Public placeholders/fonts intentionally prevent photographic fidelity approval.

## Private correction file inventory

The private correction commit changes these 19 files. The internal normalized result JSON is withheld; the public copy has its own result JSON and export documentation/manifest updates.

```text
components/booking/BookingSummary.tsx
components/booking/BookingWizard.tsx
components/booking/DateTimeSelection.tsx
components/booking/ServiceSelection.tsx
data/booking-demo.ts
docs/BOOKING_REVIEW_FIXES.md
docs/BOOKING_REVIEW_RESULTS.json
docs/BOOKING_UI.md
docs/VISUAL_REVIEW.md
lib/booking/availability.ts
lib/booking/calculations.ts
lib/booking/catalog.ts
lib/booking/policies.ts
lib/booking/state.ts
lib/booking/validation.ts
tests/booking-domain.spec.ts
tests/booking-review.spec.ts
tests/booking.spec.ts
types/booking.ts
```

## Withheld material

- Original versions of all fourteen client-photo paths; their public placeholders are unchanged. The complete path list is in the historical `data/public-export-manifest.json`.
- `app/fonts/iransans-regular.woff2`, `iransans-bold.woff2`, `kahroba-variable.woff2`; all private visual-reference boards/crops and client/source image directories.
- All private `artifacts/`, internal screenshots/review pages/logs/raw reports/ZIPs, legacy static previews, and `docs/BOOKING_REVIEW_RESULTS.json`. No new binary file is added.
- `scripts/create_booking_review.mjs`, which assembles an internal screenshot report and is neither application nor test logic. The inherited Phase 01 report assembly script remains historical and requires withheld material.
- Private Git objects/history, environment files/credentials, dependencies/caches/build output, test traces and generated public screenshots/raw logs. Ignore rules remain in effect.

## Current public validation

All current commands ran on the corrected public source with its independent installed dependencies. Windows, Node v24.16.0, npm 11.17.0, Next 15.5.28; installed Chrome selected with PLAYWRIGHT_CHANNEL=chrome and CI=true. Playwright started its own public Next.js server on **3010**; the private app on 3000 was not used, including by the no-JavaScript test.

| Command | Exit | Actual result |
| --- | --- | --- |
| `npm run typecheck` | 0 | tsc --noEmit, no diagnostics |
| `npm run build` | 0 | Compiled in 2.7s, 5/5 static pages; /booking dynamic, 13.9 kB / 117 kB first load |
| `npm run test:ui` | 0 | **92 passed** in 179.9s; zero failed/skipped/flaky |

Each of 1440×900, 1024×768, 390×844 and 375×812 passed 23 tests: 52 domain checks, 24 Booking browser checks, 16 Homepage browser checks in total. Includes forged/stale slots, provider cancellation, branch-specific config, incompatible policies, original interactions, hydration/no-JS, Jalali keyboard/date cases, assets, console/HTTP and overflow checks. No browser/JS/hydration/image/network/overflow failures. All original cases/assertions remain. Captures come from the actual Next.js app, not a static preview; they and raw logs/reports remain ignored/local. Non-failing terminal color warnings occurred.

The original private source separately passed typecheck/build and **92 tests** in 192.7s. Publication audit verifies 24 transferred application/test files (20 exact LF-normalized matches, four reversible text/test-endpoint differences), unchanged public images/system-font files and no private binary/history/credential matches. See the source manifest and normalized results JSON. The original locked install from npm ci is retained; no new packages/lock changes were needed for these fixes.

The initial public export passed npm ci, typecheck, build and 48 tests in 163.3s. That historical run belongs to 9d284a6, not this correction. Dependency manifest/lockfile are unchanged; the previously reported two Next/PostCSS audit findings remain, with no unrelated upgrade applied. No production deployment is included.

## Remaining architectural decisions

One provider must still cover all selected services. Per-service assignments require a future whole-plan availability contract and atomic server resource locking. Service ordering/parallelism, buffer occupancy and policy precedence/version acceptance remain unresolved design decisions. Real capacity, persistence, API/database/payment/messaging and policy enforcement remain deferred. Physical-device, Safari and screen-reader speech testing are not claimed. No Phase 03 or merge.
