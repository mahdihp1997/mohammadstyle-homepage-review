# Executed commands and reproducibility

All commands run in the original private checkout. [backend/README.md](RUNBOOK.md) is copied here as RUNBOOK.md for exact start/stop/reset controls. Results are in evidence/. Workspace prefixes are replaced in exported logs. No database credential is in a command, screenshot or delivered log.

| Command | Actual result / log |
| --- | --- |
| node --version / npm --version |24.16.0 /11.17.0 host; image24.16.0 /11.13.0 |
| docker version / docker compose version |29.5.2 /5.1.3 |
| docker desktop start --detach | Linux engine started; no unrelated volumes touched |
| docker pull postgres:18.6-bookworm / node:24.16.0-bookworm-slim | Actual digests pinned in delivered files |
| npm install --ignore-scripts via temporary loopback registry/cache |249 pinned-lock packages installed; original registry/cache failures resolved; lock URLs normalized to official registry |
| npm ci --offline --ignore-scripts --no-audit --no-fund --cache=[WORKSPACE]/work/phase03b-b0-qa/npm-cache2 | Exit0,249 packages; backend-ci.log |
| npm run typecheck / npm run build (backend) | Exit0; backend-typecheck.log / backend-build.log |
| node scripts/infra.mjs env / db / up | Random ignored env, least-privilege role provision, actual Docker image compile and both services healthy; infra-up.log |
| node scripts/infra.mjs stop, then db | Actual project-only stop/restart preserved B0 volume; no global prune |
| npm test (backend) |14 passed,0 failed; backend-tests.log |
| npm run test:db |35 passed,23 expected SQL rejections,0 unexpected SQL errors; database-tests.log + database-results.json |
| npm run test:prisma | Validate/generate/introspect/read/transaction/catalog assertions PASS; prisma-results.json |
| npm run diagnostics | Actual container ports/UID/version/health and empty runtime control DB verified; environment-results.json |
| npm run check:secrets | Known local values/signature/ignore/path assertions PASS; secrets-results.json |
| npm run typecheck / npm run build (frontend root) | Exit0; frontend-typecheck.log / frontend-build.log |
| PLAYWRIGHT_CHANNEL=chrome npm run test:ui |92 passed,0 failed/skipped/flaky; frontend-ui.log / frontend-summary.json |

The standard owner commands are npm ci, env:init, infra:up and the checks in RUNBOOK.md. The offline cache/temporary transport bridge were local network workarounds, not required product dependencies. Installation lifecycle scripts were disabled for the clean host install; the Prisma CLI fetched its required engine during the actual validated probe. Docker build also disables scripts and uses a cache with bounded network retries. No db push, production migration, business API, real booking, payment or message command was executed. infra:reset has a strict project-volume identity guard and is documented; destructive reset and backup/restore were not executed. Successful stop/start is not a backup restoration test.


Trailing whitespace and final blank lines are normalized in exported text logs; workspace path prefixes are redacted. Test result content is unchanged.
