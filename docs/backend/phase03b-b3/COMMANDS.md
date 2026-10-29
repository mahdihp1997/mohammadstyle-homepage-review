# Commands and outcomes

| Command/check | Actual outcome |
| --- | --- |
| git baseline/status/branch | Private a3612dd clean; new feature/phase03b-b3-pricing |
| b3:env/up | Isolated55444 cluster; old five profiles preserved |
| b3:migrate/verify | Fresh11, upgrade9->11, no-op/drift/rollback verified |
| backend typecheck/build/test:b3 | PASS;78/0 |
| scripts/b3/b2h-regression.mjs |42/71/69/83/47/14/35/Prisma PASS |
| check-schema/check-secrets | PASS actual catalog/grants and known credential/path/signature checks |
| pg_dump/separate pg_restore | PASS38-table/catalog/effective-grant equality |
| frontend typecheck/build | PASS actual Next app |
| PLAYWRIGHT_CHANNEL=chrome npm run test:ui | Initial91/92 one system ERR_NO_BUFFER_SPACE; unchanged full rerun92/92 |
| old data/evidence/migrations comparison |5 DB snapshots,47 evidence/backup files,9 migration byte hashes unchanged |

New migration drafts were corrected after real tests caught SQL alias/generated-column/row-null issues. One new-test status expectation was corrected to the implemented strict422 validation contract. Windows nested clone paths were flattened only in temporary orchestration copies; old test assertions/source profiles were not modified. Current-head GitHub CI results are separate delivery receipts. All capture images render actual recorded results, not fictional terminal/application screenshots.
