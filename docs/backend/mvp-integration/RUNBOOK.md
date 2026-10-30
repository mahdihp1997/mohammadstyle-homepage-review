# Isolated review runbook

Requirements: Node 24.16.0, Docker, FFmpeg/FFprobe and Python 3. Use the existing checkout; do not scaffold an app. All profile ports are loopback only. Frontend: 3000; API: 3112; dedicated PostgreSQL: 55450. Original B4 databases/port 55446 remain untouched.

```powershell
npm ci
cd backend
npm ci
npm run typecheck
npm run build
npm run mvp:env
npm run mvp:up
npm run mvp:migrate
npm run mvp:verify
$env:APP_ENV='mvp-local'
npm run test:mvp:schema
npm run test:mvp
npm run test:mvp:storage
npm run mvp:fixture
node scripts/mvp/ui-media.mjs
npm run mvp:start
```

`mvp:env` writes random credentials to ignored `.env.mvp.local`. No credentials are committed. The fixture is an explicit offline trusted test tool: it provisions synthetic verified identities and roles, not a runtime HTTP login or production bypass. It never imports salon assets or commercial facts. Existing verified synthetic sessions can be rotated using `node scripts/mvp/refresh-session.mjs`; old sessions are revoked. Review/session/browser state is private under ignored `.local/mvp/`.

In a separate terminal at the frontend root:

```powershell
$env:MS_MVP_ENABLED='1'
$env:MS_BOOKING_SERVER_ENABLED='1'
$env:MS_BOOKING_SERVER_PROFILE='mvp-local'
npm run dev -- --hostname 127.0.0.1
```

Visit `/admin`, `/portfolio`, `/booking?mode=server`, or unchanged DEMO `/booking`. Admin/SERVER require the real synthetic session cookie and CSRF token established by the trusted test tools. `npm run test:ui:mvp` sets those cookies using the ignored fixture and captures real browser screenshots. No session token is included in review deliverables. Run `node scripts/mvp/open-review.mjs` from `backend/` to open an authenticated local synthetic Chrome review session; close it when finished. The script is a guarded offline test utility.

Do not run `next build` while `next dev` uses the same checkout. Build verifies the disabled production surface; the integrated flow is exercised with `npm run dev` and explicit local flags.

## Tests

```powershell
# backend, with APP_ENV=mvp-local
npm run test:mvp
npm run test:mvp:schema
npm run test:mvp:storage
npm run test:b4:isolated

# frontend, actual dev app
npm run typecheck
npm run build
npm run test:ui
npm run test:ui:mvp
```

`test:b4:isolated` reroutes copied profile plumbing and preserves the original test bodies. It uses owned disposable tmpfs projects, never original databases. Port 3110 must be free for the original B4 HTTP tests. On Windows use installed Chrome by setting `PLAYWRIGHT_CHANNEL=chrome`; CI installs Chromium.

For the unchanged 12 SERVER tests, `node backend/scripts/mvp/booking-fixture.mjs` creates a separate synthetic tenant, including the original optional-deposit scenario. Temporarily copy its ignored `booking-session.json` to the old test harness location `.local/b4/ui-session.json`, preserving/restoring any original local file. Run `npm run test:ui:server` with all three local MVP/Booking flags. This reuses the original tests against the integrated API without touching the B4 database.

## Recovery and S3

Stop API/browser writers before a consistent backup. `npm run mvp:backup` uses actual `pg_dump`; `npm run mvp:restore` targets only marked `ms_mvp_restore` and compares every table/catalog fingerprint. `node scripts/mvp/media-backup.mjs` verifies source hashes, backs up required local objects and restores a separate copy. Dumps/objects/credentials are excluded from public artifacts.

For S3 set `MVP_STORAGE=s3`, `MVP_S3_ENDPOINT`, `MVP_S3_BUCKET`, `MVP_S3_REGION`, `MVP_S3_ACCESS_KEY`, `MVP_S3_SECRET_KEY` in the local process environment. Use a dedicated bucket with owner-only ACL and no bucket policy; credentials need GetBucketPolicy/GetBucketAcl/GetObject/PutObject. Public buckets fail closed. TLS is mandatory for remote endpoints; HTTP is restricted to loopback protocol tests. Secrets must never be committed. A live provider compatibility/recovery drill is still required before deployment; the local object-backup tool intentionally refuses S3 mode.

Stop only this profile with `npm run mvp:stop`. No tool performs FORCE database drop or terminates other database sessions. Never reset real data or reuse the synthetic fixture in production.
