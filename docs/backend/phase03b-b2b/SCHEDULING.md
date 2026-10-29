# Scheduling invariants and bounded materializer

## Local to UTC

Recurrence uses ISO weekday1..7, local start/end minute0..1440, half-open effective dates and immutable UUID/version. The publication input is a bounded explicit occurrence list referencing stored rules. This is a materializer of reviewed occurrences, not an autonomous horizon filler. It does not claim complete availability coverage. Max62 occurrences and31 local days; API dates2020..2099, future instants only.

For each endpoint, b2b_local_instant enumerates1921 UTC candidates at minute precision over±16h, using PostgreSQL IANA rules and exact local round-trip equality. Zero candidates -> DST_GAP; multiple +reject -> DST_FOLD_REVIEW_REQUIRED; earlier/later are explicit reviewed choices. Unsupported sub-minute-offset historical cases fail closed. No Tehran constant or browser offset. Membership midnight boundaries use the same reject-on-ambiguity resolver. PostgreSQL tzdata version changes require operational reconciliation before regeneration; published UTC/local evidence never moves silently.

The materializer returns persisted UTC intervals and source/local metadata on success, and reviewed constant failure codes on failure. It checks entire current membership/resource/capability/offering/opening/exception/shift context under locks; it does not create client-selectable appointment slots.

## Overnight and corrections

Overnight plans contain two explicit rules/day segments meeting at local midnight with the same stint. An overnight=true command validates both sides in one transaction. Separate ordinary midnight-start/end rules are permitted with overnight=false. Any replacement/withdrawal must explicitly select every retained shift in each touched plan, match staff/branch and be in the future. Existing content is frozen; reviewed archival metadata plus distinct successor plan preserve evidence. Partial overnight withdrawal rejects. Past published plans cannot be withdrawn through this API.

## Membership/capability

One global staff/STAFF resource per identity, no name-based merging. Create inactive; activation explicitly updates the linked resource. Identity link needs an active account with persisted verified auth_identity and current business membership, staff.link permission and external evidence reference digest. Already-linked accounts cannot be silently relinked. Qualifications persist reviewer/time/evidence digest and audited active transitions; a qualification is never a shift.

Close sets exclusive valid_to once, retaining active administrative eligibility until the boundary; date containment governs future use. Any retained published shift outside the proposed period blocks closure. Rejoin creates another UUID, new rule and per-stint offering eligibility. Void/correction is not exposed speculatively. Deactivation/qualification or eligibility revocation with future published shifts rejects pending explicit withdrawal/review.

## Exceptions

New requests are REQUESTED. Review inserts an immutable successor APPROVED/REJECTED; one successor per root, reviewer identity required. Original pending/legacy evidence remains. Effective approved/legacy-unreviewed leaf intervals block publication; rejected requests do not. Approval overlaps any live published shift -> EXCEPTION_SHIFT_CONFLICT, no side effects. Approval cancellation/revocation is deferred rather than silently archiving a block.

## Travel

TRANSFER_CONFIGURATION_REQUIRED blocks publication if any retained live published shift belongs to another branch, regardless of gap. This is intentionally stricter than an invented transfer buffer. Owner must define directed travel/handoff semantics, effective versions and historical treatment before relaxing it. Overlap exclusion still uses global staff_id. Physical resources are identified configuration units; this phase never reserves a chair/room/device or appointment capacity.
