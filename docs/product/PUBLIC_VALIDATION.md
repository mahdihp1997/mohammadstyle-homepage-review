# Actual sanitized public validation — 2026-11-01

Executed in this public checkout after the sanitized file transfer, not inferred from static preview:

- Frontend and backend npm ci, typecheck and production build: passed, exit0. Initial attempts hit an existing Windows npm cache stat/UNKNOWN error; isolated fresh caches completed successfully without changing dependency versions.
- New transport checks:4 passed on actual incomplete HTTP uploads plus a genuine authorized CMS image upload.
- New actual Chromium/Next/Nest/PostgreSQL/HTTP-provider journeys:6 passed,0failed,errors[]; desktop/mobile full payment/cancellation and real MFA admin operations, all4 viewport rendering.
- Public source audit passes; cross-check against private source verifies290 runtime/contract/SQL/test files identical.59 known private credential values and24 non-public asset hashes checked;0matches.18 existing public media files remain unchanged (14 placeholders,4 already-approved labeled AI service concepts). No private commit object exists in this repository. Known-value/hash checks are not a universal secret detector.

The public frontend/browser tests used the same isolated, compiled private API/worker/PG and HTTP mock provider, whose source matches this checkout; secrets were referenced through external ignored environment files and never copied to this public source. Backend compilation here is actual. Full native/legacy regression evidence in VALIDATION.md comes from the private isolated execution, not a separate claim of rerunning every old suite publicly. The new CI workflow independently provisions and executes public native/browser tests; inspect its actual status in the Draft PR.

Presentation/audit/test-harness differences and omissions are enumerated in EXPORT.md. No Booking application behavior was altered for export. No public deployment, live SMS/payment or owner acceptance is claimed.
