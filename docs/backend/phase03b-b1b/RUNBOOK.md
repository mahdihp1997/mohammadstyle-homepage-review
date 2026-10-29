# Isolated B1B runbook

Use Node24.16.0, Docker and the original private repository. Never use production credentials. Backend scripts reject non-allowlisted DBs and unexpected identities/markers; resets are allowed only for the new disposable test DBs and never use FORCE or terminate sessions.

1. In backend/: npm ci --ignore-scripts --no-audit --no-fund (local run used --offline and a verified cache).
2. npm run b1b:env; npm run b1b:up. Independent cluster55436; random secrets remain ignored.
3. npm run typecheck; npm run build; npm run b1b:migrate. Only reviewed forward versions, no startup migration.
4. npm run test:b1b executes actual83 scenarios and **recreates only marked B1B dev/failure/restore test DBs**. It creates synthetic users/roles in the harness, mints test sessions in memory, runs Nest on3102 and closes it. There is no universal login or HTTP provisioning route.
5. npm run test:b1a:isolated runs unchanged47 tests in an ignored copied harness/tmpfs55437, then removes that project. npm run test:b0:isolated runs14+35+Prisma in separate tmpfs55435. Do not run original destructive B0/B1A test commands against their approved clusters.
6. npm run b1b:verify; node scripts/b1b/check-contract.mjs; npm run check:secrets.
7. npm run b1b:backup then npm run b1b:restore for a fresh source snapshot/custom archive and separate restore comparison. The dump stays ignored. Roles are provisioned before restore.
8. Optional local API: set APP_ENV=b1b-local, keep NODE_ENV non-production, npm run b1b:start. Loopback3102 HTTP is for harness requests only; Secure cookie flags are retained and normal browser login remains unavailable. Test-only provisionSession is imported by the controlled harness with a marked DB and existing SYNTHETIC active user/membership, not exposed as an endpoint.
9. Frontend root: npm run typecheck; npm run build; PLAYWRIGHT_CHANNEL=chrome npm run test:ui locally (CI uses installed Chromium). Preserve/restore own generated tracked private UI artifacts; never export client-face screenshots.
10. npm run b1b:stop stops only the new project and preserves its volume. Never prune global Docker state or reset B0/B1A volumes.

Review production identity/MFA/recovery, HTTPS/proxy/CSRF distribution, session/retention limits, distributed throttling and operational secret/backup controls before any deployment. Stop after B1B approval; do not begin booking engine/payments/workforce/scheduling.
