# Provisional least-privilege visibility contract

| Data/view | Required current authority | Membership/window rule |
| --- | --- | --- |
| Current exceptions/time off | schedule.read for selected branch | active, nonarchived, nonvoided stint; intersect time-off UTC with membership and requested local-day UTC bounds |
| Historical time off | schedule.history.read for selected branch | same clipping; inactive/archive admitted only with finite end already past; never voided or unknown-ended revoked future |
| Current branch closure | schedule.read | selected-branch-owned, nonarchived, actual window overlap |
| Historical closure | schedule.history.read | branch-owned retained evidence, actual window overlap |
| Current calendar/schedule | schedule.read, or verified schedule.read.own for own staff only | published/nonarchived, selected branch/staff, exact local window overlap; own read additionally full membership containment |
| Historical calendar/schedule | schedule.history.read | retained evidence in branch/staff/window; explicit state; no own-permission fallback |
| Current staff/global qualification via branch | staff.read | live membership now AND relevant requested period; no former-branch current global metadata |
| Business-wide current staff/global qualification | explicit business-wide staff.read | business-fixed session, explicit global authority; no invented historical snapshot |
| Assignment/eligibility history | staff.history.read | branch-owned evidence and applicable nonvoided membership |
| Rules/hours history | schedule.history.read | branch-owned effective-window evidence; rule membership still applicable |

Current is a projection of live record state, not a promise that the query date is today. An active closed stint may justify reviewing genuinely related past nonarchived leave within that stint; it cannot justify later leave. Archived/inactive closed past stints require the explicit historical grant. History does not confer authority over a currently archived branch; existing session/branch authorization remains fail closed.

All intervals are [start,end). Branch dates convert through its IANA timezone, not UTC midnight. At exact exclusive end there is no visibility. No raw original start/end, reason or other branch segment is exposed. Each disjoint applicable stint yields one slice; composite projection identity is id+scopeAssignmentId+starts_at+ends_at. id remains the original command target, never authority. Paging is deterministic by kind,id,assignment,visible start.

view=current is the existing default. view=history is explicit and currently supports assignments,eligibilities,rules,schedule,calendar,hours,exceptions only. Mutable staff/qualification/resources/config/context are not historical snapshots and reject this mode. New permissions are not seeded/granted to real users or implied by role labels. Owner must review actual privacy/retention/delegation before production.
