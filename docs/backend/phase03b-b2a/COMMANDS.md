# Commands and actual outcomes

| Command | Outcome |
| --- | --- |
| Backend npm ci --offline --ignore-scripts --no-audit --no-fund --cache=(verified local cache) |249 pinned packages/45s, no upgrade |
| Backend npm run typecheck / build | PASS |
| npm run b2a:env / b2a:up / b2a:migrate | New isolated cluster; reviewed0001–0005 |
| npm run test:b2a | 69 PASS/0 FAIL;100 expected SQL rejections;3 observed lock-wait races |
| npm run test:b1b:isolated |83+47+14+35+Prisma PASS; disposable copied harnesses only |
| npm run b2a:verify; node scripts/b2a/check-schema.mjs | Verified no-op/catalog;27 tables, two generated/exclusions |
| node scripts/b2a/check-secrets.mjs | Known credentials/signatures/path scan; writes B2A result only |
| Frontend npm run typecheck / build / test:ui | PASS,92 actual Next.js tests across four viewports |
| Native pg_dump / pg_restore inside integration | Real custom archive/separate restore, rows+schema/grants equal |

Initial B2A run64PASS/1FAIL exposed generated BEFORE-trigger comparison blocking archive. Corrected only generated-output comparison; final tests additionally reject direct generated-column forgery. Failed attempt log/JSON remains separate; no failure is counted as passing. Remote CI is recorded separately, never inferred from workflow creation.
