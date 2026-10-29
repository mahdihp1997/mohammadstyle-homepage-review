# Phase 03A architecture review

**PROPOSED / REVIEW REQUIRED — Phase 03A specification only.** No backend, database, migration, gateway or notification service was installed or executed. The private Phase 02 frontend remains canonical and unchanged.

Private baseline: 2155872cc626d7463d94500b678d875bec0e4dc6. Private branch: feature/phase03a-architecture. This is a documentation branch, not approval to implement Phase 03B. Original request is retained privately under sources/; all generated specifications are separate. No demo values from data/booking-demo.ts are production seeds.

## Review order

1. Start with diagrams/rendered/overview.svg and the lightweight review package.
2. Read 01_SYSTEM_OVERVIEW.md and 11_OPEN_DECISIONS.md before treating a proposal as a business rule.
3. Review the domain, database and transaction/policy/payment specifications together.
4. Inspect schema/draft-postgresql.sql, schema/TABLE_DICTIONARY.md and openapi.yaml.
5. Review VALIDATION_MATRIX.md, VALIDATION_RESULTS.md and the ADRs. Static checks are not live-backend tests.

## Deliverables

| File | Purpose |
| --- | --- |
| 01_SYSTEM_OVERVIEW.md | Stack, deployment boundaries and scope |
| 02_DOMAIN_MODEL.md | Modules, invariants, ports, events and transactions |
| 03_DATABASE_DESIGN.md | Relational design, indexes, lifecycle and enforcement limits |
| 04_BOOKING_ENGINE.md | Holds, state machine, concurrency and service plans |
| 05_POLICY_ENGINE.md | Deterministic versioned resolution and accepted terms |
| 06_PAYMENT_ARCHITECTURE.md | Money units, verification, compensation and refunds |
| 07_NOTIFICATION_ARCHITECTURE.md | Outbox, consent, linking and delivery |
| 08_SECURITY_AND_RBAC.md | Object/branch permissions, sessions, media and retention |
| 09_API_CONTRACTS.md / openapi.yaml | Endpoint semantics and machine-readable contracts |
| 10_IMPLEMENTATION_ROADMAP.md | Gated Phase 03B sequence; nothing started |
| 11_OPEN_DECISIONS.md | Business unknowns, engineering proposals and risks |
| schema/model.json | Derived schema specification, not runtime ORM data |
| schema/draft-postgresql.sql | Review-only PostgreSQL 18 DDL; never executed |
| schema/TABLE_DICTIONARY.md | Every column, nullability, key, check and lifecycle |
| diagrams/ | Editable DOT/Mermaid ERD sources and actual rendered images |
| adr/ | Important choices, alternatives and consequences |
| SOURCES.md | Original source map and primary technical references |

The target envelope contains 72 normalized tables covering current and later modules. It is not a mandate to implement all tables in the first tranche. Dictionary rollout labels and the roadmap identify deferred packages, parallel plans, content/tagging and bot linking; payment capability remains gated on real merchant/legal configuration.

## User-requirement traceability

| Request sections | Evidence |
| --- | --- |
| 1–3 baseline/facts/stack | 01, SOURCES, project context, Git receipt |
| 4 bounded contexts | 02 and backend-modules diagram |
| 5–6 database/branches/staff | 03, dictionary, SQL, ERD, multi-branch-model |
| 7–8 booking/multi-provider | 04, booking-flow, state/concurrency diagrams |
| 9 policies | 05, policy-resolution, ADR-006 |
| 10 money/payments | 06, payment-sequence, ADR-007 |
| 11 content/media | 08, content section, schema Media owner |
| 12 notifications | 07 and outbox/inbox schema |
| 13 security | 08, permissions matrix and ADR-009 |
| 14 APIs | 09, openapi.yaml and frontend mapping |
| 15–17 files/visuals/QA | This index, review package, validation matrix/results |
| 18–20 Git/context/delivery | Separate architecture draft PR, context snapshot, delivery receipt |
