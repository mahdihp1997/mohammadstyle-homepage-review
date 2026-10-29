# B2A security review

No broad runtime grants, public/staff management API or authentication bypass added. Existing session/permission application code and0003 definer entry points are byte-preserved. New table privileges remain migration-owner only; both existing runtime/API roles fail read/delete attempts on all11 tables, and private trigger functions cannot be invoked directly. Existing3 API EXECUTE grants are unchanged. Tenant-safe composite FKs bind staff/resource/branch/service/qualification/stint; original RLS remains defense in depth rather than authentication.

| Severity | Finding / disposition |
| --- | --- |
| Fixed correctness defect | BEFORE UPDATE generated range comparison blocked legitimate archive; found in real tests, fixed by excluding generated outputs only; input immutability and direct-forgery rejection retested |
| Medium future gate | Cross-row temporal/active/exception/travel/publication invariants intentionally absent; no B2B/public availability API is enabled |
| Medium production gate | Migration credential owns tables/triggers; custody/rotation and audited B2B writes must be reviewed. Version guards are not authorization |
| Medium production gate | IdP/MFA/HTTPS/recovery/rate distribution/retention remain unresolved B1B decisions |
| Scope limit | Exclusion of overlapping shifts is not exclusion of overlapping customer bookings or all resource allocations |

No critical/high unresolved issue was observed in scoped native/runtime abuse tests. This is not a production security certification. Native DDL/global exclusion/history constraints cannot identify two unlinked profiles as one real person; future identity adjudication is required. Test-only session secrets remain in memory and are not exported.

Primary references checked: [PostgreSQL18 ranges](https://www.postgresql.org/docs/18/rangetypes.html), [btree_gist](https://www.postgresql.org/docs/18/btree-gist.html), [generated columns](https://www.postgresql.org/docs/18/ddl-generated-columns.html).
