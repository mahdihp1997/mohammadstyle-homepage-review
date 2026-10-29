# Prisma7.10.1 / PostgreSQL18.6 — observed compatibility

The selected stable CLI/client/pg-adapter versions are pinned together. Prisma8 was an RC when inspected; no RC was selected. This is a dev-only compatibility experiment against ms_b0_full_test; the health runtime uses pg. No db push or migration command is invoked.

| Feature | Actual observation | Future persistence requirement |
| --- | --- | --- |
| Ordinary model | Generated BusinessProbe reads2 synthetic business rows via PrismaPg | Typed repositories behind reviewed module ports later |
| daterange/tstzrange | Introspection emits Unsupported fields; cast-to-text raw SQL succeeds | Keep native range columns and parameterized SQL projections |
| GiST exclusions | Full schema installs4; negative tests reject all4 predicates; introspector warns unsupported | Hand-reviewed native SQL, catalog/drift tests; never rely on PSL reconstruction |
| Deferrable FKs | Deferred child-before-parent commit and failing unresolved COMMIT exercised; introspection warns non-default deferring unsupported | Preserve native DEFERRABLE/INITIALLY DEFERRED behavior and runtime transaction tests |
| Generated stored columns | All5 installed; actual range/key values tested; scope_key introspects as optional dbgenerated default | Preserve GENERATED ALWAYS STORED in native SQL; dbgenerated default is not equivalent |
| Partial indexes | This exact release emits where: raw on both @@index and @@unique | Review predicates/NULLS NOT DISTINCT semantics and resulting SQL/catalog; do not use an outdated blanket unsupported claim |
| CHECK constraints |250 full-schema checks install; selected negatives exercised; introspection warns not fully supported | Native reviewed SQL remains authoritative |
| SERIALIZABLE / rollback | Interactive transaction SHOW reports serializable; deliberate rollback rejects as expected | Engine lock ordering/40001 retries/idempotency/atomic coverage remain future tests |

The probe compares actual constraints, indexes and generated expressions before/after introspection/read/transaction. No catalog mutation occurred. Generated client/full introspection are local ignored artifacts; the small probe model is explicitly not a replacement architecture schema or migration generator. Ordinary successful reads do not prove that Prisma can round-trip the full design.

Primary sources checked2026-10-29: [Prisma7 supported databases](https://www.prisma.io/docs/orm/v7/reference/supported-databases), [Prisma7 native SQL features and partial indexes](https://www.prisma.io/docs/orm/v7/prisma-migrate/workflows/unsupported-database-features), [PostgreSQL support](https://www.postgresql.org/support/versioning/), [official PostgreSQL image/18 volume layout](https://github.com/docker-library/docs/blob/master/postgres/README.md), [Nest12/Node/ESM guide](https://docs.nestjs.com/migration-guide). Runtime results take precedence over a documentation-only compatibility assumption.
