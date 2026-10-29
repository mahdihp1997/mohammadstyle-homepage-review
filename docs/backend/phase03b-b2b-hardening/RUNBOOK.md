# Hardening-only local runbook

backend/: npm ci --ignore-scripts --no-audit --no-fund; npm run b2h:env; npm run b2h:up. New project mohammadstyle-b2h on127.0.0.1:55442, own random ignored secrets/volume. Never reset old environments.

- npm run typecheck; npm run build.
- npm run b2h:migrate; npm run b2h:verify. Explicit manual nine-version runner, no startup migration/db push.
- npm run test:b2h recreates only marked hardening dev/failure/restore DBs; synthetic fixtures only.
- node scripts/b2h/b2b-regression.mjs runs unchanged71 in verified tmpfs55445, then the unchanged older chain in separate nested clones. Validates project/helper routes BEFORE Compose startup. Never run old destructive baseline test commands directly against original DBs.
- node scripts/b2h/check-schema.mjs; node scripts/b2h/check-secrets.mjs.
- npm run b2h:backup; npm run b2h:restore actual separate restore; archives stay .local/b2h/backup, never export.
- APP_ENV=b2h-local, NODE_ENV nonproduction, npm run b2h:start serves loopback3106 only after migration readiness. No login/role provisioning or production IdP. Original B2B DB remains an untouched baseline; its legacy profile is not the current CLI.
- Root: npm run typecheck/build; PLAYWRIGHT_CHANNEL=chrome npm run test:ui (CI installed Chromium). Preserve private generated screenshots; export only the synthetic summary.
- npm run b2h:stop stops this project, retaining volume; never global prune or old-volume deletion.
