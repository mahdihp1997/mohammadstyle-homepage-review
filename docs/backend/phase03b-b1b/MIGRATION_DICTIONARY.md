# B1B forward persistence inventory

0001_b1_foundation.sql and0002_b1a_runtime_boundary.sql: unchanged. New registry.b1b.json includes those checksums plus0003; original registry/catalog remain the B1A regression baseline. Install in order0001→0002→0003, never execute72-table target envelope as rollout. Manual local runner only; no down/auto-repair/startup migration.

| auth_session addition | Meaning / compatibility |
| --- | --- |
| business_id uuid nullable FK business.id | Session-fixed tenant; old null session is denied, never implicitly adopted |
| csrf_hash bytea nullable CHECK32 bytes | Hash of separate random synchronizer token; no plaintext persistence |
| idle_expires_at timestamptz nullable CHECKfinite, >created_at, <=expires_at | DB-clock idle deadline; old null denied |

No new domain table.16 existing tables and metadata schema remain. New API role is provisioned separately as LOGIN/NOSUPERUSER/NOCREATEDB/NOCREATEROLE/NOREPLICATION/NOBYPASSRLS with no memberships, CREATE/TEMP or table privileges. Exactly3 public-to-API functions: b1b_session, b1b_read, b1b_command. Four private helpers: b1b_actor, b1b_can, b1b_view, b1b_validate. PUBLIC receives no EXECUTE. All function definitions, owners, security flags, search_path and effective EXECUTE ACLs enter the B1B catalog fingerprint.

No new performance index: existing unique token_hash index supports authentication; assignment/role/branch FK/uniqueness indexes support current configuration access. business_id session FK has no deletion command or tenant-scan recovery workload in B1B; evaluate a child index when measured access/deletion patterns justify EXPLAIN evidence. Both B1 inactive CHECKs remain mandatory. Existing created_by indexes are not expanded automatically.
