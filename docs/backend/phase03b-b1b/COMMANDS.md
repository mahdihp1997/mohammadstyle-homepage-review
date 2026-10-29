# Executed commands and evidence

| Command | Actual outcome |
| --- | --- |
| Backend npm ci --offline --ignore-scripts --no-audit --no-fund --cache=(verified workspace cache) | PASS;249 packages installed in54s; pinned lock preserved |
| npm run b1b:env / b1b:up | PASS; independent local project/volume/roles |
| npm run typecheck / build (backend) | PASS; saved logs |
| npm run test:b1b | 83 PASS/0 FAIL; actual PostgreSQL18/NestJS |
| npm run test:b1a:isolated |47 PASS/0 FAIL; new tmpfs routing only |
| npm run test:b0:isolated |14 tests+35 SQL+Prisma PASS; separate tmpfs clone |
| npm run b1b:verify | Verified migration no-op and full catalog |
| node scripts/b1b/check-contract.mjs |12 operation/reference/security-envelope checks |
| npm run check:secrets | Known local values/signatures/path scan; not universal secret proof |
| Root npm run typecheck / build / test:ui | Actual frontend receipt/logs; approved source unchanged |
| pg_dump / pg_restore (inside integration) | Custom archive, separate DB, lossless rows/catalog equality |

Earlier failed attempts: incomplete npm ci caused premature infra pg import failure; rerun after install. Initial0003 CASE expression returned PostgreSQL42601 and the migration transaction rolled back; corrected before reviewed catalog and final tests. Historical failed attempts are not final pass claims.
