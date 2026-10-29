# Actual commands and results

All backend commands run in backend/; frontend commands in original private root. Values/credentials withheld.

| Command | Actual result |
| --- | --- |
| git status / rev-parse | Clean approved private33b8934 before new branch |
| git switch -c feature/phase03b-b2b-scheduling-api33b8934 | New private branch; original refs retained |
| npm ci --offline --ignore-scripts --no-audit --no-fund --cache=<verified-local-cache> |249 packages installed,43s; locked versions unchanged |
| npm run b2b:env / b2b:up | New independent loopback55440 cluster/credentials; initial init-server race documented and TCP readiness corrected |
| npm run typecheck / build | PASS final; initial TS requestId undefined diagnostic corrected before pass |
| npm run test:b2b |71PASS/0FAIL,54 expected SQL rejections,8 real observed races |
| node scripts/b2b/b2a-regression.mjs | Preserved B2A69/B1B83/B1A47/B0 backend14+SQL35+Prisma PASS in independent tmpfs copies |
| npm run b2b:verify | No-op; eight versions/catalog verified |
| node scripts/b2b/check-schema.mjs |28 tables/88FK/101CHECK/89 indexes/18 functions/2 exclusions; five API entry points, no public EXECUTE |
| node scripts/b2b/check-secrets.mjs | PASS known-value/signature/path/ignored-env checks |
| actual pg_dump / pg_restore in test runner | PASS custom archive, separate destination, all row/catalog/effective grants equal |
| root npm run typecheck / build | PASS actual Next15.5.28 production build |
| PLAYWRIGHT_CHANNEL=chrome npm run test:ui |92PASS/0FAIL/0flaky in3.4m; four viewports; private generated artifacts restored |
| PostgreSQL18 parser + OpenAPI validator + workflow/render/protection checks | Separate static evidence in STATIC_VALIDATION.json; not a substitute for DB execution |

Earlier failed integration attempts42/13 and51/4 are retained in evidence;55/0 then expanded final71/0 passed. Read-query ambiguities, harness monitoring rights and snapshot ordering were fixed. Regression production test bodies were not weakened. Actual outputs are under evidence/*.log and JSON; captures render these real records. No native terminal-window screenshot is claimed.
