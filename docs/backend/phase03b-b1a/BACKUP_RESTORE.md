# Actual backup / restore verification

Status:PASS. Source ms_b1a_dev was not overwritten. Destination ms_b1a_restore was actually restored from the custom archive, not copied by INSERT or inferred from a parser. Source/destination identities are validated before destructive commands. Archive is excluded from review/CI artifacts.

Archive:68292 bytes; SHA256:ebf04110cec0c85ac29459d4255659884368c79f2fb8bb44fa024580d0098406. Client:pg_dump (PostgreSQL) 18.6 (Debian 18.6-1.pgdg12+2). Catalog fingerprint:110267d147a6110bf77e3b79039eae55475212952a9fbf948825f9ec96797900. All16 domain tables plus tracking rows compare exactly. Effective grant normalization handles PostgreSQL default ACLs; runtime policy/permission negatives are independently retested.

| Table | Rows | Ordered row SHA256 |
| --- | ---: | --- |
| ms_b1_design.app_user | 1 | 11b270673b94d16f0ef8e5fd552a78378de34fa3157b49b0764043cee37d0bc8 |
| ms_b1_design.audit_log | 1 | eada5f98f70abbe28c167b3468c63f28167ebc2d67794f2c0f3a8e2f79923a85 |
| ms_b1_design.auth_identity | 1 | 4da1124f29be6b517ad55c73a4c50155eee21317b79672d17600038658f28b40 |
| ms_b1_design.auth_session | 1 | 73b7c5a57c2aafbf875caf32bc9c5fc33791e3156f68474b19dcd952789fe276 |
| ms_b1_design.branch | 2 | 7c29549a2c8ea5cabf004d42e338ec9dbc478b2b2589220d3294c12c3972d63b |
| ms_b1_design.branch_service_offering | 1 | 5c71993b8d4875e721f6dc0706b9c9c00f333d6ade0a7f492e7c54d484ec0741 |
| ms_b1_design.business | 2 | b7d83d684390ec33fa2c414c895fc421ec17c6c8f73b5b70a87925259ded6942 |
| ms_b1_design.consumer_inbox | 1 | fe229a02ff32b0c3ffddedb4482ea9e5b72dd8a68c2486ed943cbbf15fa68c86 |
| ms_b1_design.idempotency_record | 1 | bd1b6b533a6fb95838ef1484edc0ba5d40b48898b32e8b81f7e209a874e8c658 |
| ms_b1_design.offering_resource_requirement | 1 | 01c39b3eb1a20c8f856f3a49c879f2121241711e4e120bbb2dbfeb6916d06971 |
| ms_b1_design.outbox_event | 1 | 23c997e83310aaeffbe7bcc9acb9f44e9c760691ea5744e591c9dade517afe80 |
| ms_b1_design.permission | 1 | d4dd3686f3e0357e2820952cdeac8c347c5a0c6060b7e9f95485661958fa69dc |
| ms_b1_design.role | 1 | f8e99af95ed0ca788014a33730c0b1776fd300b8739d59ef7af98443c3e129b2 |
| ms_b1_design.role_permission | 1 | 1fcee8495454046214d96820be553a8b195212a5f8c1f42335e25961dc765846 |
| ms_b1_design.service | 2 | 3993685401be6e36cdda347d1876985e00c006316bf9951af2932d078c46eb21 |
| ms_b1_design.user_role_assignment | 1 | cbb709dbdf58502d93f58f0dd0f99d7089145e5e6df0df45f3c0554de49857c8 |
| ms_b1_meta.schema_migration | 2 | 2eebacfaa150d4edf64960ffde622d93dcac378ecfaa9a297fc5cb666a209086 |

Reproduce with npm run b1a:backup then npm run b1a:restore after synthetic integration setup. See RUNBOOK.md. Existing roles are required; pg_dump does not archive cluster roles. This is not a production PITR or operational recovery guarantee.
