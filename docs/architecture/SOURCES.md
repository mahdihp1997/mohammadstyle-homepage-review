# Source boundaries and references

## Original sources (not generated specifications)

- User Phase 03A request: supplied attachment, preserved privately as sources/PHASE03A_REQUEST.txt; excluded from the public architecture export as unnecessary raw task material.
- Private baseline 2155872cc626d7463d94500b678d875bec0e4dc6: AGENTS.md, docs/PROJECT_CONTEXT.md, docs/VISUAL_CONTRACT.md, docs/BOOKING_UI.md, docs/BOOKING_REVIEW_FIXES.md, data/business-facts.json, types/booking.ts and lib/booking/{state,availability,catalog,policies,validation,calculations}.ts.
- Existing confirmed brochure facts are preserved verbatim; data/booking-demo.ts is reviewed as simulation code and is never production seed input.

The numbered documents, SQL/model/dictionary, OpenAPI, ADRs and rendered diagram sources are **derived proposals**. Their examples are synthetic, not actual staff/prices/customers/policies. Baseline frontend/tests/assets/dependencies remain unchanged. Dates below identify source consultation, not a claim to current legal advice or deployed compatibility.

## Primary technical references consulted 2026-10-29

- [NestJS modules](https://docs.nestjs.com/modules): module encapsulation/exported providers.
- [PostgreSQL 18 range types](https://www.postgresql.org/docs/18/rangetypes.html): range semantics and exclusion/GiST capabilities.
- [PostgreSQL 18 constraints](https://www.postgresql.org/docs/18/ddl-constraints.html): FK/unique/check/exclusion behavior and cross-row limits.
- [PostgreSQL 18 transaction isolation](https://www.postgresql.org/docs/18/transaction-iso.html): serialization failure/retry responsibilities.
- [PostgreSQL 18 date/time](https://www.postgresql.org/docs/18/datatype-datetime.html): instant representation versus timezone names.
- [Prisma unsupported database features](https://www.prisma.io/docs/orm/v7/prisma-migrate/workflows/unsupported-database-features): reviewed custom SQL for features outside the ORM model.
- [BullMQ idempotent jobs](https://docs.bullmq.io/patterns/idempotent-jobs) and [production guidance](https://docs.bullmq.io/guide/going-to-production): retry-safe jobs and durable queue configuration. The requested Redis backend is selected; no new alternative is introduced.
- [OpenAPI 3.0.3 specification](https://spec.openapis.org/oas/v3.0.3): deliberately pinned contract format for validator/tool compatibility, not claimed latest.
- [OWASP authorization](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html), [sessions](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html), [file uploads](https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html): security control references, not a security certification.
- [S3 presigned URL behavior](https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-presigned-url.html): time-limited access/reuse/overwrite considerations; compatibility of a future S3-compatible provider must be tested.
- [UK CMA cancellation guidance](https://www.gov.uk/government/publications/cancelling-goods-or-services-guide-for-consumers/cancelling-goods-or-services): illustrative evidence that non-refundable labels do not settle consumer-law questions; not a determination of Iranian/applicable law.

Every project-specific precedence, table, workflow, endpoint, role matrix and rollout trade-off is our proposed design, not a claim that an external source prescribes this salon's rules.


## Hardening sources consulted2026-10-29

The owner-provided architecture findings define this review scope, separate from derived decisions. Private review baseline ab62e845bcbf7c351c29c6d77078d3bcfb97793a is preserved in Git. [RFC8785 JCS](https://www.rfc-editor.org/rfc/rfc8785.html) informs deterministic JSON serialization; [PostgreSQL18 constraints](https://www.postgresql.org/docs/18/ddl-constraints.html), [range types](https://www.postgresql.org/docs/18/rangetypes.html) and [multicolumn indexes](https://www.postgresql.org/docs/18/indexes-multicolumn.html) inform draft integrity/index choices. All project-specific period/hash/stage/policy alternatives remain proposals, not externally prescribed business facts.
