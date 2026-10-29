# 10 — Recommended Phase 03B sequence (not started)

**PROPOSAL / ARCHITECTURE ONLY.** No implementation, real booking, payment, external message, database service or migration was executed.

## Approval gate

Review architecture/SQL/OpenAPI/diagrams, record accepted ADRs and answer blocking decisions first. Nothing in this document authorizes a migration, backend scaffold, real payment or external message. The private frontend stays on its current demo provider until an explicit integration task is approved.

| Tranche | Proposed implementation after approval | Acceptance gate |
| --- | --- | --- |
| B0 | Pin supported versions/deployment model, security patch plan, secrets and disposable DB test environment | Restore-capable isolated environment; no production data; approved version matrix |
| B1 | Nest module boundaries/IAM/context, business/branch/catalog/offering repositories; curated migration SQL with Prisma | Scope-negative tests; migration/rollback/drift review; only verified business configuration, no demo seed import |
| B2 | Staff memberships/qualifications, recurrence materialization, resources, unified occupancy/exclusion | Real PostgreSQL conflict/shift/DST/time-off/schedule-edit tests; explain plans on representative data |
| B3 | Immutable quotes, policy resolver/conflict publication and explicit acceptance | Unit/rounding/precedence/retirement/snapshot consent tests; local legal review of actual terms |
| B4 | Hold/state/revision engine and idempotent commands/outbox | Multi-session concurrency, A-B-A expiry/callback races, fault injection, reschedule rollback; no network under locks |
| B5 | Approved server-provider adapter/DTO evolution behind a flag | Preserve UI; actual frontend typecheck/build/92+ Playwright tests and real screenshots; server values never mislabeled demo |
| B6 | Selected payment sandbox and compensation/reconciliation | Merchant/unit verification, duplicate/late/mismatched callbacks, reserved partial refunds and outage recovery proven |
| B7 | Transactional notification adapter and preference/template admin | Explicit consent/linking/duplicate/unknown-outcome tests; no production sending until authorized |
| B8 | Content CMS/object pipeline and consent publication gates | Malicious upload, overwrite, EXIF, multi-subject rights, revocation/cache/purge tests |
| B9 | Operational reports, restore/load/security review, staged production rollout | Owner sign-off; verified configuration; operational runbooks; monitored rollback plan |

The first operational booking MVP can stop before paid rollout if actual owner-approved policy requires no online deposit; it must not silently assume that policy. Payments remain disabled until B6. Bots/marketing, packages, multi-provider/parallel planning, advanced CRM/accounting and analytics follow separately. Do not implement all 72 target-envelope tables at once merely because they are described here.

## Database rollout discipline

Generate/apply no migration in 03A. In 03B create reviewed migrations from a disposable shadow database, manually preserve range/exclusion/generated/permission features Prisma cannot represent, compare actual catalog to the approved spec, and test forward/restore paths. Avoid production db push or automatic startup migrations. Provision extension rights through a deployment role. SQL parser success is syntax checking only, not migration correctness or concurrency proof.

## Operational readiness

Assign owners for alerts, reconciliation, failed holds/queue work, upload moderation, rights revocation, backups and incident handling. Validate RPO/RTO proposals with a real restoration exercise; approve retention/keys/costs. Quota/rate/search limits must be measured before exposing high-cost whole-plan queries. Do not treat optimistic cache results or graceful provider mocks as reliability evidence. Production rollout remains a separate authorized action.
