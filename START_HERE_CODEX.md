# Start here — sanitized Phase 02 review export

This is an existing Next.js App Router project, exported for public code review. Do not scaffold another app, replace the Homepage, import private assets/history, merge this review branch or start Phase 03.

The authoritative private implementation is commit `7e56ef7e584830f6a884e677f9002b9ab46ff294` on the untouched local `feature/booking-ui` branch. This public branch, `review/phase02-booking`, is based on the independent sanitized public main at `f35a5cc20ebd497b0d8fb7b96c207549f147799f`.

Read `docs/PHASE02_PUBLIC_REVIEW.md` for current public validation and sanitization differences; `docs/BOOKING_UI.md` for contracts, reducer, validation, calendar and calculation behavior; `data/business-facts.json` for confirmed facts; and `docs/VISUAL_CONTRACT.md` for the original visual direction and export limitations.

Run `npm ci`, `npm run typecheck`, `npm run build` and `npm run test:ui`. Browser tests use their own app on port 3010. See README for Chromium/installed-Chrome setup. Use `npm run dev` to inspect `/` and `/booking` manually.

Booking is a frontend demonstration. Fictional staff/availability and opt-in prices/policy scenarios must remain labeled as demo; real business values remain unknown. No appointment or payment can be created. Client images are represented by the inherited public placeholders and fonts are system fonts.

Historical Phase 01 prompts/reports and private-source architecture notes are reference material, not new user requests. Owner visual/technical review is required before any future phase.
