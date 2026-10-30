# Isolated B4 runbook

Backend working directory: backend/. The profile binds PostgreSQL only to127.0.0.1:55446 and API to127.0.0.1:3110. It accepts only marked ms_b4_dev / ms_b4_restore databases and rejects production configuration.

`npm ci --ignore-scripts` → `npm run b4:env` → `npm run b4:up` → `npm run b4:migrate` → `npm run typecheck` → `npm run build`.

Run `npm run test:b3:isolated` for unmodified historical B0–B3 assertions in independent tmpfs clones, then `npm run test:b4` (44 core +14 extra). `npm run b4:verify`, `node scripts/b4/check-schema.mjs` and `node scripts/b4/check-secrets.mjs` are read/verification commands, not automatic schema repair. Migration history/drift/owner/marker mismatches fail closed; source-only edits to an applied migration are refused.

Set APP_ENV=b4-local for `npm run b4:ui-fixture` and `npm run b4:start`. The fixture creates a separate synthetic tenant, verified customer-role sessions and explicit test configuration. Tokens are kept only in ignored .local/b4/ui-session.json, never printed or served by a login endpoint. The browser test injects those test cookies into fresh contexts. No production identity, credentials or approved salon prices are needed or supplied.

In the existing frontend set MS_BOOKING_SERVER_ENABLED=1 and run `npm run dev -- --hostname 127.0.0.1`; visit /booking?mode=server. Host and Origin must be exactly127.0.0.1:3000. Next15 normalizes nextUrl.hostname internally to localhost, so the proxy verifies the original exact HTTP Host/Origin and ignores forwarded identities. Run `npm run test:ui` for the92 original cases; `npm run test:ui:server` for the12 real authenticated browser cases. On this Windows host PLAYWRIGHT_CHANNEL=chrome selects installed Chrome; CI installs pinned Playwright Chromium. /booking without mode remains DEMO. Production SERVER/proxy startup is deliberately closed.

Every API read/command invokes a separate durable SQL sweep before work. APP_ENV=b4-local `npm run b4:reap` explicitly runs the bounded restartable sweep for quiet tenants. No in-memory timer owns capacity; every lease deadline is persisted. Production scheduling/monitoring of sweeps is an approval gate.

`npm run b4:backup` writes an ignored custom-format archive plus a value-free integrity receipt. `npm run b4:restore` verifies source/backup fingerprints and restores only the separately marked ms_b4_restore database, without FORCE or killing sessions. `npm run b4:stop` stops only the B4 Compose project. Old clusters, volumes, migrations and source branches are outside its lifecycle allowlist.
