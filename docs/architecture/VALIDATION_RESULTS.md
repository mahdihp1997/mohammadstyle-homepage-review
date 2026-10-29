# Actual architecture validation results

2026-10-29. These are **static specification checks and actual image rendering**, not working backend tests. No migrations or database statements executed against PostgreSQL; no provider/API connected.

| Check | Actual result | Evidence |
| --- | --- | --- |
| PostgreSQL18 syntax parser | PASS | {"statements":530,"executedAgainstDatabase":false,"parser":"pgsql-parser18.3.1 / libpg_query18.2.1"} |
| No seed/DML/migration execution material | PASS | CREATE/ALTER/index draft only; no seed inserts. |
| Relational model keys, FK arity/types/unique targets | PASS | {"tables":72,"foreignKeys":254,"checks":242,"generatedColumns":4} |
| Global exclusions and deferred revision identity | PASS | 3 exclusion constraints; globally keyed resource/staff, explicit expiry release, deferred active revision. |
| OpenAPI3.0.3 schema and local refs | PASS | {"validator":"@apidevtools/swagger-parser13.1.0","paths":67,"operations":69,"schemas":78,"deployed":false} |
| API operation IDs / auth / concurrency / idempotency metadata | PASS | {"uniqueOperationIds":69,"allContractsHaveMetadata":true} |
| Money lexical examples | PASS | Canonical nonnegative multiple-of10 strings; max bigint checked in future server, no runtime arithmetic implementation tested. |
| Module dependency DAG | PASS | {"nodes":18,"domainContexts":16,"compositionLayers":1,"sharedKernel":1,"cycles":0} |
| ERD entity/edge coverage and actual image artifacts | PASS | {"entities":72,"relationships":254,"actualSvgAndPngPairs":9,"embeddedPrivateAssets":0} |
| Architecture request scenario coverage | PASS | {"specifiedScenarios":18,"executedBackendScenarios":0} |
| Original feature branch and frontend source unchanged | PASS | {"originalFeatureRef":"2155872cc626d7463d94500b678d875bec0e4dc6","runtimeSourceDiff":0,"existingTestsUnmodified":true,"frontendCommandsRerun":false,"reason":"Documentation-only; user requires existing frontend checks only when source is touched."} |

## Commands and outputs

- `node work/phase03a/generate-schema.mjs`:72 tables,254 FKs,242 local CHECKs; generated review-only SQL/model/dictionary/ERD.
- `node work/phase03a/write-api.mjs`:67 paths,69 operations,78 schemas.
- `node work/phase03a/write-validation.mjs`:18 future acceptance scenarios.
- `node work/phase03a/render-diagrams.mjs`:9 actual SVG+PNG pairs; renderer receipt in diagrams/rendered/render-receipt.json.
- `node work/phase03a/validate.mjs`: all checks in the table passed; PostgreSQL parser statement count and schema validation details recorded above and in JSON.

Tools live only in isolated review scratch, never app dependencies. npm/Python package fetches initially failed/time-out because of DNS/network; isolated parser packages were subsequently fetched with native curl and verified against registry SRI, without running package scripts. The first Graphviz render hit a WASM layout assertion; enabling Graphviz newrank resolved it. The final render command exited0 and produced all reviewed files. These tooling failures are not hidden backend results.

## Limits and unexecuted gates

No database DDL execution, extension installation, actual query plans, constraint-trigger/grant checks, multi-session races, provider sandbox, legal enforceability, auth penetration test or load/restore exercise occurred. Syntax parsing does not validate PostgreSQL expression volatility/DDL catalog behavior or transaction correctness. JSON/FK/DAG checks do not prove runtime authorization or policy enforcement. Required integration cases are specified in VALIDATION_MATRIX.md and hardening gates in03_DATABASE_DESIGN.md. The broad72-table envelope is staged, not a mandated one-shot migration.

`npm ci`, `npm run typecheck`, `npm run build` and `npm run test:ui` were **not rerun in03A**, because no frontend source, dependency or existing test changed. Earlier Phase02 results are historical and not presented as03A backend QA. Source/ref guards above verify preservation. No UI screenshots are required for this documentation-only task; the delivered images are actual architecture renders, not fabricated app screenshots.


## Architecture visual index browser check

Installed Chrome/Playwright opened the actual local REVIEW.html at1440x900 and390x844. All9 diagram images loaded,34 local links resolved, no horizontal overflow and no page JS errors. This checks the architecture review document only; it is explicitly not Next.js or backend QA. Command: node work/phase03a/check-review-page.mjs; exit0. Machine receipt:REVIEW_PAGE_CHECK.json.
