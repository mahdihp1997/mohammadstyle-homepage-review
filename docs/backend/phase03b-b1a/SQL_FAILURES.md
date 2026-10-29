# Actual failures and negative tests

The following are deliberate final-run rejections. PostgreSQL SQLSTATEs are separated from migration application guard codes. Failed development attempts are retained separately in evidence/; their resolutions are explained in TECHNICAL_REPORT.md.

## 1. 23503

SQLSTATE:23503.

```text
INSERT branch_service_offering with another tenant branch
```

Root cause:insert or update on table "branch_service_offering" violates foreign key constraint "fk_branch_service_offering_2". Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 2. 23505

SQLSTATE:23505.

```text
INSERT duplicate branch code
```

Root cause:duplicate key value violates unique constraint "uq_branch_1". Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 3. 23505

SQLSTATE:23505.

```text
INSERT duplicate active role assignment with NULL branch
```

Root cause:duplicate key value violates unique constraint "ix_user_role_assignment_integrity_0". Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 4. 23514

SQLSTATE:23514.

```text
UPDATE offering price_rial
```

Root cause:new row for relation "branch_service_offering" violates check constraint "ck_branch_service_offering_1". Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 5. 23514

SQLSTATE:23514.

```text
UPDATE offering duration_minutes
```

Root cause:new row for relation "branch_service_offering" violates check constraint "ck_branch_service_offering_2". Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 6. 23514

SQLSTATE:23514.

```text
UPDATE offering buffer_before_minutes
```

Root cause:new row for relation "branch_service_offering" violates check constraint "ck_branch_service_offering_3". Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 7. 23502

SQLSTATE:23502.

```text
INSERT branch without timezone
```

Root cause:null value in column "time_zone" of relation "branch" violates not-null constraint. Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 8. 23514

SQLSTATE:23514.

```text
UPDATE branch active=true,bookable=true
```

Root cause:new row for relation "branch" violates check constraint "b1_branch_inactive". Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 9. 23514

SQLSTATE:23514.

```text
UPDATE fully populated synthetic offering active=true
```

Root cause:new row for relation "branch_service_offering" violates check constraint "b1_branch_service_offering_inactive". Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 10. 42501

SQLSTATE:42501.

```text
CREATE TABLE ms_b1_design.denied(id int)
```

Root cause:permission denied for schema ms_b1_design. Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 11. 42501

SQLSTATE:42501.

```text
CREATE TABLE public.denied(id int)
```

Root cause:permission denied for schema public. Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 12. 42501

SQLSTATE:42501.

```text
SELECT * FROM ms_b1_meta.schema_migration
```

Root cause:permission denied for schema ms_b1_meta. Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 13. 42501

SQLSTATE:42501.

```text
SELECT * FROM ms_b1_design.auth_session
```

Root cause:permission denied for table auth_session. Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 14. 42501

SQLSTATE:42501.

```text
DELETE FROM ms_b1_design.audit_log
```

Root cause:permission denied for table audit_log. Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 15. 42501

SQLSTATE:42501.

```text
DELETE FROM ms_b1_design.service
```

Root cause:permission denied for table service. Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 16. 42501

SQLSTATE:42501.

```text
TRUNCATE ms_b1_design.service
```

Root cause:permission denied for table service. Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 17. 42501

SQLSTATE:42501.

```text
UPDATE ms_b1_design.service SET display_name='FORBIDDEN'
```

Root cause:permission denied for table service. Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 18. 42501

SQLSTATE:42501.

```text
UPDATE ms_b1_design.branch SET bookable=true
```

Root cause:permission denied for table branch. Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 19. 42501

SQLSTATE:42501.

```text
SET ROLE ms_b1a_migrator
```

Root cause:permission denied to set role "ms_b1a_migrator". Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 20. 42501

SQLSTATE:42501.

```text
ALTER TABLE ms_b1_design.branch DISABLE ROW LEVEL SECURITY
```

Root cause:must be owner of table branch. Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 21. 22012

SQLSTATE:22012.

```text
SELECT 1/0 after version write
```

Root cause:division by zero. Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 22. 42501

SQLSTATE:42501.

```text
SET LOCAL row_security=off;SELECT branch
```

Root cause:query would be affected by row-level security policy for table "branch". Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 23. B1A_DRIFT

SQLSTATE:not a PostgreSQL error; application guard.

```text
catalog verification after dropping gate
```

Root cause:B1A catalog drift detected; no automatic repair allowed. Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 24. B1A_DRIFT

SQLSTATE:not a PostgreSQL error; application guard.

```text
catalog verification after extra runtime grant
```

Root cause:B1A catalog drift detected; no automatic repair allowed. Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 25. B1A_DRIFT

SQLSTATE:not a PostgreSQL error; application guard.

```text
catalog verification after dropping FK-support index
```

Root cause:B1A catalog drift detected; no automatic repair allowed. Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 26. B1A_HISTORY

SQLSTATE:not a PostgreSQL error; application guard.

```text
BEGIN
```

Root cause:Unknown, missing or out-of-order migration history. Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 27. B1A_CHECKSUM

SQLSTATE:not a PostgreSQL error; application guard.

```text
BEGIN
```

Root cause:Applied migration checksum differs from reviewed source. Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 28. 22012

SQLSTATE:22012.

```text
SELECT 1/0;
```

Root cause:division by zero. Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 29. B1A_UNTRACKED_SCHEMA

SQLSTATE:not a PostgreSQL error; application guard.

```text
BEGIN
```

Root cause:Untracked application schema; refuse implicit adoption. Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.

## 30. 42501

SQLSTATE:42501.

```text
restored runtime SELECT migration metadata
```

Root cause:permission denied for schema ms_b1_meta. Correction:Expected negative fixture: reject invalid input/state or unauthorized operation; no automatic schema/permission repair.
