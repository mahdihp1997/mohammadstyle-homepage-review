# Reviewed read contract refinement

Same30 B2B routes and12 existing B1B routes; no customer/booking API. Default GET semantics narrow to current authorized data. New optional query view=current|history; no other value/unknown selector accepted. Explicit history permission is independent of ordinary read.

New projection discriminator on page, evidenceState on shifts, scopeAssignmentId and intervalScope on clipped time-off records. Source id remains a command target. starts_at/ends_at in a time-off projection are visible bounds, not full global source bounds. Multiple disjoint stints can produce multiple items for the same source id; use the documented composite projection identity. No full original interval is added under another field.

Former branch-only staff/qualification reads now exclude current global metadata even when querying a former employment window. Branch-owned rules/assignments/eligibilities/hours are constrained by applicable periods/archive mode. Legacy eligibleStaffIds excludes former memberships using the branch's current local date; it remains configuration information, not availability.

The current opt-in isolated API moves from the preserved baseline3104/55440 profile to3106/55442, APP_ENV=b2h-local; OpenAPI server/Origin updated accordingly. No production URL/client was changed. Startup refuses an unmigrated hardening profile. Original factory profile remains solely for unchanged71 baseline tests, not a supported current CLI.

Original0001..0008, registry.b2b.json and old phase evidence stay immutable. Use registry.b2h.json and b2h lifecycle/migration commands for the reviewed nine-version environment. No automatic migration or production deployment.
