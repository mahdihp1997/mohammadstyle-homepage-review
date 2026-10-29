# Mohammad Style — sanitized Phase 02 code review

نسخه عمومی برای بررسی کد محمد استایل، شامل صفحه اصلی و پیش‌نمایش پنج‌مرحله‌ای رزرو. **این خروجی سایت آماده انتشار یا سامانه رزرو واقعی نیست.**

`review/phase02-booking` starts at sanitized public `main` (`f35a5cc20ebd497b0d8fb7b96c207549f147799f`). Application source is transferred from private Phase 02 commit `7e56ef7e584830f6a884e677f9002b9ab46ff294` as files, without importing private commits or Git objects. The original private branch remains untouched. Review through a **draft PR into public main; do not merge or begin Phase 03**.

## Run and test

Use Node.js 20.9+ and npm. The original package manifest and lockfile are unchanged.

```sh
npm ci
npm run typecheck
npm run build
npm run dev
```

Open `http://localhost:3000/` and `/booking`. The existing Homepage drawer has a demo-entry link that carries a selected service into Booking. Tests start their own Next.js app on port **3010**, including the no-JavaScript test.

```sh
npx playwright install chromium
npm run test:ui
```

Alternatively, with installed Chrome in PowerShell:

```powershell
$env:PLAYWRIGHT_CHANNEL = 'chrome'
npm run test:ui
```

## Booking behavior retained

Five RTL steps cover branch, multiple services, eligible fictional barbers, Jalali date/demo time, and summary/policy preview. The single typed reducer, upstream invalidation, asynchronous cancellable provider, validation, date utilities, calculations and domain/browser tests are preserved. Real prices/durations/policies default to unknown. Explicit fixture controls supply hypothetical values for testing. The final action produces a preview only. No reservation, payment, API, database, browser persistence or messaging exists.

## Publication boundary

All 14 sanitized Phase 01 placeholder WebPs, four labeled AI service concepts, system-font layout/CSS and public notice remain unchanged from public main. No client photos, private font files, visual-reference binaries, internal screenshots, environment files or private Git history are included. Public Booking differs only in honest placeholder descriptions and the no-JavaScript test's server address. No booking decision, arithmetic, value, assertion or flow was changed for export.

Read:

- `docs/PHASE02_PUBLIC_REVIEW.md`: current public-copy tests, exact sanitization and omissions.
- `data/phase02-public-export-manifest.json`: normalized source hashes, difference allowlist and preservation checks.
- `docs/BOOKING_UI.md`: architecture, contracts, reducer rules, demo fixtures and integration boundaries.
- `docs/VISUAL_REVIEW.md`: public review status followed by historical internal Phase 01 evidence.
- `data/business-facts.json`: the six exact services, confirmed Poonak location and unknown business facts.

`docs/PUBLIC_REVIEW.md`, `data/public-export-manifest.json`, `docs/internal-source/`, `docs/INTERNAL_README.md` and the earlier final report describe the historical Phase 01 export/source. Their validation is not Phase 02 public-copy evidence. Tests generate ignored local screenshots and reports; none are copied from the private project or committed here. Photographic fidelity and private fonts cannot be assessed in this sanitized version. Public code visibility grants no rights to withheld photos/fonts and does not imply a license grant or production deployment.
