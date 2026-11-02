## Latest visual review: MVP admin and portfolio — 2026-10-30

Actual Next.js dev app captured at 1440×900, 1024×768, 390×844 and 375×812. Nine admin panes, rights-gated public gallery, full image dialog and video playback reviewed. New media are explicitly synthetic test patterns; original client images/fonts/references remain private and unchanged. Homepage/Booking visual source and DEMO are preserved. Final actual results: frontend/backend npm ci, typecheck and build pass; 41 integration +5 native schema +7 SDK protocol cases; 23 new browser +92 existing Homepage/DEMO +12 existing SERVER pass. Nine redundant cross-size mutation repeats intentionally skipped; zero failures/flaky. Gallery focus return, asynchronous error focus, REQUESTED/legacy exception controls and concurrent private thumbnail delivery were fixed and regression-tested. Original B0–B4 bodies pass on disposable clones. Detailed changes/deviations/results: `docs/backend/mvp-integration/VISUAL_REVIEW.md` and `evidence/VALIDATION.json`. Earlier static/Phase 01/02 reports below do not describe this new backend phase. Owner approval pending; no production release.

# Visual review — Task 01 / Phase 1 Homepage

**Phase 02 update (2026-10-29):** The latest owner request approves this internal Homepage as the baseline and explicitly authorizes the Smart Booking UI. The historical Phase 1 approval-pending statements below describe the earlier review. See the Phase 02 section at the end for current implementation/evidence. Phase 02 visual and technical sign-off is still required before backend work.

Reviewed 2026-10-28. Technical gates pass. **Owner visual approval is pending; stop before Phase 2.** All screenshots described below are from the actual Next.js React app at `http://127.0.0.1:3000/`, launched with `npm run dev`, not from the static HTML preview.

## Baseline and preserved scope

The supplied ZIP was extracted intact. The existing Next App Router components and CSS were improved in place; no application scaffolding or template replacement was performed. Baseline Git commit: `d1b485b` (`chore: preserve supplied homepage baseline`). See `CODEX_BASELINE.md` for the initial inventory.

All fourteen original client WebP files and `data/business-facts.json` remain unchanged. `data/site.ts` and image-provenance data now include the owner's barber-photo correction and four explicitly requested conceptual service images. Exactly these services remain: استایل دامادی، هیرکات مو، فیشیال صورت، ماساژ، مانیکور، پدیکور. Brand, brochure title, confirmed Poonak location and Instagram link remain as supplied. No APIs, database, booking, prices, durations, available appointments, policies, invented staff identities, reviews, or messaging were added.

## Actual implementation changes

- `app/layout.tsx`, `app/fonts/`: owner-supplied local Kahroba variable font for Persian display text and IRANSans regular/bold for body copy and controls, served through `next/font/local`. Weight-axis metadata was checked; active font files load successfully in the browser. See `FONT_PROVENANCE.md` for sources and the public-licensing limitation. No font CDN is used.
- `app/globals.css`: retained charcoal/champagne/ivory palette, authentic photography, RTL composition and existing sections. Tuned display typography and service titles; removed the large decorative circle from the hero. Rebalanced the six-image gallery into a complete 3×2 desktop grid, eliminating the former orphan third row and empty cells. Mobile uses two columns for single photographs and full-width Before/After pairs so hairstyles remain visible. Filtered desktop results use two columns. Improved disclaimer contrast, 44px menu/close/filter targets, drawer scrolling/safe-area padding, and visible Before/After keyboard focus. Changed `align-items:end` to `flex-end` to remove both Autoprefixer warnings.
- `components/Homepage.tsx`: menu Escape closes and restores focus to its toggle; leaving the header closes the menu. Booking opens with the selected service, makes the underlying page inert, locks body scroll, traps Tab/Shift+Tab, restores focus to the original trigger, and closes by Escape, close button or desktop scrim click. Added a skip link, comparison value announcement, and filter result announcement. The drawer says plainly in Persian that no booking is recorded. Removed the decorative `01 / 03` hero counter, since there is no carousel.
- `app/icon.svg`: a small SVG using the existing crown motif fixes the browser's missing-favicon console error; it is not a replacement brand identity.
- `next.config.ts`: disabled only the Next development indicator so review captures show the homepage without development chrome. React Strict Mode remains enabled.
- `package-lock.json`: added reproducible resolution of the original declared dependency ranges. Application dependency ranges were not changed. Resolved Next 15.5.28, React/React DOM 19.3.1 and TypeScript 5.9.3. Added exact `@playwright/test` 1.64.1 as development tooling, `playwright.config.ts`, `tests/homepage.spec.ts` and `npm run test:ui`.
- `.gitignore`: excludes TypeScript incremental caches and Playwright temporary outputs; preserves command logs as review evidence. `next-env.d.ts` contains Next's generated route-type reference.

## Comparison against locked visual references

All four supplied section crops and all three full boards were visually inspected before editing, then compared with actual renders. Reference links in older documents mention absent `screen-references/` and `design-system/tokens.css`; the supplied `references/` files and existing CSS tokens were used. The visual contract itself was not changed.

| Reference | Rendered comparison and intentional departure |
| --- | --- |
| `01-homepage-hero.png` | Retains the right-hand cinematic photograph, left-hand Persian editorial headline, warm gold CTA, restrained secondary CTA and dark overlay. Authentic `hero-groom.webp` replaces the AI scene; its real interior and red foliage remain visible. Existing three-line headline and separate header remain rather than reproducing the collage's overlapping text/navigation. Local Kahroba is the owner's requested typography refinement. Mobile stacks photo before copy to preserve readable text and faces. |
| `02-services-grid.png` | Retains six tall bordered cards, gold line icons and exact brochure labels in RTL order. Groom/hair cards use existing related photographs. At the owner's explicit follow-up request, the former four SVG/CSS panels now use generated photographic service concepts, all visibly labeled as conceptual. They are not real salon/client evidence. The new set follows the reference's photographic card composition and charcoal/champagne light. |
| `03-before-after-gallery.png` | Uses six actual supplied portfolio images in a balanced grid; four working filters reflect the categories for which real content exists. There are no fabricated facial/massage/nail portfolio entries to fill the mockup's categories. The existing separate Before/After section uses the two source halves of `IMG_2785.png` through a real keyboard/pointer/touch-operated range input. |
| `04-branches.png` | Two bordered cards remain; Poonak shows the confirmed address. Branch two is an explicit non-selectable placeholder with no invented name, address, photo or schedule. The salon image is the supplied collection image, not independent evidence of branch-specific image attribution. |
| Board A — luxury/home/services/booking/admin | Carries forward charcoal/gold hierarchy, authentic grooming image, six cards, branch selection preview. Admin panels, service detail pages and operational booking are beyond Phase 1. |
| Board B — full experience | Carries forward photograph-led hero, filtered gallery and salon story section. Testimonials, ratings, benefits not supported by facts, times, payments and booking confirmation are intentionally omitted. |
| Board C — premium editorial | Carries forward oversized Persian typography, subtle gold lines, Before/After control and editorial story stripe. AI-generated faces, garbled text, decorative fake controls and calendar/payment/success screens are not copied. |

The app never uses a reference crop or whole mockup as a background. All text, buttons, filters, icons and controls are legitimate DOM/SVG. Existing decorative English editorial labels are retained. These documented departures are submitted for review, **not represented as approved**.

## Actual Next.js browser validation

Playwright controlled installed Google Chrome **155.0.8059.85**, in fresh contexts, at device scale 1 with `fa-IR` locale and reduced motion. Mobile projects use touch/mobile emulation. The test navigates to the running Next server, scrolls every lazy image into view, awaits decode and active fonts, then returns to the top before capturing full-page and above-fold PNGs. No screenshot was fabricated or produced with `set_content`.

| Viewport | Render / screenshot pair | Horizontal overflow | Broken images | JS / hydration / console / HTTP failures |
| --- | --- | --- | --- | --- |
| 1440×900 | desktop, captured | 0px | 0 | 0 |
| 1024×768 | tablet, captured | 0px | 0 | 0 |
| 390×844 | mobile, captured | 0px | 0 | 0 |
| 375×812 | mobile-small, captured | 0px | 0 | 0 |

Latest result after the service-image and attribution correction: **16 passed, 0 failed, 0 skipped, 0 flaky (61.0 seconds)**. Machine-readable results: `artifacts/codex-playwright-results.json`. Earlier passes remain recorded in `playwright-final.log` (66.3 seconds) and `playwright-hair-crops.log` (58.7 seconds).

Each viewport passed these checks:

- Actual HTTP 200 render, Persian/RTL document, no-index metadata, correct title/address and exact six services; all internal links resolve to real IDs. External links point to the supplied Instagram account, and were not used to transmit or publish anything.
- All four portfolio filters produce the expected real items and selected state; all six return on reset. Images decode after filtering; controls remain inside the viewport.
- Before/After Home/End/ArrowRight update clipping and accessible value; visible keyboard focus; desktop mouse drag and mobile touch tap update the split.
- All six service cards preselect the correct preview service. Generic entry clears selection. Drawer selection works; close, Escape, focus entry/restoration, Tab/Shift+Tab wrap, background inertness and scroll unlock work. Desktop backdrop closing works; mobile drawer fills the screen and uses its close/Escape routes. Continuation stays disabled; there is no availability field, form submission or booking success state.
- Header links and portfolio CTA navigate correctly. Both mobile sizes pass open/close, Escape/focus return, all five menu links, and menu closure when opening the preview. Keyboard skip link reaches the main landmark.

This is Chromium desktop/touch emulation, not a claim of testing Safari, screen-reader speech output or physical phones.

## Commands and observed outputs

Full command output logs are in `artifacts/logs/codex/`.

| Command / step | Result |
| --- | --- |
| `git init`, `git add .`, baseline commit | `d1b485b`; source, supplied assets and historical review evidence preserved; build output and secrets excluded. |
| `npm install` | Failed: `UNKNOWN`, `mkdir ... npm-cache/_cacache/tmp`. See `npm-install.log`. |
| `npm install --cache ../npm-cache` | Exit 0; 26 packages added. See `npm-install-local-cache.log`. |
| Initial `npm run typecheck` | Exit 0. See `typecheck-initial.log`. |
| Initial `npm run build` | Exit 0, but two Autoprefixer `align-items:end` warnings. Both fixed in existing CSS. See `build-initial.log`. |
| `npm install --save-dev --save-exact @playwright/test --cache ../npm-cache` | Exit 0; three development-tool packages added. See `playwright-install.log`. |
| `npx playwright install chromium` | Failed with official CDN HTTP 403/location denial. No network/security controls changed; tests instead used already-installed Chrome via `PLAYWRIGHT_CHANNEL=chrome`. See `playwright-chromium-install.log`. |
| `npm run dev -- --hostname 127.0.0.1` | Actual Next 15.5.28 app started on port 3000, loopback only. See `next-dev.log`. |
| First `npm run test:ui` with Chrome | 16 failed on the common favicon console 404; four also exposed an overbroad test assertion about unused Next dev fonts. Added crown SVG favicon, corrected the assertion to actual site fonts; application interactions themselves completed. See `playwright-first.log`. |
| Final `npm run test:ui` with Chrome | **16 passed (1.1m)**. See `playwright-final.log` and structured JSON. |
| `npm run typecheck` after adding test sources | Caught missing `HTMLImageElement` narrowing in one test diagnostic. Fixed the test typing. Final typecheck exit 0; see `typecheck-final.log`. |
| `npm run typecheck` without `.next` build output | Exit 0, confirming a clean source checkout can typecheck. See `typecheck-clean.log`. |
| Final `npm run build` with dev server stopped | **Exit 0**, compiled successfully in 7.4s; 5 static pages generated; no CSS/compiler warnings. `/`: 7kB route, 110kB first load JS. See `build-final.log`. |
| `npm audit --json --cache ../npm-cache` | Two entries: Next moderate via PostCSS, transitive PostCSS high. Exact advisories and affected ranges recorded in `npm-audit.json`. The proposed npm fix upgrades Next to a different major; no forced upgrade was applied under this task's dependency constraint. |
| Additional Playwright section captures | Services, comparison, portfolio and branches captured directly from the live 1440×900 app for reference comparison. |
| `node scripts/create_owner_review.mjs` | 18 authentic PNGs indexed, the eight required capture dimensions asserted, SHA-256 manifest saved, and every local review-gallery link verified. See `owner-review.log`. |

There is no separate configured ESLint script; Next's build type/lint stage completed. No full ESLint ruleset pass is claimed.

## Owner screenshot review

All current evidence is under `artifacts/screenshots/codex/`; the older sibling screenshots and `artifacts/QA_RESULTS.json` are **historical static-preview QA only** and were not used as Next.js acceptance evidence.

| Viewport | Above fold | Full page |
| --- | --- | --- |
| 1440×900 | [desktop](../artifacts/screenshots/codex/homepage-desktop-above-fold.png) | [desktop full](../artifacts/screenshots/codex/homepage-desktop-full.png) |
| 1024×768 | [tablet](../artifacts/screenshots/codex/homepage-tablet-above-fold.png) | [tablet full](../artifacts/screenshots/codex/homepage-tablet-full.png) |
| 390×844 | [mobile](../artifacts/screenshots/codex/homepage-mobile-above-fold.png) | [mobile full](../artifacts/screenshots/codex/homepage-mobile-full.png) |
| 375×812 | [small mobile](../artifacts/screenshots/codex/homepage-mobile-small-above-fold.png) | [small mobile full](../artifacts/screenshots/codex/homepage-mobile-small-full.png) |

Also included: drawer captures at all four sizes, mobile menu captures at both phone sizes, and four desktop section captures. `artifacts/OWNER_REVIEW.html` provides an offline screenshot gallery with the locked section references alongside actual captures. It is a review document, not application QA or a replacement app.

## Owner feedback correction — visible hair and grooming (2026-10-28)

The owner correctly identified that the Before/After framing hid hairstyles. The earlier `object-fit:cover` used a landscape comparison frame and a vertical 40% focal point on tall portrait assets, cropping away the crown. The square composite gallery images also used a centered crop; on mobile two portraits shared one narrow card.

- Existing `BeforeAfter` component retained: frame aspect ratio changed from 1.39:1 desktop / 1.12:1 mobile to 1:1.08, with top-aligned portrait crops. Hair, hairline and beard now fit together at both full slider endpoints and at the default split. No raster edits, generated hair, face changes or new imagery.
- Portfolio figures now have a stable category class. All `beforeafter` images use the same top-aligned crop in both “all” and filtered views; filtering cannot change the crop based on the item's current index. A lower caption gradient leaves the hair/beard area brighter.
- Both Before/After gallery pairs span the full grid width on mobile. The dedicated Before/After filter has taller cards at all four breakpoints, retaining both heads and the beard outline. Other portfolio categories keep their existing layout.
- Visually reviewed the actual comparison and both gallery states at 1440×900, 1024×768, 390×844 and 375×812. Full heads and grooming details are now visible within the supplied source bounds. The second original composite already has very little space above the hair; no nonexistent image area was invented.
- `npm run typecheck`: exit 0 (`typecheck-hair-crops.log`). `PLAYWRIGHT_CHANNEL=chrome npm run test:ui`: 16 passed in 58.7s (`playwright-hair-crops.log`), with no JS/console/HTTP failures or horizontal overflow. `npm run build`: exit 0 (`build-hair-crops.log`).
- Refreshed all required full-page screenshots and the comparison/gallery section captures. Added `hair-comparison-{viewport}.png`, `hair-gallery-all-{viewport}.png`, `hair-gallery-filtered-{viewport}.png` for all four sizes, plus full-before/full-after desktop endpoint captures. The owner review and SHA-256 manifest are regenerated from these actual PNGs.

This changes photographic framing within Phase 1 in response to explicit owner feedback; it does not imply visual sign-off or authorization for Phase 2/public publication. Every original image file remains byte-for-byte unchanged.

## Local server recovery — ENOSPC (2026-10-28)

After the prior checks, the owner reported `Internal Server Error`. A direct request reproduced HTTP 500. The running dev log showed `ENOSPC: no space left on device, write` from Next/Webpack; it could no longer write generated files on C:. This was an actual environment failure after the earlier browser pass, not a successful current render. The incident log is preserved in `artifacts/logs/codex/storage-incident.log`.

The safety layer rejected automatic recursive deletion. Used a reversible recovery instead: stopped only the verified project server and moved three generated task folders (`work/npm-cache`, `work/next-before-final`, and this project's `.next`) to `D:/Codex-task-cache-recovery/2026-10-28-mohammadstyle/`. Source paths and destination boundaries were checked before the moves. No business data, images, font originals, source components, owner deliverables or unrelated user files were removed or changed.

Restarted with `npm run dev -- --hostname 127.0.0.1`. Next generated fresh output successfully. Playwright then verified HTTP 200 for both `/` and `/icon.svg` at all four required sizes, decoded every image, exercised opening/closing the preview drawer, and found zero page/console/HTTP errors, broken images or horizontal overflow. Results: `artifacts/server-recovery-results.json`; screenshots: `server-recovery-{desktop,tablet,mobile,mobile-small}.png` in the current screenshot directory. The owner's existing in-app browser tab was reloaded and visibly changed from the error text to the actual homepage.

No source-code change or dependency change was needed, so the previous build/typecheck results remain applicable to the same implementation. Current recovery verification is separate from the earlier 16-test pass. No Phase 2 work or public deployment was performed.

## Owner feedback — barber attribution, desktop framing and service photographs (2026-10-28)

The owner identified `groom-look.webp` as a photograph of the barber, not a client. Its gallery title is now **آرایشگر مجموعه**, category `behind`, with corresponding alt text and provenance. The image file was preserved. It is excluded from the groom-service filter. Current category counts are all=6, beforeafter=2, groom=1, behind=3. No generated replacement customer image was added to the portfolio.

The desktop behind-the-scenes filter previously enlarged the craft image from a 438px overview card to 663.5px and changed its focal point from 37% to 50% because styling depended on the item's array index. Gallery classes now use stable image IDs; the craft focal point is 37% in every filter. At desktop widths ≥1200px the three behind-the-scenes items use three columns: the craft card stays 438px wide and reveals more vertical context in the taller filtered row. Tablet and phone layouts keep their prior grids. Visually compared the before/after desktop captures and all four sizes.

The owner explicitly authorized generating relevant pictures for facial, massage, manicure and pedicure. Used the built-in `image_gen` tool, one call per asset, with one identical style paragraph prefixed to all prompts: photorealistic service close-ups, warm upper-left lighting, charcoal #111214 / #08090a, champagne #e9c890, portrait composition, no text/logos/branding. The source prompts contain no client-photo input or real-person likeness reference. Inspected all four outputs for service relevance, natural anatomy, consistent light and text-free composition.

| New asset under `public/images/mohammadstyle-images/` | Final size | Bytes | Use |
| --- | --- | --- | --- |
| `mohammadstyle-services-facial-concept.webp` | 640×960 | 59,632 | Cosmetic mask/brush facial care |
| `mohammadstyle-services-massage-concept.webp` | 640×960 | 47,354 | Professional shoulder/upper-back massage |
| `mohammadstyle-services-manicure-concept.webp` | 640×960 | 50,720 | Natural male fingernail filing |
| `mohammadstyle-services-pedicure-concept.webp` | 640×960 | 64,210 | Professional heel/foot care |

Each generated original is 1024×1536; a proportional Sharp export produced the 640×960 WebP copy without semantic editing. All four original generated PNGs remain at the tool's original location. Exact shared style, complete prompts, alt text, source filenames, dimensions, measured bytes and SHA-256 are preserved in `data/generated-service-images.json`. `data/image-provenance.json` distinguishes these from the fourteen untouched supplied images. Every generated service card has a visible **تصویر مفهومی** badge and conceptual alt text; the service note states that the four are AI-generated and not real salon work. No generated image is used in the portfolio or Before/After control.

The visual contract records the owner's specific imagery authorization while preserving the locked design and publication/Phase 1 restrictions. This makes the newly generated service photographs authorized for this internal review, not owner visual sign-off or evidence of real premises, clients or equipment.

Validation: `npm run typecheck` exit 0 (`typecheck-service-images.log`); `PLAYWRIGHT_CHANNEL=chrome npm run test:ui` **16 passed in 61.0s** (`playwright-service-images.log`). Tests now also guard the barber portrait's exclusion from the groom filter, its correct behind-the-scenes attribution, no desktop magnification of the craft card, and conceptual labels/alt text on all four generated services. All images decode; no browser/HTTP errors or horizontal overflow at any requested size. `npm run build` exit 0 (`build-service-images.log`). Refreshed the eight required homepage screenshots, current services/gallery section captures, and added services and behind-the-scenes captures at all four sizes.

## Remaining issues and approval gate

- No known failing Phase 1 technical/browser gate. **Human visual sign-off is still required**, especially the new font pairing, authentic photo crops, four generated service concepts and branch-two placeholder.
- Recognizable photos are for internal owner review only. No public publication occurred. Public image consent, branch-specific photo attribution and webfont licensing remain unverified.
- The dependency audit entries remain documented. Review/remediate before any future production release; a framework major change was intentionally outside this task.
- Branch-two data, verified service photos, staff, pricing, duration and policies remain unknown. The preview cannot create a booking or collect payment.

**Stop here. Request owner visual approval before Phase 2; do not infer approval from passing tests.**

## Phase 02 — Smart Booking UI (2026-10-29)

Work performed only in the original internal repository. Verified clean `master` at **ec03330**, no remotes, then created **feature/booking-ui** from that commit. The public repository was not used as development source or updated. Source photographs, font binaries, `data/business-facts.json`, dependency manifests and the existing `tests/homepage.spec.ts` remain unchanged.

### Implementation and visual review

- Added a dedicated `/booking` route with branch, multi-service, eligible demo barber/any barber, Jalali date/demo time, and summary/policy preview. Components, contracts, state actions, validity checks and provider seams are documented in `BOOKING_UI.md`.
- Existing Homepage composition and sections are preserved. An enabled entry inside its accessible drawer carries the selected service into the route. Keeping the drawer is an intentional entry decision to preserve quick selection, keyboard behavior and all existing tests; its legacy disabled continuation still refers to real booking, while the new link explicitly starts a demo.
- The default leaves real prices/durations/policies unconfirmed. Explicit fixture and policy controls demonstrate known-value totals, missing inputs, optional/fixed/percentage deposits and refund-window presentation, without real staff/schedule/policy claims.
- Inspected all three supplied full concept boards and `04-branches.png` for branch/booking hierarchy; the referenced standalone `05-booking-stepper.png` is not in the supplied ZIP. Compared actual desktop service/date/summary and mobile/tablet renders against the boards' dark/champagne panels, restrained CTA, border treatment and Persian hierarchy. Reused Kahroba/IRANSans and existing tokens/icons. No whole-board background or generic replacement UI.
- The requested five steps replace the boards' compressed four phases. Demo notices, unknown facts, an unconfigured branch-two card and a preview-only final action replace fake availability/payment/success screens. The collection interior carries an explicit unverified branch-attribution caption. Fictional barber cards use icons rather than fabricated staff portraits/ratings.
- Mobile choice text precedes branch imagery, the calendar has verified ≥44px day targets, controls clear the fixed safe-area action bar, and a collapsible overview follows the panel. Calendar/slots stack on tablet and phone. Separate top-of-page, focused-step viewport and full-page screenshots explain the composition; fixed controls retain their actual viewport position in stitched mobile full-page captures.
- Four Homepage above-fold PNGs are **byte-for-byte identical** to the saved Phase 1 baseline. Full-page dimensions remain unchanged at every viewport; small full-page raster/compression variation does not change layout. Original baseline copies are retained in `artifacts/screenshots/booking/phase1-baseline/`.

### Commands and observed results

| Command / check | Actual result and evidence |
| --- | --- |
| `git status --short --branch`, `git log`, `git remote -v` | Clean internal baseline `ec03330`; no configured remote. `git switch -c feature/booking-ui ec03330` succeeded. |
| `npm run typecheck` | Exit **0**, `tsc --noEmit`; `artifacts/logs/codex/typecheck-booking.log`. Initial typecheck also passed. |
| First complete Chrome UI run | 32 passed / 12 failed. New assertions matched Next's route-announcer alert instead of the form alert, and very fast Homepage entry exposed the SSR form's native-submit race before hydration. Scoped new error assertions to the form and disabled its fieldset until the client is ready. Existing Homepage tests were not modified. `playwright-booking-first.log`, `booking-first-playwright-results.json`. |
| Desktop diagnostic run after fixes | **4 passed (26.0s)**; `playwright-booking-desktop-debug.log`. |
| Second complete Chrome UI run | 44 passed / 4 failed, solely the newly added no-JS fallback's DOM-text assertion on `noscript`. The fallback was present in actual server HTML; corrected that assertion to the response markup, retaining both disabled-control assertions. `playwright-booking-second.log`, `booking-second-playwright-results.json`. |
| `PLAYWRIGHT_CHANNEL=chrome npm run test:ui` | **48 passed, 0 failed/skipped/flaky in 161.5s**. Includes 16 unchanged Homepage browser tests, 20 booking browser checks and 12 domain checks across the four projects. `playwright-booking-final.log`, current `artifacts/codex-playwright-results.json`. |
| `npm run build`, verified project dev processes stopped first | Exit **0**; Next **15.5.28**, compiled in **4.2s**, 5/5 static pages generated, `/booking` correctly dynamic. `/booking`: **12.7kB**, **116kB** first load; `/`: **7.42kB**, **110kB** first load. No compiler/CSS warnings. `build-booking-final.log`. |
| `npm run dev -- --hostname 127.0.0.1` | Restarted the actual internal app on loopback port 3000 after the build. No production hosting/deployment. |
| Live smoke after build/dev restart | Homepage and `/booking?service=hair` returned **HTTP 200 at all four viewports**, hydrated form ready, all images decoded, zero JS/console/HTTP errors or horizontal overflow. Stable evidence: `artifacts/booking-live-smoke.json`. |
| `node scripts/create_booking_review.mjs` | **96 actual booking PNGs** (8 step/state captures × 4 viewports × 3 framing types), dimensions and hashes checked, review links verified, four Homepage above-fold matches asserted. `booking-owner-review.log`, `booking-screenshot-manifest.json`, `OWNER_REVIEW_BOOKING.html`. |
| `git diff --name-only ec03330 -- public/images app/fonts data/business-facts.json tests/homepage.spec.ts` | Empty: original images/fonts/facts and the existing test source are unchanged. |

The only test-run warnings were the runner's `NO_COLOR`/`FORCE_COLOR` environment notices; these were not browser errors. No standalone ESLint pass is claimed; the existing Next build type/lint stage completed.

### Coverage and current screenshot review

At **1440×900, 1024×768, 390×844 and 375×812** the actual app passes navigation/service preselection, invalid query handling, unconfigured branch exclusion, multiple services, eligible staff intersection/any staff, loading/empty/disabled/selected slots, Jalali month and keyboard controls, summary recalculation, unknown totals, policy scenarios, back/forward preservation, branch/service/barber/date invalidation, rapid asynchronous date edits, final preview-only feedback, reduced-motion layout and no horizontal overflow, broken images, HTTP/console/hydration/JS failures. Additional 844×390 landscape overflow checks pass. A no-JavaScript browser context verifies disabled SSR controls and response fallback markup. Unit checks cover Nowruz/leap/month/timezone boundaries and arithmetic/invalidation invariants.

All current booking captures are under `artifacts/screenshots/booking/`. `*-viewport.png` starts at the page top; `*-step.png` shows the active panel at the original viewport dimensions; `*-full.png` contains the full page. The internal offline gallery is [OWNER_REVIEW_BOOKING.html](../artifacts/OWNER_REVIEW_BOOKING.html); it is a screenshot review artifact, not a substitute for real Next.js QA.

| Viewport | Calendar / time | Summary / policy | Branch |
| --- | --- | --- | --- |
| Desktop | [step](../artifacts/screenshots/booking/datetime-desktop-step.png) / [full](../artifacts/screenshots/booking/datetime-desktop-full.png) | [full](../artifacts/screenshots/booking/summary-desktop-full.png) | [full](../artifacts/screenshots/booking/branch-desktop-full.png) |
| Tablet | [step](../artifacts/screenshots/booking/datetime-tablet-step.png) | [full](../artifacts/screenshots/booking/summary-tablet-full.png) | [full](../artifacts/screenshots/booking/branch-tablet-full.png) |
| Mobile | [step](../artifacts/screenshots/booking/datetime-mobile-step.png) / [full](../artifacts/screenshots/booking/datetime-mobile-full.png) | [full](../artifacts/screenshots/booking/summary-mobile-full.png) | [full](../artifacts/screenshots/booking/branch-mobile-full.png) |
| Small mobile | [step](../artifacts/screenshots/booking/datetime-mobile-small-step.png) | [full](../artifacts/screenshots/booking/summary-mobile-small-full.png) | [full](../artifacts/screenshots/booking/branch-mobile-small-full.png) |

### Remaining issues / stop gate

No known failing frontend acceptance check. Owner visual and technical review of Phase 02 remains pending. Prices/durations/staff/eligibility/policies/real capacity and branch two are unconfirmed. The frontend cannot create appointments, collect money, enforce cancellation rules, resolve authoritative policy versions or prevent concurrent bookings. Physical phones, Safari, screen-reader speech and production dependency remediation remain outside this verification. Existing private-photo/font publication limitations remain. No private remote is configured: commit locally on the feature branch, do not merge or push internal history/assets to the public review export. **Stop after Phase 02; backend/database/real booking/payment require the next approved task.**


## Phase 02 targeted review fixes — 2026-10-29

Canonical provider-slot selection and generation/key validation, branch-service offering contracts and policy-context guards were added without changing Homepage/Booking visual design. The single-provider MVP is retained; a future per-service segment model and open decisions are documented. See [BOOKING_REVIEW_FIXES.md](BOOKING_REVIEW_FIXES.md) and [BOOKING_REVIEW_RESULTS.json](BOOKING_REVIEW_RESULTS.json) for exact changes and actual private QA.


### Actual command results

- `npm run typecheck`: exit 0; no diagnostics.
- `npm run build`: exit 0; compiled in 2.7s, 5/5 static pages, dynamic /booking (13.9 kB / 117 kB first load).
- `npm run test:ui`: installed Chrome, CI=true, dedicated original Next.js app on port 3000: **92 passed**, zero failed/skipped/flaky, 192.7s. Four viewports: 1440×900, 1024×768, 390×844, 375×812. Includes 52 domain checks, 24 Booking browser checks and 16 unchanged Homepage browser checks. No console/JS/HTTP/image/overflow failures.
- Protected Homepage/CSS/layout/font/image/reference/business-fact/dependency paths are unchanged from the private baseline. 143/150 existing screenshot files are byte-identical; any differing captures are recorded in `BOOKING_REVIEW_RESULTS.json` for actual visual inspection. Captures and raw logs stay private/local; the public PR receives source/docs and normalized evidence only.
- No real booking, payment, policy enforcement, backend/database, merge or Phase 03. Draft public PR #1 is updated separately from this committed private source; its current public-copy results are recorded in the public export report.


## Owner supplied brand logo — 2026-10-31

The owner authorized the attached identity board as the site logo. A transparent gold MS/hair/beard raster replaces the decorative brand crown in Homepage header/footer, both Booking modes and admin; the portfolio header uses the same shared BrandMark. Existing live brand text remains selectable and labels the link. The board itself, unverified EST date, decorative badge and other statements are not incorporated. Original supplied photos, fonts, business facts and backend/Booking behavior are preserved. See BRAND_LOGO.md and data/brand-logo-provenance.json for exact built-in image_gen extraction prompt and source/asset hashes.

The mark uses 52px desktop/40px phone sizing; the compact admin sidebar at <=1250px uses 44px with 20px non-wrapping brand text to prevent the tablet name wrapping found during actual screenshot review. Image proportions, intrinsic space and readable adjacent text are preserved. Browser icon is 64px PNG and Apple icon is 180px, with charcoal matte and safe clear space. This is an AI-assisted raster adaptation; no vector master or pixel-identical extraction is claimed.

Actual checks: npm run typecheck exit 0; npm run build exit 0, including both new icon routes; PLAYWRIGHT_CHANNEL=chrome npm run test:ui: **92 passed, 0 failed/skipped/flaky**, 238.9s (52 domain checks and 40 browser checks across four projects). No test source changed. A separate actual Next.js/Chrome render audit passes on /, /booking, /booking?mode=server, /portfolio and /admin at 1440x900, 1024x768, 390x844 and 375x812: **20/20** HTTP 200, no JS/console errors, visible broken images or horizontal overflow. Protected routes used verified synthetic local sessions. Full-page and fold screenshots are saved in outputs/logo-review/ (40 actual page images). Additional 812x375 landscape checks on Homepage/Booking show no overflow; /icon.png and /apple-icon.png return HTTP 200 and decode at 64px/180px. The final admin CSS adjustment was rebuilt/typechecked and its four captures rerun; Homepage/Booking were unchanged after the 92-check run.

Capture-harness dry runs exposed expected anonymous 401s and a timeout scrolling CSS-hidden images, not new application bugs. The harness was corrected to use existing verified local sessions and decode visible images; the final evidence is browser-checks.json. Earlier historical test screenshot baselines are preserved in Git; new logo screenshots and logs are in the dedicated owner review folder. No public repository/PR, private photography, font binaries or original board was exported. Owner visual review remains the next step; no backend phase or production login change.


## Owner requested manual local admin login — 2026-10-31

Added /admin/login with the existing logo, selectable brand name, charcoal/champagne palette, local fonts and RTL form. Password managers/paste, show/hide, visible keyboard focus, pending/error states and post-error focus work. Inputs are disabled until hydration; native method is POST and no-JavaScript controls stay disabled so credentials cannot enter a GET URL. The existing unauthorized admin state now links to the login page; mobile logout closes its drawer. Homepage, Booking, original private assets and the 15 approved core migrations are unchanged.

The owner-authorized development-only login uses a scrypt verifier and an offline-pinned existing verified synthetic administrator; each browser gets fresh DB-backed session/CSRF values, not copied fixture cookies. Existing authorization, idle/absolute expiry and revocation remain authoritative. A separate EXECUTE-only local issuer role cannot read/write tables or assume the migration role. Browser Origin/Host/pre-auth CSRF, bounded payloads, bridge authentication, hashing limits and production-disable behavior are verified. See backend/mvp-integration/LOCAL_REVIEW_LOGIN.md for the exact boundary and setup. No production identity provider, real account, SMS or payment was added.

Actual results: frontend/backend typecheck and build exit 0; 12 actual PG/Nest login checks and all 41 existing native MVP checks passed; new browser suite 11 passed/9 intentionally skipped redundant viewport cases/0 failed; four existing unauthenticated admin browser cases passed; all 92 existing Homepage/Booking Playwright checks passed. An actual Next production server with the MVP flag and local credential files present returns 404 for login GET and POST and renders no login form. Screenshots (full/fold, no filled credentials) cover 1440x900, 1024x768, 390x844, 375x812 in outputs/local-login-review/. Reviewed desktop/mobile form screenshots and all four sizes for overflow; no horizontal overflow or page JS errors. Original historical screenshot baselines are preserved; new evidence/logs live only in the owner output.

Diagnostic failures were fixed before the final runs: the offline setup initially called an incorrectly named permission helper (corrected to existing b1b_can); a native HTTP harness did not preserve a custom Host through fetch (changed to native http.request); an initial browser assertion also matched Next's route announcer (scoped to the form alert). No application security check was relaxed. No public PR/source/history/assets/credentials were exported. Stop for owner visual review.

The first complete Homepage/Booking run had 89 passes and three artifact-file ENOENT failures because two legacy Playwright runners shared/cleared the same test-results directory. The final run uses a separate output directory; the new login config also has its own output directory. No test assertion or application behavior was weakened. Final command: PLAYWRIGHT_CHANNEL=chrome npm run test:ui -- --output=backend/.local/mvp/playwright-output/homepage.


## Product finalization — actual review 2026-11-01

The owner-requested final product extends the approved RTL dark/champagne interface with verified customer login, account/session/history/payment states and operational admin pages. Homepage/Booking composition and six brochure services remain. No complete mockup is used as a background. New screenshots are actual Next/Nest/PostgreSQL/HTTP-provider journeys at 1440×900, 1024×768, 390×844 and 375×812. Existing Homepage/DEMO92, admin/CMS23, manual-login11 and SERVER12 browser checks passed; redundant cross-size mutations retain their documented skips. New complete journeys6 and production HTTPS6 passed, with no browser JS/hydration errors, broken images or horizontal overflow in the exercised pages.

Intentional publication differences: system fonts and self-contained editable brand SVG replace unlicensed/private font/photo dependencies in product/public packages. Private assets remain unchanged in the private source and original internal-review profile. Product before/after waits for approved media instead of fabricating client results; CMS public gallery exposes only currently rights-approved published variants. This preserves layout and color direction but is a material photographic difference requiring owner review. No public visual approval is implied.

Actual captures and test logs: owner package outputs/product-final-review (separate from tracked source). See docs/product/VALIDATION.md, REPORT.md, SECURITY.md and RUNBOOK.md for commands, diagnostic failures followed by clean runs, security and deployment boundaries. Selected private owner screenshots contain synthetic fixture data only. No static preview was used as Next QA. Final acceptance remains with the owner.


## Owner correction — private product visual review, 2026-11-01

The owner rejected showing the publication-safe image placeholders as the internal product Homepage. Restored the existing photographic Homepage, private typography, portfolio filters and real before/after slider at local3006 while retaining new Booking/admin functionality. The cause was an overly broad product-mode condition in the private asset guard, not missing/deleted source images. The guard is now shared by middleware/page/font delivery and supports explicit loopback-only isolated development review. Production and public export still exclude private assets. Four-size actual Chromium review and10 privacy-boundary cases passed; see product/PRIVATE_VISUAL_REVIEW.md. New internal photo screenshots remain outside Git/public review packages.


## Internal Wi-Fi review — 2026-11-01

Owner requested the same approved product over the private Wi-Fi address. Homepage composition, photographs, fonts, crops, gallery and Before/After remain unchanged. Four-size actual private visual/interaction regression passed again. Functional change only: browser request UUIDs retain native cryptographic generation, with a cryptographic getRandomValues v4 path for HTTP LAN contexts. Actual LAN-origin customer/payment/admin journey passed through a separate authenticated private-review ingress; no private assets/history or ingress credentials are exported. See product/LAN_REVIEW.md.

## Manual transfer, content and owner refinements — actual review, 2026-11-01

The owner authorized this combined change after the approved product baseline. The restored photographic Homepage, six exact brochure service names, Booking steps and charcoal/champagne typography remain. Added owner-requested four-frame hero choices and muted/blurred supplied video, a separate About video chapter, full gallery films, About/Contact/Barbers pages, confirmed staff names/phone numbers and Toman menu, varied craft photos, decorative comb/scissors, larger Instagram CTA, split login, logo fill/unfill feedback and optional persistent light admin theme. Before/After remains a real hair comparison; the newly supplied alternate staff portraits are not mislabeled transformation results. Prototype presentation badges were removed at the owner's request; accurate provenance remains in alt text and private records.

### Superseding owner refinements and clean dataset — 2026-11-02

The final hero has three automatically crossfading approved photos, no manual picker/video and no brochure subtitle. Repeated diagonal arrows and Before/After preset buttons are removed. The work film is the full-width background of the craft chapter; its visible overlay control was removed as explicitly requested. Offscreen/tab pause and reduced-motion/save-data still defer video. About/gallery controls remain. Decorative comb/scissors now use a natural photographic AI cutout (660×220 transparent WebP, 51,148 bytes), with its exact prompt/tool/provenance recorded in data/barber-tools-provenance.json. This is decoration, not a claim about actual salon equipment. Gallery headings use “گالری تصاویر”.

Actual final Next/Chrome verification: frontend typecheck and production build PASS; Homepage/DEMO92/92 PASS after these refinements. Four refreshed private Homepage full/fold and supporting-page captures at 1440×900, 1024×768, 390×844, 375×812 have zero horizontal overflow, missing decoded images or JS errors. Actual automatic three-frame advance, work-video playback/offscreen pause, no picker/preset/overlay buttons and reduced-motion poster behavior PASS. The native slider still passes pointer/keyboard endpoints. No static preview was used.

Owner-authorized active-data curation: encrypted full snapshot (94 tables, nine referenced media objects), then archived the former synthetic dataset without deleting history or disabling immutable triggers. A fresh migrated owner dataset contains exactly پونک/فرشته, the six brochure services and three confirmed staff names. It omits synthetic customers/bookings/CMS/media/prices/policies/orders/cards and invented schedules. Only the existing operator authentication identity/password/MFA/recovery provenance and valid operator sessions are retained. Staff are not assigned/activated without confirmed branch/schedule eligibility. Branches remain unbookable until real operational configuration exists. Normal owner password/MFA login and seven read-only admin workspaces across all four viewport sizes PASS; zero visible synthetic data, horizontal overflow or JS errors. Six pre-SQL fixture-boundary denials PASS, preventing synthetic seeds in owner/non-disposable databases. Original source assets, original database and archived test history remain recoverable and outside the active interface/public export.

CI diagnostic: the first independent SERVER browser run incorrectly targeted the retired3110 API because its web-server harness forced MVP off despite the explicit mvp-local profile. The harness now respects that profile and targets the already provisioned isolated MVP backend. No test body, slot/consent/payment assertion or Booking behavior is weakened. Actual current GitHub results are delivered separately from historical/local passes.

Actual Next/Chrome screenshots and visual inspection cover 1440×900, 1024×768, 390×844, 375×812: Homepage full/fold, slider endpoints, About/Contact/Barbers/login, gallery and light/dark administration. No JavaScript/hydration errors, broken decoded images or horizontal overflow in these exercised views. Real video playback, explicit pause retained across frame switching, offscreen pause, two gallery films, alternative staff frames, and reduced-motion/save-data deferred download passed. Chrome mobile/touch emulation was used; a physical iPhone/Android check remains for the owner. No static preview was used as Next QA.

Manual payment/card settings and financial review workspaces use the existing RTL dashboard; receipt upload is never confirmation. Desktop/mobile actual Booking and store journeys covered submission, rejection, resubmission, independent synthetic bank attestation and authoritative settlement. A genuine nested-form defect discovered by these tests was fixed by moving the shared payment form outside the wizard's step form; all existing SERVER tests pass. Blog CMS draft/publish/unpublish/archive and literal text rendering, store configuration/product/inventory/order fulfillment and default-off sales boundaries passed actual browser tests. Store shipping/returns/final prices must be explicitly configured; no real products or commercial policy were seeded.

Commands/results: npm ci frontend/backend PASS (no dependency upgrades); npm run typecheck and npm run build both apps PASS. Original Homepage/DEMO92, SERVER12, MVP23+9 existing intentional skips, login11+9 existing intentional skips PASS. Original B0–B4 and MVP native test bodies retained; isolated wrappers pass (B4 44+14, B3 78 and nested prior suites). Product auth11, MFA/policy6, workflow10, lifecycle13, migration4, manual15, shop19, editorial6, review OTP3, receipt transport/notifications8 and backup/restore5 PASS. Offline receipt retention7 PASS against historical synthetic evidence and an authenticated independently restored backup. Unchanged original product browser6 and new manual/store/editorial browser8 PASS. The original product browser suite uses publication-safe images; private photographic QA is recorded separately above. Homepage presentation assertions were updated only for owner-requested badge removal, new page links and confirmed contact links; financial/security assertions were retained.

Immutable forward migrations0041–0056 extend the model;001–0040 checksums remain identical to the approved private commit. A renamed private SMS helper's parameter qualifier was corrected in new0056 after actual native regression exposed it; applied historical SQL was never rewritten. Independent encrypted clone of the old owner database restored all74 table counts, migration checksums and9 media hashes, then16 forward migrations applied; existing booking/identity/payment records and encryption keys were checked unchanged. This is isolated review, not a production migration claim.

Intentional publication differences remain required: all recognizable photos, films/posters, private fonts, visual reference boards, owner screenshot evidence and local credentials/dumps are omitted from the public review and production package. The public source uses existing synthetic placeholders/system fonts and an explicit review notice, with private video omitted. Owner review images stay local. Staff-specific haircut rates are informative menu facts; the current persisted server quote has branch/offering prices, so main-branch live booking awaits an explicit staff-tariff contract plus real durations, assignments, schedules and policy rather than silently using the wrong price. Only massage's duration is confirmed.

During packaging, a full system drive stopped Docker. After the owner freed space, the original volume-backed databases recovered healthy; no volume/data was deleted. Initial failed container builds are recorded as failures; fresh sequential build results and actual GitHub CI status belong in the final delivery report. Code and visual approval are still required; no public deployment, live payment/SMS, merge or next phase is authorized by these tests.

## Current follow-up implementation — 2026-11-02

Changed in place: bounded four-frame hero (3200ms) with touch/keyboard navigation and refined native-vector watermark; original small brand unchanged. Restored original line-art decoration; About overlay pause hidden per owner, automatic accessibility/media safeguards retained. Multi-service drawer uses a scrolling body and visible footer; entry helper normalizes known IDs and maps only unambiguous current-branch offering names. The current API has no brochure code, so missing/ambiguous matches never inject an offering; final server slot/price/terms checks remain authoritative.

Font/style audit:70 actual route/viewport samples (public13, admin19, account3;1440/390), normal administrator password/MFA, no fixture writes: zero JS errors, horizontal overflow, clipped content or controls below44px after fixes. Body IRANSansPrivate400/700, display KahrobaPrivate; controls inherit body font, admin mobile inputs16px, utility mobile H132px, normal buttons48px; English brand serif and financial monospace are intentional. A first audit's screenshot caret-hiding style caused hydration warnings before React settled; rerunning with caret:initial removed the QA artifact. No hydration suppression was added. Four initial hero/drawer viewport captures verify no photo/text overlap and footer inside844/812px. Chrome emulation is not a physical-device claim.

Contact cards are now compact; phone numbers use Persian digits, LTR isolation, body sans-serif and tabular spacing. Added a keyboard-dismissible public contact shortcut, hidden during menu/drawer activity and absent on transactional/admin pages. Shared sticky header directly exposes About/Barbers/Contact in desktop and scrollable mobile menus. Footer has consistent link/contact groups and44px targets. Journal has a featured story, category filtering, reading-time estimates and two-column editorial cards; three newly authored styling/consultation pieces and three original generated editorial covers are published through the existing CMS, editable in admin. No private client image rights were asserted for these generated assets.

Current verification recorded before delivery: npm run typecheck PASS. Earlier original Homepage/DEMO92 passed; new booking-entry12 passed after correcting only a new test's wrong button label. Current complete-suite/build/remote results are recorded in the delivery package and CI for the delivered commit, separately from historical results. No static HTML preview is used as Next QA. Newly added navigation/contact tests cover keyboard dismissal, working phone links, modal avoidance, responsive navigation and sticky positioning. Existing Homepage navigation assertions change only to reflect the explicitly requested direct page links and tablet menu breakpoint.

Owner-authorized sample setup activates both existing real branch records using the existing guarded B4 planner, normal MFA owner session, preserved triggers and a pre-change full private backup. No new synthetic branch or erased history. Sample eligibility, schedules, prices not yet covered by real contracts and terms are disclosed and bounded in OWNER_REVIEW_SAMPLE.md. Authentication, authoritative availability/quote/hold validation and payment/SMS isolation are unchanged. Server outer password removal was explicitly requested; no claim of cleared legal publication rights. Public export still excludes private assets, screenshots, credentials, backups and history.
