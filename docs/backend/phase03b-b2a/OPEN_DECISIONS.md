# Explicitly not implemented / B2B requirements

1. Cross-row membership containment of every published shift/local date, including later membership closure/void correction.
2. Recurrence materialization, DST ambiguity/gap resolution, branch opening coverage and horizon completeness.
3. Shift versus time-off/branch-closure reconciliation; resource allocation ledger is a later cohort.
4. Travel time between branches; adjacent intervals do not imply practical travel feasibility.
5. Current active/verified/archived qualification/assignment/resource readiness across references.
6. Monotonic branch-wide schedule publication version and atomic audited B2B revision/exception commands.
7. Authoritative slot generation, booking/hold/resource-allocation admission and complete double-booking protection.

Additional required decisions/work:

- Production staff identity verification/linking, duplicate unlinked profile adjudication, real roster/qualifications and verified hours/resources. No staff or branch-two facts are inferred.
- Branch timezone changes with existing local rules/published instants need a reviewed versioned reconciliation workflow. The current DB trigger validates the identifier, not downstream semantic migration.
- Membership close/void with dependent future shifts, qualification revocation, branch/resource/staff activation/archive and offering readiness need authorized transaction checks. No FK tests current flags or temporal containment. A correction can retain referenced facts; no unauthenticated correction API exists.
- Rules are immutable UUID revisions, but successor configuration_version ordering across an entire branch/calendar and effective-window overlap resolution are not enforced globally. B2B must define publication/version scope, locks, CAS, audits/outbox/idempotency and conflict responses.
- Archived shifts leave the shift exclusion predicate; withdrawing them must later check accepted holds/bookings under canonical resource locks. The later allocation ledger is intentionally absent here.
- Working-hour recurrence overlap and full shift containment in opening hours are not enforced. Time-off/closure approval/reconciliation, travel buffers and DST gap/fold behavior need reviewed business/system choices. This tranche neither invents travel minutes nor materializes ambiguous times.
- Current B1B response eligibleStaffIds remains the approved empty/deferred projection even though native B2A eligibility rows can exist. New B2B read/write DTOs and granular branch/staff/resource permissions are required before exposing them.
- Resource requirements are counts of verified kinds and individual capacity units are persisted, but requirement-to-instance coverage, availability, maintenance and allocation checks remain later. Missing requirements do not grant capacity.
- Production IdP/MFA/recovery/HTTPS, distributed rate limits, credential custody, retention and operational backup controls remain B1B open gates. Mixed-service policy aggregation remains owner-undecided/fail-closed.

No listed gap is represented as complete booking safety or a passed implementation of that business rule. Known-gap tests explicitly verify the current boundary; they do not erase the gap.
