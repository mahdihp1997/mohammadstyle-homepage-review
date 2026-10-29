# ADR-B2A-001 — approved tranche plus local revision guards

Status: implemented for isolated B2A review; no B2B/production authorization.

Copy exactly the approved dependency-closed11-table B2 DDL, FKs, generated ranges and two exclusions into0004. Install trusted btree_gist in public as a separately privileged migration operation. Preserve existing three migrations/grants and inactive booking gates. Add0005 for finite recurring dates, IANA validation and local-row exact version/history guards. No new table/API role grant is needed.

Keep relational rules/local dates separate from actual timestamptz shifts; overnight recurrence splits across local days. Native exclusions serialize global staff shift conflicts and same-branch non-voided membership periods, including inactive historical membership. Rules/exceptions/published shift content are immutable revisions; stable staff/resource/stint associations do not reparent. Old rows remain referenced; updates require exact next versions.

Do not implement temporal containment, recurrence materialization, time-off/closure reconciliation, travel policy or the later ResourceAllocation ledger by pretending FKs/scalar checks prove them. These need reviewed transaction/constraint-trigger workflows and B2B tests. No authoritative slot API exists. The trade-off is explicit limited enforcement with no false double-booking guarantee.

The first real test run exposed generated NEW fields being unavailable in BEFORE UPDATE, so content comparison excludes generated outputs while preserving/freeze-checking their inputs; PostgreSQL independently rejects direct output forgery. All final constraints, drift and restore behavior are actually tested.
