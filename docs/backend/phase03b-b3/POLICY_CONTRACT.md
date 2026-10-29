# B3 policy semantics

All rules below are configurable engineering semantics inherited from the approved architecture or explicit task requirements, never invented salon terms. No policies are production seeds.

## Resolution

Capture a verified business and selected branch; use explicit UTC millisecond candidate instants and branch IANA timezone. Offering records/prices/durations/names/versions are server-owned. The complete candidate includes sequential service durations and configured buffers; it is a commercial context, not a feasible staff/resource allocation. Candidate selection does not query/reserve capacity.

Require ACTIVE published versions and nonrevoked assignments covering the entire half-open candidate [start,end). Exact start is inclusive; candidate end may equal effective_to. Per item rank is STAFF_SERVICE > STAFF > SERVICE > BRANCH > BUSINESS, then explicit branch specificity, then priority. This adds staff scopes above service as a documented B3 extension; priority never promotes a lower rank. Same-ranked equally-specific/priority different versions fail POLICY_CONFLICT, never choose an arbitrary winner. Native context+priority+period exclusion prevents duplicate exact-scope overlaps. Same-version ties have a deterministic UUID-ordered routing source.

If per-item winners differ, fail POLICY_CONFLICT. WHOLE_BOOKING is available only as an explicit branch assignment with policy.override, nonempty reason, exact selected service set and exact distinct underlying winning version set. The configured version must be published/applicable and belong to the business/allowed branch. It cannot cover a subset, an unrelated add-on or a changed winner. No strictest/first/sum/majority policy aggregation exists. Package/specific-booking scopes and per-item/grouped financial strategies remain outside B3.

Staff selection is optional in a commercial preview. If selected, current active/nonarchived staff, branch temporal membership and verified service/offering eligibility must cover the entire context. Version fingerprints bind staff, memberships and qualification/eligibility evidence. Voided/inactive/ended membership cannot justify a future context. An unspecified provider does not resolve staff-specific rules and is not an operational booking quote. B4 must select/revalidate a real provider and resources.

## Arithmetic and cancellation preview

Money is canonical decimal string v1 integer Rial,0..9223372036854775807, divisible by10 under the inherited unit contract. Intermediate multiplication/sums use exact PostgreSQL numeric or BigInt, never float. Percentage deposit = floor((totalRial*bps+50000)/100000)*10. Apply only explicitly configured min/max; deposit>total is POLICY_UNCALCULABLE. Fixed deposit applies once to the homogeneous whole booking. REQUIRED always calculates; OPTIONAL requires explicit boolean choice; NONE has no amount/bounds. Zero real business defaults are never inferred.

Refund FULL=10000bps/no windows; NONE=0/no windows; PARTIAL=explicit1..9999 flat/no windows; CONDITIONAL=nonempty unique threshold rows plus explicit outside rate. Before original start, floor whole minutes and choose greatest threshold<=minutes; equality is included. After start always outside rate. CancellationAllowed uses the explicit cancellationDeadlineMinutes with inclusive equality. No grace/no-show/legal exception is invented.

Preview uses frozen proposal terms and server-snapshotted total/deposit as a clearly labeled hypothetical paid base (DEPOSIT_PAID/ALL_PAID). It returns previewOnly, illustrationAssumesPaidRial and moneyExecuted=false. It neither reads real captures nor establishes an enforceable refund amount; B4/payment workflows must use actual accepted terms, one server cancellation instant and captured/unrefunded/reserved fund limits. Flat/window refund rounding uses the same inherited positive whole-Toman rule.

## History

Draft terms/refund windows can be replaced with aggregate CAS. Publication validates and hashes canonical terms, then freezes content/windows. Retirement never edits terms. Create a new monotonically numbered version and explicitly route it; old evidence persists. Assignment revocation retains its original scope/effective period and invalidates unaccepted proposals. Branch history needs policy.history.read; global unassigned/draft/other-branch versions do not leak through a branch read. No acceptance/consent is created by B3.
