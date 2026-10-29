# Start here — Mohammad Style (Phase 1)

**This is an existing Next.js app, not a blank project.** Do not scaffold a new application or replace its visual design.

## Current status

- React/TypeScript and CSS Homepage draft exists in `components/Homepage.tsx`, `app/globals.css`, `data/site.ts`.
- Real client images are in `public/images/`. Referenced concept boards and crops are in `references/`.
- Offline preview passed preliminary visual checks; the actual Next.js build has **not** yet been run. Do not claim otherwise.
- Booking drawer is **visual-only**. No API, login, payments, availability, or business-policy engine is implemented yet.

## In Codex (local project)

1. Open the extracted `mohammadstyle-phase1-homepage` directory as the local project root, **not** the ZIP file and not the parent directory.
2. Paste the full contents of `docs/CODEX_NEXT_PROMPT.md` as the first task. The quick prompt below also works, but the complete file is preferred.
3. Review Codex changes and actual browser screenshots before accepting the homepage. No Phase 2 or backend until visual approval.

## For a manual smoke test

```bash
npm install
npm run typecheck
npm run build
npm run dev
```

Visit `http://localhost:3000`. If installation/build fails, record the exact error and resolve it without changing the brand design.

## Sources of truth

- `AGENTS.md` — immutable project rules
- `docs/VISUAL_CONTRACT.md` — binding UI design direction
- `docs/ACCEPTANCE_CRITERIA.md` — success gates
- `docs/VISUAL_REVIEW.md` — known differences and limitations
- `data/business-facts.json` — grounded business info / unknowns

**Never invent prices, staff, opening hours, availability, branch-2 address, phone number, reviews, or deposit terms.**
