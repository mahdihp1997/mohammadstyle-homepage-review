# Commands and actual outcomes

| Command | Outcome |
| --- | --- |
| git status/branch/HEAD | Clean private d6e3983 on existing B2B branch; public847f9c6 verified |
| npm ci --offline --ignore-scripts --no-audit --no-fund --cache=<verified cache> | PASS locked backend dependencies |
| b2h:env/up | New isolated55442 environment, independent credentials |
| backend npm run typecheck/build | PASS |
| npm run test:b2h | 42PASS/0FAIL,17 expected denials |
| node scripts/b2h/b2b-regression.mjs | Unchanged71/69/83/47/14/35/Prisma PASS, verified clone routes |
| b2h:verify/check-schema/check-secrets | PASS catalog/grants/noop/value-signature-path checks |
| pg_dump + separate pg_restore via runner | PASS source/restore row/catalog/effective grant equality |
| root npm run typecheck/build | PASS actual Next production build |
| PLAYWRIGHT_CHANNEL=chrome npm run test:ui |92PASS/0FAIL/0flaky, four viewports,3.5m |
| Preservation comparison | Original4 app DB snapshots,56 prior evidence/backup files and8 migration bytes identical |

A draft0009 parser/actual execution42601 was corrected before final source. A temporary clone-routing error affected service configuration only; original volume/data remained intact and restored configuration/data fingerprints were verified immediately. See SECURITY_REVIEW.md. Display logs normalize trailing whitespace/private absolute paths only; original local evidence remains ignored. Captures render actual result records, not terminal-window screenshots.
