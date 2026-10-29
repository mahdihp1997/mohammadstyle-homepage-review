# Isolated B2B runbook

Node24.16.0, PostgreSQL18.6 pinned image and backend locked dependencies. No upgrades.

1. backend/: npm ci --ignore-scripts --no-audit --no-fund. Local execution used verified offline cache.
2. npm run b2b:env; npm run b2b:up. New project mohammadstyle-b2b/loopback55440, independent random ignored credentials and volume. TCP health check avoids temporary init-server readiness. Old projects remain untouched.
3. npm run typecheck; npm run build; npm run b2b:migrate. Runner uses eight source checksums, atomic history/catalog transaction and advisory migration lock; never app-startup migration or prisma db push.
4. npm run test:b2b. Recreates only marked ms_b2b_dev/failure/restore; actual Nest on3104, synthetic users/sessions in memory, no HTTP login/helper. Preserves prior test bodies.
5. node scripts/b2b/b2a-regression.mjs. Unchanged69 baseline tests on a new tmpfs clone55441, then83/47/14/35/Prisma in their own nested copies/clusters. No old evidence/result overwrite.
6. npm run b2b:verify; node scripts/b2b/check-schema.mjs; node scripts/b2b/check-secrets.mjs.
7. npm run b2b:backup; npm run b2b:restore. Actual custom dump stays .local/b2b/backup; separate restore validates exact row/catalog/grant equality.
8. Optional local-only API: APP_ENV=b2b-local, NODE_ENV non-production, node dist/workforce/main.js; listens127.0.0.1:3104. No login or provisioning endpoint. Session fixtures belong only to controlled tests.
9. Root frontend: npm run typecheck; npm run build; PLAYWRIGHT_CHANNEL=chrome npm run test:ui locally. Actual tests use four existing viewports. Keep private screenshots private; preserve original tracked review artifacts after collecting the new summary.
10. npm run b2b:stop stops only this project, retaining its volume. Never prune Docker globally or reset approved B0/B1A/B1B/B2A DBs.

Public CI checks sanitized source before install and exports result JSON only. No production migration, identity data, backup archive, private photographs/fonts/references or UI screenshots are exported.
