# Remaining decisions / stop gate

- Real verified branch/staff/identity/capability/hours/resource data are unknown; all run fixtures are synthetic. No real salon employee or schedule is seeded.
- Directed cross-branch transfer/handoff policy, effective versions, zero-travel exceptions and historic cross-branch treatment need owner approval. Current rule blocks any retained other-branch published shift, even far apart.
- Production identity source/MFA/privileged reauthentication, browser HTTPS/CSRF distribution, distributed rate limits, session lifetimes/recovery, secret custody and retention remain B1B gates. External evidence reference digests need approved custody/retention for the underlying records.
- Whole-calendar serialization/CAS is conservative; performance and finer lock scopes need measured load/EXPLAIN evidence. Queries paginate100 rows; consumers must follow offsets. No throughput/RPO/RTO SLA is claimed.
- Automated recurrence horizon expansion, recurrence successor retirement, timezone/tzdata reconciliation and changing branch/catalog config after hours/rules exist require a reviewed workflow. Current bounded explicit occurrence materializer and fail-closed legacy gate avoid silent regeneration.
- Approved exception reversal/incident correction and past-shift correction are deliberately not exposed. Future explicit workflows must preserve evidence and later accepted booking allocations.
- Physical resource configuration does not establish allocation capacity. No ResourceAllocation/BookingHold/BookingRevision, authoritative customer slots or expiry/admission engine exists.
- Mixed-service policy/legal/unit choices remain undecided; B3/B4 quote/booking cohort, acceptance snapshots and concurrency/compensation tests need separate authorization.

STOP after B2B; do not infer permission for B3/B4, payments, notifications, CMS or deployment.
