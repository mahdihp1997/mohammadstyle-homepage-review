# Mohammad Style — public Phase 1 code review

نسخه عمومی برای بررسی کد صفحه اصلی محمد استایل. سورس از نسخه داخلی `ec03330` استخراج شده است. **این ریپو نسخه عمومیِ آماده انتشار سایت یا مبنای تأیید بصری نیست.**

**Client photographs, screenshots, concept-board binaries and licensed local font binaries are deliberately absent.** Fourteen image paths contain clearly labeled neutral placeholders. The four requested AI service concepts remain visibly labeled. System fonts replace the private font files. No private Git history was copied.

The full internal implementation, original images, fonts, screenshots and commit history remain unchanged locally. Original `Homepage.tsx` and `layout.tsx` are preserved as plain-text source for exact code review in `docs/internal-source/`.

## Run

Use Node.js 20.9+ and npm.

```sh
npm ci
npm run typecheck
npm run build
npm run dev
```

Open http://localhost:3000. Browser tests use a separate server on port 3010, avoiding an already-running internal preview:

```sh
npx playwright install chromium
npm run test:ui
```

With installed Chrome on Windows: `$env:PLAYWRIGHT_CHANNEL='chrome'; npm run test:ui`.

## Read for review

- `docs/PUBLIC_REVIEW.md`: precise export differences and current public-copy checks.
- `docs/VISUAL_REVIEW.md`: historical validation of the original internal Next.js app, including the actual four-viewport screenshots that stay private.
- `docs/CODEX_FINAL_REPORT_FA.txt`: consolidated Persian report of the internal task.
- `data/business-facts.json`: confirmed facts and unknowns.
- `data/public-export-manifest.json`: origin commit and per-file hashes/change classification.

All six brochure services and RTL interactions remain. Booking is a non-operational preview only. No APIs, payments, appointments, fabricated prices or testimonials. Branch-two details and owner visual approval are pending. Public code visibility grants no publication rights to private client photos or proprietary fonts. No license grant or production deployment is implied.
