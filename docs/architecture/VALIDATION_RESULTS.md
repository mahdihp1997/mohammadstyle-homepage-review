# Actual Phase03A hardening validation

**Static specification checks and actual diagram rendering only.** No PostgreSQL execution, successful migration, EXPLAIN, concurrency/auth/provider/backend runtime test is claimed.

| Check | Result | Actual evidence |
| --- | --- | --- |
| PostgreSQL18 syntax parsing (no execution) | PASS | {"fullStatements":423,"b1Statements":70,"parser":"pgsql-parser18.3.1 / libpg_query18.2.1","postgresqlExecution":false} |
| Review-only DDL AST whitelist and no seeds | PASS | No INSERT/UPDATE/DELETE/COPY, backend server or migration execution. |
| Every FK target/key/type remains valid after pruning | PASS | {"tables":72,"foreignKeys":254,"checks":250,"generatedColumns":5} |
| SQL/model column, key and constraint correspondence | PASS | 72 model tables match parsed CREATE TABLE column/key/check counts; generated columns are separate ALTER definitions. |
| Quote identity and integrity separation in draft | PASS | Content hash non-unique, actor-owned UUID identity and request idempotency separate; independent rows are representable (not inserted into DB). |
| Hash payload schema, golden digest and independent-customer vectors | PASS | {"schema":"JSON Schema2020-12 / AJV8","digestVectors":5,"independentActorsWithSameHash":2,"invalidPayloadShapesRejected":3,"scope":"Static vectors only; raw duplicate-key/Unicode, semantic rows and real requests remain future backend tests."} |
| Temporal membership and period-bound references | PASS | Period exclusion includes closed/inactive/archived history; eligibility/rule FK retains exact stint. Cross-row date containment not executed. |
| Static membership interval examples | PASS | 5 specification examples; no PostgreSQL exclusion or race test executed. |
| Draft shape truth table and every allowed transition | PASS | {"staticShapeCases":80,"validShapes":12,"representedTransitions":17,"monotonicOldNewValueGuard":"Required future command/grant/trigger tests; not proved by CHECK"} |
| All index categories, FK coverage and no redundant unfiltered support prefixes | PASS | {"retainedByCategory":{"integrity":185,"fk-support":74,"operational-recovery":3,"exclusion":4},"removedIdentityHelpers":46,"deferredQueryCandidates":15,"automaticCreatedByIndexes":0,"oldStandaloneIndexes":193,"newStandaloneIndexes":85,"checkedFkSupport":74,"explainExecuted":false} |
| Four exclusion definitions and deferred active-revision FK | PASS | 4 integrity arbiters; syntax present, catalog behavior/extension volatility/concurrency not executed. |
| B1 exact table inventory, FK closure/order and inactive gates | PASS | {"tables":["app_user","business","permission","auth_identity","auth_session","role","branch","role_permission","user_role_assignment","service","branch_service_offering","offering_resource_requirement","audit_log","idempotency_record","outbox_event","consumer_inbox"],"tableCount":16,"deferredTables":56,"parentClosure":true,"createBeforeFks":true,"temporaryInactiveGates":2,"migrationExecuted":false} |
| OpenAPI3.0.3 structural/ref validity and hardened DTOs | PASS | {"paths":69,"operations":71,"schemas":82,"validator":"swagger-parser13.1.0","deployed":false} |
| Module DAG and exact diagram edges | PASS | {"nodes":18,"cycles":0} |
| Full ERD and bounded-context projection coverage | PASS | {"fullEntities":72,"fullForeignKeyEdges":254,"contextViews":16,"ownedTableCoverage":72} |
| Actual image pairs and explicit payment alternatives | PASS | {"actualSvgPngPairs":26,"contextViews":16,"sequenceSource":"sequence.json + editable SVG","privateAssetsEmbedded":0} |
| Dictionary, ADR and scenario synchronization | PASS | {"scenarios":29,"adrs":19,"workingBackendTests":0} |
| Private baseline/ref and original runtime preservation | PASS | {"originalHomepageBookingAssetsTestsChanged":0,"privateArchitectureBase":"ab62e845bcbf7c351c29c6d77078d3bcfb97793a","phase02BaselinePreserved":true,"frontendCommandsRerun":false} |

## Commands run

- node work/phase03a-hardening/schema.mjs:72 tables,254 FKs,250 local checks,16-table B1;193→85 standalone indexes.
- node work/phase03a-hardening/contracts.mjs:69 paths,71 operations,82 OpenAPI schemas; exact hash schema and synthetic vectors.
- node work/phase03a-hardening/docs.mjs:19 ADRs and29 future acceptance scenarios, not backend tests.
- node work/phase03a-hardening/diagrams.mjs:26 actual SVG/PNG pairs,16 bounded-context ERDs; full source ERD preserved.
- node work/phase03a-hardening/validate.mjs: all static checks in this table passed. Tooling isolated in review scratch; app dependencies unchanged.

Initial local YAML parsing hit its alias expansion guard on the prior generator output; trusted local input was parsed with a bounded higher limit and the revised YAML is emitted without anchors/aliases. First diagram hardening render used reserved DOT node name edge; renamed to proxy and reran successfully. Final parser/validator/render commands exited0.

## Limits / next executable evidence

Syntax parser acceptance does not validate actual DDL catalog behavior, generated-expression volatility, extension installation, grants/triggers or SQL row behavior. The interval/truth/hash vectors are restricted specification calculations; they do not run booking commands, insert customers, execute exclusions, prove concurrency or certify RFC8785 library interoperability. Duplicate raw-key/Unicode/date/semantic containment and full financial/state/permission cases still need production-language unit/integration tests and a disposable real PostgreSQL environment after approval.

No frontend source/dependency/asset/existing test changed; npm ci/typecheck/build/test:ui were not rerun in this architecture-only hardening pass. No prior Phase02 results are presented as backend QA. Business policy strategy, actual configuration/legal terms and implementation approval remain open. Browser results for the architecture review page are recorded separately in REVIEW_PAGE_CHECK.json and never called Next.js QA.


## Architecture review HTML browser check

node work/phase03a-hardening/check-review-page.mjs exited0. Actual installed Chrome/Playwright at1440x900 and390x844 loaded all26 images and verified90 local links; no horizontal overflow or JS page errors. Scope is the architecture review document only, never Next.js/backend QA. Receipt:REVIEW_PAGE_CHECK.json.
