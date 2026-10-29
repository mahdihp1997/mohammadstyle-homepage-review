# Mohammad Style — Phase 1 / Homepage

**Status: Task 01 technical gates pass — awaiting owner visual approval.**

A real Next.js App Router + React + TypeScript implementation of the approved luxury dark/champagne design direction. The homepage is composed of accessible DOM components, not a screenshot background. Real client photographs are displayed for internal review only.

## Run it (in VS Code / Codex)

Requirements: Node.js 20.9+ (Node 22 LTS recommended), npm.

```bash
npm ci
npm run dev
# Open http://localhost:3000
npm run typecheck
npm run build
```

## Review evidence and browser tests

Open `artifacts/OWNER_REVIEW.html` for screenshots of the actual Next.js app at all four required sizes, section comparisons, drawer states and mobile menus. Read `docs/VISUAL_REVIEW.md` for actual changes, commands/results and remaining approval gates. Current PNGs are under `artifacts/screenshots/codex/` and test results are in `artifacts/codex-playwright-results.json`.

Run browser QA with `npm run test:ui`. It starts the actual Next dev server on loopback automatically if needed. Normally install the matching Chromium using `npx playwright install chromium`. On this machine that download was denied by the CDN; already-installed Chrome was used successfully. In PowerShell:

```powershell
$env:PLAYWRIGHT_CHANNEL = 'chrome'
npm run test:ui
```

The legacy `preview.html`, standalone HTML, old screenshot files and `artifacts/QA_RESULTS.json` are retained as historical static material. They do not reflect all new React/font changes and are not current Next.js validation evidence.

## Done in this phase

- Dark cinematic **responsive** homepage: Header, Hero, six brochure services, interactive Before/After, filtered Portfolio, Story, known Branch + unknown Branch placeholder, CTA and Footer.
- Booking **preview** drawer only (no fabricated availability, deposits or success messages).
- Business information sourced from brochure / client-provided images.
- Actual Next.js desktop/tablet/mobile screenshots and 16 passing Playwright Chrome tests in `artifacts/`.
- Owner-supplied Kahroba/IRANSans typography; see `docs/FONT_PROVENANCE.md`.
- Four owner-requested AI-generated service concepts for facial, massage, manicure and pedicure, clearly labeled in the service cards. Full prompts, alt text and export dimensions are in `data/generated-service-images.json`. The barber's portrait is correctly classified under behind-the-scenes.

## Not implemented (by design)

- Authentication, server API, PostgreSQL, customer panel, staff management, calendar, real booking, payment, deposit/refund Policy Engine, SMS/Telegram/Bale, CRM, media upload admin. These are later phases and must **not** be inferred from the visual draft.
- Branch 2 address and metadata, service prices/durations, staff names, accepted deposit rules. Waiting for client confirmation.

## Validation and remaining gates

`npm run typecheck` and `npm run build` pass. The real React app was tested with Playwright/Chrome at 1440×900, 1024×768, 390×844 and 375×812, with no JS/hydration/console/HTTP errors, broken images or horizontal overflow. Menu, navigation, filters, comparison and preview drawer passed. Physical phones, Safari and screen-reader speech output were not tested.

Owner visual approval is still required before Phase 2. Image publication consent and public webfont licensing remain unverified. Two dependency audit entries through Next's PostCSS dependency remain documented; no out-of-scope major framework upgrade was forced. No public deployment was performed.

See `docs/CODEX_NEXT_PROMPT.md`, `docs/VISUAL_REVIEW.md` and `docs/VISUAL_CONTRACT.md`.

## Photo / release caution

Client images were supplied for making an internal presentation; obtain permission and consent before public publication of recognizable people. Original client photographs remain unchanged, and no supplied person's face was edited. Separately, four new AI-generated service illustrations were created at the owner's request; these are labeled as conceptual, not real client work or staff.
