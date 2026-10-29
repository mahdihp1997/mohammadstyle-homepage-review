# Actual B2A backup / separate restore

pg_dump (PostgreSQL) 18.6 (Debian 18.6-1.pgdg12+2); custom archive163026 bytes; SHA256:848a16fb9db48e9af8309b2cb8449f1413c51a96df675fecd6f75c27033b60fb. Source:ms_b2a_dev; destination:ms_b2a_restore; source untouched:true; rows/catalog equal:true.

Application catalog SHA256:9347294bb877d0e1fcc395a7183390a95c48a9fea2ea40f7b3d7760e04b04f06.27 tables + tracking rows,2 generated expressions,2 exclusions,84 indexes,82 FKs,93 checks,9 functions,12 triggers,4 RLS policies and effective privileges/extension metadata compare. Restored exclusion/version/history behaviors are independently exercised. Archive creation alone is not counted as restore success. No dumps, cluster-role secrets or production PITR guarantee are exported.

| Table | Rows | Lossless ordered row hash |
| --- | ---: | --- |
| ms_b1_design.app_user | 1 | fb7751b241a89d07ee6d1cc5bce4b7b42ebc52826d38d0ba5cb71c8bc2f41a93 |
| ms_b1_design.audit_log | 1 | 8351956546e6d208ad3c9b4b545df7bd0073a35122879ea6c5a08e6a69790e91 |
| ms_b1_design.auth_identity | 0 | 4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945 |
| ms_b1_design.auth_session | 1 | 85a6c84943bb78e6975e896bc439f9c877f403474efb52f05bdfddc270fdd20b |
| ms_b1_design.availability_configuration | 1 | 2850ac3bbccffef753e3af49bb674067ffa69e4a3ddf7df887a1330efee69ec2 |
| ms_b1_design.branch | 4 | 164401dc30e5813d45c809ba34e7f64fbc9f9421d7adbae856546ad832db6e84 |
| ms_b1_design.branch_closure | 1 | fac9f8c0db3c49843082769fb266991c951a1d523c448997853b4d8e17d236ca |
| ms_b1_design.branch_service_offering | 1 | 7eba64effac72f138c2b2184fd93c39683917a5adb2cabfdd6f22a9f4efdfa79 |
| ms_b1_design.branch_working_hours | 2 | 4cfe7da7e8c2634f380f01487d590733bf0ac8b239dd7a134875f72088259606 |
| ms_b1_design.business | 2 | 601d9cf270c4e0a00cebd224a096584ec79a63f02b3e47e735316298a45ee3fd |
| ms_b1_design.consumer_inbox | 0 | 4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945 |
| ms_b1_design.idempotency_record | 1 | e530335ad85343a5d85a7e305f7d4178860d42365977d9b7e995da88cfefda55 |
| ms_b1_design.offering_resource_requirement | 0 | 4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945 |
| ms_b1_design.offering_staff_eligibility | 2 | 7dc59bf6b9a9677c815c856fc684a5a29cc825187d250f315adc40d922752aa2 |
| ms_b1_design.outbox_event | 1 | c8545558043632e2eac2ffd2c11109d004dedae0b63699f4cc30cd9db610e3ca |
| ms_b1_design.permission | 2 | 50bd43be075ea62ef80daabf5da6af9e6fb8b65d786c5167c76556dd44d93ef4 |
| ms_b1_design.resource | 9 | f152d1129d66eeab12a984bb0c8d44d5b99252c42c177a6a922fdbb1473783cc |
| ms_b1_design.role | 1 | 6c4673e0f549ecbbfaf489144f1d1cf1ea713fe0e0201aec4b66964df4f9a110 |
| ms_b1_design.role_permission | 2 | 7ba0255c03aca35ea595b1b5ec5c129c0aec7c9197d4258ed5477cd8b7c5e305 |
| ms_b1_design.service | 2 | b8346f00f6ec95d3ccaf9e744d7197f73a02dd14844c30b3e67fb2125692c291 |
| ms_b1_design.staff | 2 | 01cbcc4892a480393e3b25f74bd9868d1ae6e1f930f89aad77e2210dabb146bf |
| ms_b1_design.staff_branch_assignment | 5 | 6ecd263d2ee748575aee78a0db8a6932409e7808825d37db93c7e5b03c20bbef |
| ms_b1_design.staff_schedule_rule | 2 | 3b5a806c783bd3bdc6eab586770aa60aeff90cb10e3a617ee14518ea21dcfcdd |
| ms_b1_design.staff_service_eligibility | 2 | 704b9c08e8ea898f6186bcb87d8fb48d71665e4a2a8e57e26def34c2e313b140 |
| ms_b1_design.staff_shift | 7 | 1b7195c1b7792c6c5452b3b59be5aff0e6921e4b22861f69a0a895faef764e69 |
| ms_b1_design.staff_time_off | 1 | f6a93a0ac8a13039fea0d023b56c3179432dce7c2289b294d2440a36b9236577 |
| ms_b1_design.user_role_assignment | 1 | f51507856ab3355c776a2dca3cefcd6f6d75ddfc9655877eaa166f0541a99efc |
| ms_b1_meta.schema_migration | 5 | 46c26fd60397f6bd74a8dcfae051d26f46adb828bde58563a7d86ee621e63060 |
