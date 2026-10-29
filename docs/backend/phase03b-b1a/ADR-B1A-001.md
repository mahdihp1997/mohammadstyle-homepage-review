# B1A persistence/security decision record

Implemented only under explicit B1-A authorization. Preserve approved B0/private frontend and stage B1 as16 domain tables, plus separate migration bookkeeping. Use a separate cluster/credentials/roles and explicit native SQL runner with immutable registry/checksum, transaction advisory lock, atomic history and catalog verification; no API startup migrations. Native SQL retains all approved FK/CHECK/unique/index/inactive-gate semantics.

Add RLS and limited technical repository permissions only on four future configuration read surfaces. This strengthens accidental tenant isolation but does not authenticate a caller or protect against compromised runtime credentials choosing another context. Keep API integration and business writes/production authentication disabled until B1-B review. A single small concrete reader/four typed ports and explicit transaction scope avoid empty future domain modules. A metadata-only CAS writer proves concurrency without inventing configuration commands.

Logical backup/restore is actually executed into a separate database. Compare effective rather than representational ACLs using acldefault/aclexplode; retain detection of real grant differences. Fail closed on drift/history/checksum/source/destination identity mismatch. No destructive auto-repair/down migration.

Existing B0 regression uses a separate tmpfs clone, with a strict explicit helper profile; default55432 behavior stays unchanged. Native Prisma probe routing now honors the validated local port. This permits all original tests without resetting the approved B0 databases. The regression72-table draft remains test-only, not a B1 migration.

Security, authorization, real business facts, production recovery/deployment and B1-B command development remain future approval gates. No deposit/refund policy or mixed-policy strategy is chosen.
