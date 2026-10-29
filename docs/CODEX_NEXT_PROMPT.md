# CODEX TASK 01 — Make the existing Homepage buildable and visually faithful

You are the engineer continuing an EXISTING Next.js (App Router) + TypeScript project for محمد استایل / سالن ممتاز پونک. Work within this project root. This is not a greenfield task. DO NOT scaffold a new app, DO NOT replace the homepage with a template, and DO NOT change the approved dark/champagne cinematic visual direction.

Read all of these BEFORE editing:
- `AGENTS.md`
- `START_HERE_CODEX.md`
- `docs/VISUAL_CONTRACT.md`
- `docs/ACCEPTANCE_CRITERIA.md`
- `docs/VISUAL_REVIEW.md`
- `data/business-facts.json`
- `components/Homepage.tsx`, `app/globals.css`, `data/site.ts`
- relevant image references in `references/`.

## Required implementation work

1. Inspect the project and record a concise baseline of what exists. If no Git repository is present, initialize one and make a baseline commit with the current source (omit build outputs and secrets). Do not delete or rewrite existing components.
2. Install dependencies and run `npm run typecheck` and `npm run build`. Fix TypeScript, Next.js, lint/build, or hydration errors while preserving the intended design. Avoid dependency upgrades unless a documented compatibility problem requires them.
3. Launch the ACTUAL Next.js app using `npm run dev`. Inspect it with a browser. The old `preview.html` is not a substitute for the live React app.
4. Capture full-page and above-the-fold screenshots of the actual app at 1440×900, 1024×768, 390×844, and 375×812. Save under `artifacts/screenshots/codex/`. Use Playwright if available; set it up if needed. Do not fabricate screenshots.
5. Compare the actual rendered Homepage with `references/01-homepage-hero.png`, `02-services-grid.png`, `03-before-after-gallery.png`, `04-branches.png` and the three full concept boards. Revise layout/typography/spacing/crops/colors to maintain high visual fidelity, but DO NOT alter the factual content or use a whole mockup screenshot as a background. Where an AI reference contains impossible/unreadable decorative details, implement a legitimate accessible component instead.
6. Confirm the RTL layout and test interactions: mobile navigation, service navigation, portfolio filters, Before/After control, and booking-preview drawer (open, close, Escape, focus). Verify no overflow, broken images, console errors, or non-functional actionable UI.
7. Retain EXACT six brochure services: استایل دامادی، هیرکات مو، فیشیال صورت، ماساژ، مانیکور، پدیکور. The brand is محمد استایل, brochure title سالن ممتاز پونک, and confirmed location is پونک، ساختمان رونیکا پالاس، لابی. The business has two branches but branch-two details are not yet confirmed.
8. Preserve uploaded client image assets. They are approved for internal review only; do not publish recognizable client images to the public or claim publication rights are cleared.
9. Update `docs/VISUAL_REVIEW.md` with actual changes, intentional deviations from AI mockups, test results and remaining issues. Document the commands run and their outputs. Do not present static preview QA as Next.js QA.

## Strict scope

PHASE 1: Homepage frontend only. NO real booking, payments, deposit/refund rules, production messaging, backend APIs, database, fake prices, fake available time slots, fake testimonials or invented business details. Never claim a booking was actually made.

## Definition of done / final report

- `npm run typecheck` passes.
- `npm run build` passes.
- Actual Next.js browser renders at four viewport sizes, with screenshots saved.
- No JS errors, broken links/images, or horizontal scrolling.
- Main menu, filters, Before/After control and preview drawer operate as described.
- Visual review report explains any material departures from locked references.
- End with a brief summary of changed files, commands/tests and blockers; provide the screenshots for owner review. STOP and request visual approval before Phase 2.
