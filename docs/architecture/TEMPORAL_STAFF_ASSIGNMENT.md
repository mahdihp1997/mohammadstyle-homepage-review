# Temporal branch membership

**PROPOSED / Phase03A architecture hardening only.** No backend, migration, database execution, payment or messaging implementation. Original Homepage/Booking/source/assets/tests are unchanged.

Each staff_branch_assignment UUID identifies **one employment/membership stint** in one branch, not the permanent staff+branch pair. Remove UNIQUE(business_id,staff_id,branch_id). Store valid_from inclusive and valid_to exclusive local dates in the branch timezone; null valid_to means open-ended. A generated daterange(valid_from,valid_to,'[)') and GiST exclusion on business_id,staff_id,branch_id,membership_period reject overlap while voided_at IS NULL. Finite boundary checks prevent PostgreSQL date infinities; an empty period is rejected. Memberships in different branches may overlap; actual published shifts and resource occupancy must still not overlap globally.

Example is illustrative, not a real employee: stint A [2027-01-01,2027-03-01); stint B [2027-04-01,infinity). B gets a new UUID. The old row is closed/retained and all old schedule/eligibility/history links remain attached to A. Adjacent periods are valid; overlapping same-branch periods are not. active=false or archived_at does **not** remove the historical overlap constraint. Historical membership queries use date coverage/non-voided evidence, not the current active flag; future bookability additionally requires current activation and all other capabilities.

OfferingStaffEligibility uniqueness now includes assignment_id. A returning employee gets new offering-eligibility rows referencing B; old rows are not repointed. staff_schedule_rule and staff_shift carry assignment_id; the composite shift-to-rule FK also binds the same stint. Schedule publication must check every covered local date and exact UTC shift interval against assignment period, rules, timezone, approved travel and resource availability. Those cross-row temporal checks are future transaction/constraint-trigger gates, not claims that an FK checks time containment.

## Leaving, rejoining and corrections

Close an open stint using If-Match on its UUID, exclusive validTo and an audited reason; valid_from is frozen once referenced. Lock all affected branches/resources before membership/schedule rows; recheck versions and every affected future shift/held/confirmed booking. Reject unresolved conflicts409 SCHEDULE_CONFLICT or use an explicitly approved remediation workflow; do not silently cancel or rewrite accepted history. A rejoin always creates another stint and new rules/eligibility, with normal publication checks.

voided_at + nonempty void_reason are reserved for permissioned audited correction of erroneous membership facts. Void disables future use and preserves the row/FKs/evidence; create a corrected replacement row under the same locks if needed. Never use void/archive to disguise an ordinary departure or bypass conflicts. Corrections involving referenced shifts/bookings require explicit incident review; historical evidence shows both original reference and correction trail. Application/grant guards must prevent silent unvoiding/reparenting/content edits. No correction endpoint is enabled in the current API proposal; it needs an approved reviewed workflow.

See ADR014 and V22–V24. No real employee, membership migration or overlap transaction was executed.
