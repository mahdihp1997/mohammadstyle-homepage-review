# Actual migration and restore

0009_b2b_read_scope_hardening.sql adds no tables/columns/indexes and does not rewrite application rows. It replaces the current read wrapper and legacy projection, and adds a private interval helper/private core/explicit history wrapper. New functions are installed atomically with registry recording. Old8 checksums/source remain exact; nine-version registry and actual catalog snapshot are included.

Actual catalog: {"status":"PASS","sha256":"94804847f5fd4ff7ea7cfa359b3246510874e1e6037ee6f88af14d8d75e96dd4","tables":28,"indexes":89,"functions":21,"foreignKeys":88,"checks":101,"exclusions":2,"apiEntryPoints":6,"publicExecute":false,"apiHasOwnerRole":false}. Parser acceptance is separate static validation. Actual fresh9, upgrade8->9, no-op, drift detection and failed forward DDL/history rollback pass.

Actual pg_dump custom230347bytes SHA2563c6ace94de746a63ec7e9f696153e9fbfe380735622f7f63c5988b8ea0d74c61; pg_restore into separatems_b2h_restore, sourcems_b2h_dev unchanged at restore verification, all28-table lossless ordered row/catalog/effective-ACL fingerprints equal. Restored API negatives/current/history semantics pass. Dump/auth secrets remain ignored and excluded.
