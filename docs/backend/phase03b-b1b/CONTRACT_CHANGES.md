# Reviewed B1B API profile and DTO mapping

backend/openapi.b1b.json is the12-operation implemented admin-only profile. Historical docs/architecture/openapi.yaml is preserved as the wider design proposal, not falsely claimed fully implemented. All routes remain /api/v1. Frontend demo types/provider/reducer remain untouched and are not connected to this API.

| Field / change | B1B mapping and reason |
| --- | --- |
| IDs | Server UUIDs; business is derived from bound session; body businessId/actor/role rejected |
| Stable code | Branch/Service code accepts ASCII stable identifiers and is immutable after create; display text remains Unicode |
| BranchWrite / ServiceWrite | Approved required keys retained; nullable address/description preserved; no arbitrary metadata mass assignment |
| OfferingWrite | Approved money/version-unit shape retained; unknown price/duration/buffers explicitly null; active=false, resourcesConfirmed=false, eligibleStaffIds/resourceRequirements empty for writes in this tranche |
| Existing resource configuration | Read existing ResourceRequirement honestly; existing configured offering updates fail closed until future command, no silent erase |
| Admin response projections | Explicit AdminBusiness/Branch/Service/Offering types; version decimal string maps row_version; configurationVersion remains separate. Service/Offering writes return the full explicit admin record rather than minimal RecordVersion, for reviewable administrative feedback |
| Public Offering proposal | Public nested-service/bookability/issue projection remains unimplemented; admin profile exposes serviceId and explicit nulls, not an invented public booking offering |
| Session | authenticated=true + userId + businessId + role/branch/permission tuples; replaces flattened optional permissions/branchIds in the implemented admin profile to preserve grant-to-scope correlation; no token or CSRF secret returned by GET |
| Added GET admin routes | Required read endpoints plus /admin/business select only session business; no arbitrary tenant URL selector |
| Added POST session/revoke | Self invalidation only; CSRF/Origin/idempotency; no bootstrap/login/other-user revoke API |
| Pagination | limit1..100(default25), offset0..10000(default0), sort asc/desc on stable code then ID; strict query keys. This is bounded offset pagination for small config; no speculative performance index |
| PUT | If-Match quoted positive bigint, missing/stale412; codes/association cannot change |
| Mutations | ASCII Idempotency-Key16..128, JSON only, exact Origin/CSRF; body allowlists at HTTP and DB. No real policy or payment enforcement |

These are explicit review-profile extensions/tightenings, not a silent frontend breaking change. Future clients should bind to this reviewed admin profile after approval. Production CSRF distribution/login and public booking contract adapters remain open decisions.
