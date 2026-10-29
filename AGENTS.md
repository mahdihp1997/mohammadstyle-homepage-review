# Codex workspace rules — Mohammad Style
- Start with `docs/VISUAL_CONTRACT.md` and `data/business-facts.json`; do not invent missing business data.
- The 3 full reference boards and 6 crops are locked visual references; implement as accessible, responsive code, not as screenshot backgrounds.
- Do not redesign or expand scope without documented approval.
- Each UI page requires Playwright screenshots at requested viewports, actual visual review, and owner sign-off before the next page.
- Follow priority Correctness -> Security -> Data Integrity -> Performance -> Architecture -> Maintainability -> Styling; visual fidelity is a separate UI acceptance gate.
- Never publish recognizable client faces without confirmed rights; images are for internal mockup unless rights are verified.
- Booking Policy Engine: versioned configurable rules (including refundable/nonrefundable options); never retroactively mutate accepted booking terms silently.
- Backend later: safe transactional bookings; no fake prices or appointments; server must validate capacity and payments.

## Current implemented state / phase 1
- `components/Homepage.tsx` and `app/globals.css` contain working draft React+CSS sections. Improve in place; **do not overwrite** with a generic template.
- The `preview.html` is a static mirror for visually checking CSS offline; the actual Next app is canonical and MUST be compiled and tested separately before approval.
- The owner has approved three dark/gold concept boards as **binding visual references**; a replacement design is not acceptable without approval.
- Scope limit: only homepage until signed off. The drawer is a non-operational booking design preview.
