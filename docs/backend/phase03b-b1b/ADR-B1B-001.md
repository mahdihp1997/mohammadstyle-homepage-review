# ADR-B1B-001 — session-bound database command boundary

Status: implemented for isolated B1B review; production auth/deployment unapproved.

Keep the B1A persistence contract/artifacts unchanged. A new non-owner API role gets only3 reviewed SECURITY DEFINER entry points. Four private helpers use SECURITY INVOKER. Functions pin pg_catalog search_path, qualify tables, contain no dynamic SQL, derive tenant/actor from verified session-hash evidence and recheck current permission/scope before replay. The owner is the separately held non-superuser migration role. New API source never imports the B1A raw-query/UUID-context port. RLS context is internal defense in depth.

Alternative broad table grants plus caller-controlled tenant settings would retain a larger abuse surface and encourage accidental raw SQL. Moving all writes into app-issued SQL with an unrestricted pooled connection would require a different reviewed boundary. This tranche chooses a small auditable DB command boundary and typed Nest ports; the trade-off is duplicated strict DTO validation and more SQL review responsibility. Direct-call abuse and catalog security/ACL drift are tested.

One SQL command commits config+redacted audit+minimal unpublished outbox+durable idempotency result. Row locks and exact If-Match enforce optimistic concurrency; identity hash and idempotency identity are separate. No external effects or automatic retries. Session revalidation occurs inside the transaction; user-before-session lock order matches offline rotation. Production provider/MFA/HTTPS, key custody, distributed throttling, recovery/retention and later resource/business rules remain gates. No owner business policy is invented.
