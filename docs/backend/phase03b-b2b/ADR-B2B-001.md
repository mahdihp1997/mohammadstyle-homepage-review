# ADR-B2B-001 — administrative calendar transaction boundary

Status: implemented for isolated review, not production approval. Date2026-10-30.

Use the existing opaque-session evidence with EXECUTE-only reviewed PostgreSQL functions, a coarse per-business advisory gate and whole-calendar CAS. All cross-row workforce mutations follow the gate; canonical branch/resource locks precede revision/membership/exception rows. READ COMMITTED re-reads after waiting, avoiding stale checks while retaining native global GiST exclusion. API role cannot sidestep the command boundary.

Alternative fine-grained locks/multiple aggregates could improve concurrency but increase complete-lock-set discovery/revalidation complexity before actual traffic is measured. The deliberate trade-off is serialization of unrelated branch administrators and coarse412 conflicts. No measured throughput claim. Decompose only with representative EXPLAIN/load/race evidence.

Existing0001..0005 stay immutable. Explicit legacy-unreviewed exception state avoids inventing prior approval. New immutable review successors avoid editing frozen B2A exception content. One small relational revision table supplies CAS without upgrading the business-row SHARE lock taken by session authentication, which could deadlock. Evidence references are digested; production external evidence retention and privileged reauthentication remain gates.

Fail-closed travel and blocked legacy configuration changes are documented operational restrictions, not claimed real salon policies. Published corrections require explicit complete-plan review, reason digest and new evidence. No Booking/Payment/ResourceAllocation cohort is introduced.

Primary technical references: [PostgreSQL18 isolation](https://www.postgresql.org/docs/18/transaction-iso.html), [AT TIME ZONE](https://www.postgresql.org/docs/18/functions-datetime.html), [secure functions](https://www.postgresql.org/docs/18/sql-createfunction.html). Actual executions, not these documents, provide test evidence.
