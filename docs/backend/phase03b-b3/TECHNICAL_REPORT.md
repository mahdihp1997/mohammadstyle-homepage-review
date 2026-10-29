# B3 technical report

## Delivered

- Server-owned branch offering prices, multi-service totals, integer Rial fixed/percentage/minimum/maximum/optional/required/explicit NONE deposits and remaining balance. Exact BigInt/numeric intermediates; inherited whole-Toman-compatible positive half-up rounding. No real tariff or salon rule is seeded.
- Versioned definitions, editable drafts, validated publication/frozen terms/refund windows, retirement, temporal assignments and explicit revocation. Deterministic business/branch/service/staff precedence and exact-set compatible whole-booking overrides; heterogeneous winners return POLICY_CONFLICT.
- Immutable commercial proposals/items/routing evidence, nonunique JCS content hashes, independent actor-owned UUID/expiry, durable actor/route/key idempotency, stale configuration/tamper checks, transparent terms and hypothetical cancellation/refund preview. No actual captured funds or entitlement is inferred.
-15 new authenticated operations (15 OpenAPI operations), plus12 retained B1B session/catalog/admin operations. Branch-scoped permissions, aggregate If-Match, CSRF/Origin, strict raw JSON/DTO bounds, safe SQL entrypoints, redacted audit and command-stream transactional outbox. See API_INVENTORY.md and backend/openapi.b3.json.

## Database and compatibility

0010 creates10 needed tables;0011 installs reviewed native constraints/guards/resolver/transaction boundaries. Complete registry.b3.json extends unchanged0001–0009; no old checksum is recalculated. Actual catalog: 38tables/111FK/143CHECK/115indexes/34functions/3exclusions;8 API entrypoints, no API table/private-helper grants. Catalog SHA256 2a3ce8aab5a51bffb6953b9c8562fae470c5eaeb022b9afdb249d9d2e0fc3e8b. Only identity/FK/concurrency indexes are added.

Separate local PostgreSQL18.6 cluster55444/API3108 preserves all5 prior app databases, branches and evidence. Branches remain nonbookable, offerings inactive, availability enablement unchanged. Homepage/Booking/source/assets/old assertions/lockfiles unchanged. New local factory refuses missing B3 boundary; no migration at startup.

## Deliberate dependency-safe quote boundary

The exact final V2 hash contract includes actual provider/resource segments and policy-resolution snapshot hashes. B4 has not supplied a trusted planner, so no final pricing_quote/booking/customer/revision/hold/allocation/payment table or final issuance API is fabricated. B3 persists a separately named commercial precursor and supplies a restricted JCS/V2 serialization utility verified against every approved vector. A proposal ID/hash is never accepted as a final quote. See QUOTE_CONTRACT.md for the mandatory B4 binding and remaining relational/plan validation. This is the task's expressly permitted dependency-safe portion, not a claim of operational booking quotes.

## Actual verification

{"passed":78,"failed":0,"expectedDenials":52}. Real API-role SQL + Nest HTTP, native exclusion, two-connection CAS/idempotency and data/audit/outbox rollback tests run against actual PostgreSQL. Natural60-second expiration and exact expired-key replay are observed, not only clock fixtures. All prior42/71/69/83/47 tests and B0 backend14/SQL35/Prisma pass in isolated clones. Backend/frontend typecheck/build pass;92/92 Playwright passes at four existing viewports. First local UI run had91 passes/1 ERR_NO_BUFFER_SPACE resource-load failure; unchanged full rerun passes.

Fresh11, upgrade9->11 preserving prior rows, verified no-op, checksum preservation, drift rejection, failed migration rollback and separate custom restore pass. Backup394915bytes, SHA25686460a5b98cba211a2fafe523444a18a271974d9cf5e95cbef3aede1c1dd84cd; all38-table ordered row/catalog/effective-grant fingerprints match restored DB. Parser/OpenAPI validation is reported separately from actual DB execution. Current-head GitHub CI/commit/PR receipts are added to the owner package after publishing.

## Review and stop

Actual synthetic engine results are rendered as labeled review captures; two individual editable diagrams and a contact sheet are provided. No new product UI was added, so no desktop/mobile UI redesign screenshot is claimed. Source files/evidence are hash-manifested. Private photos/fonts/references/session tokens/env/dumps/Git objects are omitted from public review. See OPEN_DECISIONS.md. No B4, deployment, payments, notifications or Portfolio CMS.
