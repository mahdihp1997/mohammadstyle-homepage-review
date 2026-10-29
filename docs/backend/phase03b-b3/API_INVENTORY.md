# Authenticated API inventory

15 new operations; retained12 B1B session/business/branch/catalog/offering operations on the same isolated API. backend/openapi.b3.json is the strict reviewed contract. Branch/actor identity derives from session; path/body IDs are selectors only.

| Method | Route | Required permission |
| --- | --- | --- |
|GET|`/api/v1/admin/pricing/quotes/{id}`|pricing.quote + actor ownership|
|GET|`/api/v1/admin/pricing/assignments`|policy.read; history additionally policy.history.read instead of ordinary read|
|GET|`/api/v1/admin/pricing/policies`|policy.read; history additionally policy.history.read instead of ordinary read|
|GET|`/api/v1/admin/pricing/context`|policy.read; history additionally policy.history.read instead of ordinary read|
|POST|`/api/v1/admin/pricing/commands/policy.create`|policy.manage|
|POST|`/api/v1/admin/pricing/commands/version.create`|policy.manage|
|POST|`/api/v1/admin/pricing/commands/version.replace`|policy.manage|
|POST|`/api/v1/admin/pricing/commands/version.publish`|policy.manage|
|POST|`/api/v1/admin/pricing/commands/version.retire`|policy.manage|
|POST|`/api/v1/admin/pricing/commands/assignment.create`|policy.manage; WHOLE_BOOKING additionally policy.override|
|POST|`/api/v1/admin/pricing/commands/assignment.revoke`|policy.manage|
|POST|`/api/v1/admin/pricing/commands/configuration.set`|policy.manage|
|POST|`/api/v1/admin/pricing/commands/quote.create`|pricing.quote|
|POST|`/api/v1/admin/pricing/commands/quote.validate`|pricing.quote|
|POST|`/api/v1/admin/pricing/commands/quote.cancellation-preview`|pricing.quote|

Commands use envelope branchId/entityId/data; the operation is a fixed allowlisted path, never a SQL selector. Every command needs If-Match pricing revision, Idempotency-Key, X-CSRF-Token, matching Origin and session. Read context first; create policy then draft version, publish, explicitly route and set branch quote TTL. List current/history with deterministic100-row pages and offset<=10000. quote.validate checks hash/TTL/current configuration; quote.cancellation-preview uses immutable hypothetical terms and executes no money.
