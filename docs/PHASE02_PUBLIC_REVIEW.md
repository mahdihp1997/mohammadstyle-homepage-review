# Phase 02 — sanitized public code-review export

Date: 2026-10-29. Source: private commit `7e56ef7e584830f6a884e677f9002b9ab46ff294`. Public base: `f35a5cc20ebd497b0d8fb7b96c207549f147799f`. Branch: `review/phase02-booking`. Target: public `main`; **draft PR only, no merge, no Phase 03**.

## Transfer and functional parity

The export was prepared in a fresh clone of public main. Only an explicit source-file allowlist was read from the private working tree, whose clean HEAD was verified against the supplied commit. No private repository was added as a remote, fetched, merged or cherry-picked. Public main retains its original independent root. The original private branch, commit, source, assets and history are unchanged.

Twenty new application/test files supply the Booking route/CSS, ten Booking components, typed contracts, demo data, reducer, calculations, validation, Jalali utilities and two test suites. The exact private Phase 02 drawer delta was applied to the already-sanitized public Homepage. No application dependency/lockfile changes were needed.

Domain behavior is retained: five steps; validated service query; branch/service/barber eligibility; one reducer with the same invalidation rules; cancellable asynchronous demo availability; Tehran-local dates and Jalali keyboard/month navigation; unknown real prices/durations; opt-in sample values; versioned policy preview arithmetic; final validation and preview-only output. No fixture, rule, number, scheduling choice, API/persistence behavior, test case or assertion was dropped or weakened.

The source manifest records LF-normalized SHA-256 hashes and a reversible string-only allowlist. Exact matches are required for all domain modules/contracts/date utilities, route/CSS, remaining components and domain tests. Reversing the four presentation strings and three test-endpoint edits must reproduce the private source. All pre-existing public images, fonts/layout substitutes, business facts and dependencies are checked against public main.

## Exact sanitization differences

| Path | Difference from the private implementation |
| --- | --- |
| `public/images/*.webp` | The same fourteen neutral labeled Phase 01 placeholders remain byte-for-byte unchanged. No private photograph is copied. |
| `public/images/mohammadstyle-images/*.webp` | The same four permitted, visibly labeled AI service concepts remain unchanged from public main. |
| `app/layout.tsx`, `app/public-review.css` | Existing system fonts (Tahoma/Arial), public notice and layout preserved unchanged. Private local-font imports/binaries remain absent. |
| `components/Homepage.tsx` | Inherited Phase 01 placeholder descriptions/copy remain; only the exact private Phase 02 drawer link/copy is added. |
| `components/booking/BookingWizard.tsx` | Sidebar image alt string describes the public placeholder. No logic changes. |
| `components/booking/ServiceSelection.tsx` | Non-concept service-image alt template describes public placeholders. Concept labels, selections and logic unchanged. |
| `data/booking-demo.ts` | Only the Poonak image alt/caption describe the placeholder. Every fixture, policy, calculation input and provider remains unchanged. |
| `playwright.config.ts`, `tests/homepage.spec.ts` | Existing public Phase 01 setup remains: port 3010, system-font/notice expectations. All original interactions/diagnostics are retained. |
| `tests/booking.spec.ts` | No-JavaScript context now receives Playwright's configured baseURL and uses a relative route, instead of hardcoding private port 3000. All assertions and five test cases remain. |
| Documentation and manifest | Current public instructions/results and explicit sanitization. Architecture notes are labeled as describing the private counterpart. Earlier Phase 01 source/report snapshots remain historical. |

## Omitted files and material

- Private `app/fonts/iransans-regular.woff2`, `iransans-bold.woff2`, `kahroba-variable.woff2`.
- Original versions of fourteen client-photo paths (full path list in `data/public-export-manifest.json`). The public placeholders at those paths are retained.
- All private `references/` boards/crops, other client/source image directories and all internal screenshot binaries.
- All private `artifacts/` (including `OWNER_REVIEW_BOOKING.html`, screenshot manifests, Playwright JSON, command logs and screenshot trees), private review ZIPs and legacy static preview outputs.
- `scripts/create_booking_review.mjs`: internal report assembly depends on withheld screenshots/reference images. It is not runtime logic or a test. The inherited Phase 01 assembly script is historical and also requires withheld material.
- Private Git directories/objects/history, caches, build output, node_modules, test traces/reports, environment files and credentials. Local public test captures/reports are ignored and not published.

## Validation of this public copy

All commands below ran in the fresh public checkout with its own physical node_modules directory (no dependency junction to the private project). Package manifest/lockfile stayed unchanged. Node v24.16.0, npm 11.17.0, Next 15.5.28, Windows; installed Google Chrome selected with PLAYWRIGHT_CHANNEL=chrome. CI=true forced Playwright to launch its own public Next.js server on 3010. NEXT_TELEMETRY_DISABLED=1 was set. npm used a separate local cache outside the repository.

| Command | Exit | Actual result |
| --- | --- | --- |
| `npm ci` | 0 | Added 29 packages; audited 30; two existing dependency findings. |
| `npm run typecheck` | 0 | tsc --noEmit, no diagnostics. |
| `npm run build` | 0 | Compiled in 6.0s; 5/5 static pages; /booking dynamically server-rendered. |
| `npm run test:ui` | 0 | **48 passed** in 163.3s; zero failed/skipped/flaky. |

Coverage: 12 Booking domain checks (the same three tests in each project), 20 Booking browser checks and 16 Homepage browser checks. Each viewport passes 12 tests: 1440×900, 1024×768, 390×844 and 375×812. Assertions cover all five steps, service query/unknown query, defaults and demo totals/policy scenarios, upstream invalidation/eligibility, empty and asynchronous availability, Jalali leap/Nowruz/Tehran boundaries and keyboard/month controls, hydration/no-JavaScript safeguards, mobile targets, Homepage menu/filter/Before-After/drawer focus behavior, and image/network/console/overflow health. No test case or assertion was removed. These are actual Next.js browser results, not static-preview QA.

The actual public tests generated local screenshots at all four sizes. Public desktop and mobile captures were inspected to confirm the inherited placeholders, system fonts, disclosure and demo labels. Generated screenshots, traces, raw Playwright JSON and raw command logs remain local and excluded; normalized results are in `PHASE02_PUBLIC_REVIEW_RESULTS.json`.

Publication audit: 173 unique withheld private binary hashes checked; zero original binary matches, new binary files, forbidden paths or credential-pattern matches. All 18 public image files and the existing system-font files remain unchanged. Sixteen of the 20 new application/test files match private source exactly after LF normalization; the other four match after reversing only the seven documented text/test-endpoint substitutions. The Homepage/CSS Phase 02 delta exactly matches the private delta over the sanitized public baseline. The private commit object is absent from the public clone; its sole root remains sanitized public main.

`npm audit --json` additionally records two findings (one moderate, one high) through Next/PostCSS. npm proposes a major Next upgrade; none was applied in this export. Non-failing NO_COLOR/FORCE_COLOR terminal warnings occurred during Playwright. No browser/application errors were observed. See the normalized evidence and source manifest for reproducible checks.

## Review limits

Images/font metrics intentionally differ from the internal approved visual baseline. The public copy is suitable for application/domain/interaction review, not photographic fidelity approval. Booking remains a local frontend demonstration: no reservation, payment, authentication, backend, database, notifications or authoritative capacity/policy engine. The second branch is unconfigured; real staff, prices, durations and policies remain unconfirmed. Physical-device, Safari and screen-reader speech verification are not claimed. Phase 02 visual/technical approval remains pending; stop before Phase 03.
