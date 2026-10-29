# Actual B1B logical backup and restore

pg_dump (PostgreSQL) 18.6 (Debian 18.6-1.pgdg12+2). Custom archive:102322 bytes; SHA256:d621e450fe4ef25339681c413b27cd95c2a8b7a10cf8ef86d2d4654a3bc658b4. Source:ms_b1b_dev; separate destination:ms_b1b_restore. Source untouched:true; rows/catalog equal:true.

Catalog/function/permission SHA256:1ed91cfcdaabab6fe8471cd7f7e919cd7b780e4df541db72bc8c34b3fa1b6fc3. Runtime IAM access denied and valid session verification retested after restore. Archive/env not exported. Role provisioning is external to pg_dump. This is not production PITR or operational disaster recovery certification.

| Table | Rows | Ordered lossless row hash |
| --- | ---: | --- |
| ms_b1_design.app_user | 6 | 3b6493b1e4811b87ea8dc39c9998bc0bcb13f9a709f8c0c2ef25f6e31c8e8232 |
| ms_b1_design.audit_log | 12 | 04830dd4f3a69ce68b026b401a521ea7bd3ba488de9b543cb41283a92872eb39 |
| ms_b1_design.auth_identity | 0 | 4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945 |
| ms_b1_design.auth_session | 10 | 5166736065153b3e1907655f5e648edcdc81adddd7bd9a7567b9de2677c971ec |
| ms_b1_design.branch | 4 | 286143711b8faaa3433b777f24a5687b8f21a6b50b52b5fa54174561d9a74c71 |
| ms_b1_design.branch_service_offering | 1 | de193b5e05c53a71b59771194e97e5d44109078cafbfddd9f668caf3a1d38e29 |
| ms_b1_design.business | 2 | 7d709b9651b96db3deb85d0f8d7ceb6f535fa7c2f95138295217464908b82358 |
| ms_b1_design.consumer_inbox | 0 | 4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945 |
| ms_b1_design.idempotency_record | 12 | e6f0a410313592d7f840b7bad194ab731eb4655b311ed0aaf601043be8eb5294 |
| ms_b1_design.offering_resource_requirement | 1 | 46491a6894525a9d04f181b49f43724b0f3fa28013cc278f91ae6b656cf376a3 |
| ms_b1_design.outbox_event | 12 | f4b60ff5cdedc03407314edfed43c528edfc7b7d0fcc482d1f21efb59a8b8d65 |
| ms_b1_design.permission | 7 | 2f6275aba1da24b8a4d513fd11830304ce3892f9913bbcf511a932af4ac98be1 |
| ms_b1_design.role | 7 | 67ec3109f6ca84121dd01036308abfecdf12c59c0662cc567756a65915c9f404 |
| ms_b1_design.role_permission | 28 | d72d8f2c4cc0902951abd46d47ee57344b688dbdf99a3181f223367845ea0a38 |
| ms_b1_design.service | 6 | 6822715def412c3cca9681d1d2f1151a74065abc2d2cc367490a3d9019a826f9 |
| ms_b1_design.user_role_assignment | 7 | 28933c0db323675c5c34416c8ca70ba8e101feb3d50fdcad0e24d71ed75d4a2e |
| ms_b1_meta.schema_migration | 3 | e2c31bdea5aa4cb7b00fcb06afbfee1ff25368129cf43f58d51e24c0bf1eedff |
