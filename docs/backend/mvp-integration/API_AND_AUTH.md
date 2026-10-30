# API and authorization contract

All authenticated routes reuse the approved session, exact Origin/Host, JSON, verified identity, CSRF, permission and branch/tenant boundaries. No caller-supplied user/tenant is trusted. Existing B1B/B2H/B3/B4 routes/DTO validators remain authoritative. There is no production authentication entry point in this phase.

| Route | Behavior |
|---|---|
| `GET /api/v1/admin/portal/workspace` | Consistent authorized view; view, optional branch, from/to, history and bounded offset |
| `GET /api/v1/admin/portal/read/:kind` | Fixed media/categories/reservations/reservation/identities/instant/policy-header projections |
| `POST /api/v1/admin/portal/commands/:op` | Strict operation allowlist; branchId/entityId/version/data, actor/route idempotency key, real CSRF |
| `POST /api/v1/admin/media/upload` | Strict fileName/base64/branchId; upload authorization precedes any native processing |
| `GET/HEAD /api/v1/admin/media/view/:id/:variant` | Authorized private safe derivative only |
| `GET /api/v1/portfolio` | Trusted configured business; active-rights/published projection and category/offset filters |
| `GET/HEAD /api/v1/portfolio/:id/:variant` | Published asset with current valid rights; THUMB/DISPLAY/VIDEO only |

Next proxies `/api/mvp/*` and `/api/portfolio/*` expose only fixed loopback paths in explicit development. New portal/upload POST responses use Nest's 201 status; response snapshots remain idempotent. Existing approved endpoints retain their original statuses. New commands use 24-hour actor/route idempotency receipts. Changed payloads cannot reuse a key. Uncertain client outcomes retain the form/key for retry.

Operations: branch.save, service.save, offering.create/configure/requirements, booking.cancel, category.save, media.edit/rights/publish/unpublish/archive. All writes have SQL permissions, typed/strict data validation, row CAS or the original aggregate revision and canonical transaction locks. Client visibility of a button is never the authorization boundary.

Media permission separation: `media.manage` imports/edits/previews; `media.rights.manage` records/revokes evidence; `media.publish` publishes. A branch-scoped role cannot assert a global scope or reach another branch. Business-wide categories require the corresponding global manage authority to edit. Identity linking uses existing verified identities and `staff.link`; there is no user creation or identity fabrication route.

Admin booking.read is separate from booking.manage. Cancellation preserves the original accepted quote and follows B4 cancellation eligibility; reason and transition are immutable. No endpoint can execute a payment or set an arbitrary paid/confirmed status.

Workforce writes and pricing lifecycle operations call the original APIs with If-Match and aggregate revision. Changing branch/service/policy context preserves their existing invalidation and fail-closed rules. The single-provider MVP and mixed-service policy owner decision remain unchanged.
