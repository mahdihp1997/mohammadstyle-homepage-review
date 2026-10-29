# Current schedule and historical evidence

Scheduling writes/publication semantics remain the approved B2B implementation.0009 changes read authority/projections only; no customer capacity is reserved.

Default GET calendar/schedule is view=current: published=true and archived_at=NULL, selected business/branch/staff, exact branch-local from/to window. CapacityReserved remains false. Draft/withdrawn/archive evidence stays persisted and cannot appear as a current published shift.

view=history requires schedule.history.read, and returns complete retained window evidence with projection=history and explicit evidenceState: PUBLISHED,DRAFT,WITHDRAWN,ARCHIVED_DRAFT. A published row included for audit remains labeled PUBLISHED; the page is nevertheless an explicit evidence view, not current operational availability. Own-schedule-only grants cannot invoke history.

Time off uses intersections of actual half-open timestamptz ranges. Date membership bounds are branch-local; resolver rejects DST gaps/folds instead of guessing. Query-local midnight is exact; no±16h read padding. Disjoint stints return disjoint slices. ScopeAssignmentId and intervalScope identify clipped projection evidence; original source interval is deliberately hidden.

Branch-only current staff/qualification reads cannot use a past membership to fetch mutable global metadata. Genuine branch-specific historical evidence needs the documented historical authority. Global qualification verification time is not a historical capability version and must never be represented as one.

A clipped branch view cannot serve as complete evidence for approving a global leave interval. Use the original reviewed request and explicit business-wide approval authority; that command is unchanged. Historical timezone edits not captured by old schema require reviewed incident/evidence handling before relying on historical local-date interpretation. No retention or employee privacy policy is invented.
