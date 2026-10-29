# Index review and budget

**PROPOSED / Phase03A architecture hardening only.** No backend, migration, database execution, payment or messaging implementation. Original Homepage/Booking/source/assets/tests are unchanged.

Machine inventory: [index-inventory.json](schema/index-inventory.json). Every retained index, candidate and FK support decision is recorded per table; dictionary and SQL use the same model. Counts are derived from **draft definitions**, not a PostgreSQL catalog or performance benchmark.

| Category | Proposed full-envelope count | Meaning |
| --- | --- | --- |
| PK/UNIQUE and explicit conditional uniqueness | 185 | Integrity-backed indexes; exact FK targets/business/idempotency uniqueness |
| Child FK support | 74 | Chosen baseline tenant+parent-UUID lookup; not a SQL correctness requirement |
| Recovery scans | 3 | Active hold expiry, unpublished outbox, scheduled reminder work; later tranche applies |
| GiST exclusion | 4 | Membership history, global shifts, global live occupancy, equal-rank policy routing |
| Deferred query candidates | 15 | Require representative EXPLAIN/cardinality before acceptance |

Standalone CREATE INDEX definitions decrease193→85.46 unreferenced identity-helper unique keys are removed, plus quote-hash uniqueness. Necessary composite FK-target keys remain even when the global UUID PK logically implies uniqueness: PostgreSQL requires an appropriate referenced unique target. Every FK still has a valid target. Logical implication is not permission to remove a constraint used by a physical composite FK.

## created_by and parent deletion

No automatic created_by indexes remain (previously one per table). Standalone audit actor/approver/business references are not indiscriminately indexed either. Business/User records are archived/redacted, not routinely physically deleted; rare attempted parent deletion still receives FK enforcement through a scan. This is an explicit cost/maintenance trade-off, not weakened referential integrity. User-owned auth-session/role lookup support remains where operationally useful. If a lawful physical-erasure workflow is approved later, evaluate its constraints and scan/lock costs in a disposable environment before enabling it; never disable FKs to purge identities.

## Composite coverage

Full tenant/context composite FKs are preserved. Child lookup normally uses (business_id,parent_uuid); trailing context IDs are filtered while validating the full FK. Avoid one index per branch/staff/service context suffix when the same identity-prefix lookup suffices. Existing unfiltered PK/unique prefixes cover child lookup where possible. A partial live-only index never counts as coverage for FK scans across historical rows. GiST overlap is not treated as an unfiltered B-tree parent-reference index.

Strict redundant prefixes are collapsed. Deferred examples: customer quote history, booking calendar/status/history, resource start-time/live-revision variants, audit actor/object histories, public portfolio sort, refund state and idempotency cleanup. Existing FK lookup/GiST may serve some queries adequately; do not assert they outperform a tailored candidate without a plan.

## Evidence gate before each03B tranche

For each proposed candidate capture the actual endpoint query, predicates/order/limit, active versus archived cardinality, write/retention rate, existing usable indexes, representative data and EXPLAIN (ANALYZE,BUFFERS) on a disposable database. Compare planning/execution/lock/write/storage cost; then document accepted or rejected index. B1-only DDL includes only indexes on its16 tables; later index inventory is not authorization to install them now. No EXPLAIN or index performance test was run in03A.

PostgreSQL automatically indexes PK/unique/exclusion constraints, while referencing-side FK indexes are a design choice ([constraints](https://www.postgresql.org/docs/18/ddl-constraints.html)). Leading-column selectivity guides our conservative prefix coverage rule, not a claim that all suffix queries are optimal ([multicolumn indexes](https://www.postgresql.org/docs/18/indexes-multicolumn.html)).
