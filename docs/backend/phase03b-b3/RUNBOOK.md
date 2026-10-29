# Isolated B3 runbook and migration/restore evidence

Node24.16.0; pinned dependencies/lockfiles unchanged; PostgreSQL18.6 image digest inherited. No auto migrations.

1. backend: npm ci --ignore-scripts --no-audit --no-fund (CI); npm run b3:env; npm run b3:up. Ignored random credentials remain local.
2. npm run b3:migrate then b3:verify; never point tools at old profiles. Only marked ms_b3_dev/failure/restore are allowed for guarded recreation.
3. npm run typecheck; npm run build; npm run test:b3; node scripts/b3/b2h-regression.mjs; node scripts/b3/check-schema.mjs; node scripts/b3/check-secrets.mjs. Tests reset only B3 or verified disposable clones.
4. APP_ENV=b3-local npm run b3:start listens loopback3108. Existing B1B session-provisioning mechanics require trusted offline evidence; no passwordless login/production session endpoint was added.
5. npm run b3:backup; npm run b3:restore restores separately and compares source/catalog/ordered row/effective privilege fingerprints. No dump or credential is exported.
6. Root npm run typecheck; npm run build; PLAYWRIGHT_CHANNEL=chrome npm run test:ui for local Chrome. CI installs Chromium. Stop the owned dev server before production build, then test actual Next app.

Actual catalog {"status":"PASS","sha256":"2a3ce8aab5a51bffb6953b9c8562fae470c5eaeb022b9afdb249d9d2e0fc3e8b","tables":38,"indexes":115,"functions":34,"foreignKeys":111,"checks":143,"exclusions":3,"apiEntryPoints":8,"publicExecute":false,"apiHasOwnerRole":false}. Actual backup 394915bytes/86460a5b98cba211a2fafe523444a18a271974d9cf5e95cbef3aede1c1dd84cd. Separate restore equality=true; source database was not overwritten. First9 migration file bytes and all5 old app DB snapshots/evidence fingerprints preserved. Static parser acceptance does not substitute for these execution checks.
