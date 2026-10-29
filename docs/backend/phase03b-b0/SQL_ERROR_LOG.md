# Actual SQL errors and expected negative tests

Unexpected schema execution errors:0. No approved draft correction patch is needed. Initial host ECONNREFUSED is a transport failure with no SQLSTATE, not a PostgreSQL DDL error. Successful parser validation from03A is separate from these actual executions.

The following23 failures were intentionally provoked. Bind parameters are synthetic and omitted; exact SQL text is retained. No credential-bearing SQL is included.

## 1. 23503 — fk_branch_service_offering_2

```sql
INSERT INTO branch_service_offering(business_id,branch_id,service_id) VALUES($1,$2,$3)
```

Root cause: insert or update on table "branch_service_offering" violates foreign key constraint "fk_branch_service_offering_2". Proposed correction: No DDL correction: deliberately invalid synthetic input; supply valid tenant/configuration/state/range instead. Expected rejection: true.

## 2. 23505 — uq_branch_1

```sql
INSERT INTO branch(business_id,code,display_name,time_zone) VALUES($1,$2,$3,$4)
```

Root cause: duplicate key value violates unique constraint "uq_branch_1". Proposed correction: No DDL correction: deliberately invalid synthetic input; supply valid tenant/configuration/state/range instead. Expected rejection: true.

## 3. 23502 — column/transaction constraint

```sql
INSERT INTO branch(business_id,code,display_name) VALUES($1,$2,$3)
```

Root cause: null value in column "time_zone" of relation "branch" violates not-null constraint. Proposed correction: No DDL correction: deliberately invalid synthetic input; supply valid tenant/configuration/state/range instead. Expected rejection: true.

## 4. 23514 — ck_branch_service_offering_1

```sql
UPDATE branch_service_offering SET price_rial=-10 WHERE id=$1
```

Root cause: new row for relation "branch_service_offering" violates check constraint "ck_branch_service_offering_1". Proposed correction: No DDL correction: deliberately invalid synthetic input; supply valid tenant/configuration/state/range instead. Expected rejection: true.

## 5. 23514 — ck_branch_service_offering_2

```sql
UPDATE branch_service_offering SET duration_minutes=0 WHERE id=$1
```

Root cause: new row for relation "branch_service_offering" violates check constraint "ck_branch_service_offering_2". Proposed correction: No DDL correction: deliberately invalid synthetic input; supply valid tenant/configuration/state/range instead. Expected rejection: true.

## 6. 23503 — fk_auth_identity_1

```sql
COMMIT
```

Root cause: insert or update on table "auth_identity" violates foreign key constraint "fk_auth_identity_1". Proposed correction: No DDL correction: deliberately invalid synthetic input; supply valid tenant/configuration/state/range instead. Expected rejection: true.

## 7. 23514 — b1_branch_inactive

```sql
UPDATE branch SET active=true,bookable=true WHERE id=$1
```

Root cause: new row for relation "branch" violates check constraint "b1_branch_inactive". Proposed correction: No DDL correction: deliberately invalid synthetic input; supply valid tenant/configuration/state/range instead. Expected rejection: true.

## 8. 23514 — b1_branch_service_offering_inactive

```sql
UPDATE branch_service_offering SET active=true,price_rial=100,duration_minutes=30,buffer_before_minutes=0,buffer_after_minutes=0,resources_confirmed=true WHERE id=$1
```

Root cause: new row for relation "branch_service_offering" violates check constraint "b1_branch_service_offering_inactive". Proposed correction: No DDL correction: deliberately invalid synthetic input; supply valid tenant/configuration/state/range instead. Expected rejection: true.

## 9. 23503 — fk_branch_service_offering_2

```sql
INSERT INTO branch_service_offering(business_id,branch_id,service_id) VALUES($1,$2,$3)
```

Root cause: insert or update on table "branch_service_offering" violates foreign key constraint "fk_branch_service_offering_2". Proposed correction: No DDL correction: deliberately invalid synthetic input; supply valid tenant/configuration/state/range instead. Expected rejection: true.

## 10. 23505 — uq_branch_1

```sql
INSERT INTO branch(business_id,code,display_name,time_zone) VALUES($1,$2,$3,$4)
```

Root cause: duplicate key value violates unique constraint "uq_branch_1". Proposed correction: No DDL correction: deliberately invalid synthetic input; supply valid tenant/configuration/state/range instead. Expected rejection: true.

## 11. 23502 — column/transaction constraint

```sql
INSERT INTO branch(business_id,code,display_name) VALUES($1,$2,$3)
```

Root cause: null value in column "time_zone" of relation "branch" violates not-null constraint. Proposed correction: No DDL correction: deliberately invalid synthetic input; supply valid tenant/configuration/state/range instead. Expected rejection: true.

## 12. 23514 — ck_branch_service_offering_1

```sql
UPDATE branch_service_offering SET price_rial=-10 WHERE id=$1
```

Root cause: new row for relation "branch_service_offering" violates check constraint "ck_branch_service_offering_1". Proposed correction: No DDL correction: deliberately invalid synthetic input; supply valid tenant/configuration/state/range instead. Expected rejection: true.

## 13. 23514 — ck_branch_service_offering_2

```sql
UPDATE branch_service_offering SET duration_minutes=0 WHERE id=$1
```

Root cause: new row for relation "branch_service_offering" violates check constraint "ck_branch_service_offering_2". Proposed correction: No DDL correction: deliberately invalid synthetic input; supply valid tenant/configuration/state/range instead. Expected rejection: true.

## 14. 23503 — fk_auth_identity_1

```sql
COMMIT
```

Root cause: insert or update on table "auth_identity" violates foreign key constraint "fk_auth_identity_1". Proposed correction: No DDL correction: deliberately invalid synthetic input; supply valid tenant/configuration/state/range instead. Expected rejection: true.

## 15. 23514 — ck_branch_service_offering_6

```sql
UPDATE branch_service_offering SET active=true WHERE id=$1
```

Root cause: new row for relation "branch_service_offering" violates check constraint "ck_branch_service_offering_6". Proposed correction: No DDL correction: deliberately invalid synthetic input; supply valid tenant/configuration/state/range instead. Expected rejection: true.

## 16. 23P01 — no_overlapping_membership_period

```sql
INSERT INTO staff_branch_assignment(business_id,staff_id,branch_id,valid_from,valid_to) VALUES($1,$2,$3,$4,$5)
```

Root cause: conflicting key value violates exclusion constraint "no_overlapping_membership_period". Proposed correction: No DDL correction: deliberately invalid synthetic input; supply valid tenant/configuration/state/range instead. Expected rejection: true.

## 17. 23514 — ck_staff_branch_assignment_4

```sql
INSERT INTO staff_branch_assignment(business_id,staff_id,branch_id,valid_from,voided_at) VALUES($1,$2,$3,$4,now())
```

Root cause: new row for relation "staff_branch_assignment" violates check constraint "ck_staff_branch_assignment_4". Proposed correction: No DDL correction: deliberately invalid synthetic input; supply valid tenant/configuration/state/range instead. Expected rejection: true.

## 18. 23P01 — no_cross_branch_staff_shift

```sql
INSERT INTO staff_shift(business_id,staff_id,branch_id,assignment_id,starts_at,ends_at,published,schedule_version) VALUES($1,$2,$3,$4,$5,$6,true,1)
```

Root cause: conflicting key value violates exclusion constraint "no_cross_branch_staff_shift". Proposed correction: No DDL correction: deliberately invalid synthetic input; supply valid tenant/configuration/state/range instead. Expected rejection: true.

## 19. 23P01 — no_equal_rank_policy_assignment

```sql
INSERT INTO booking_policy_assignment(business_id,policy_version_id,scope_kind,effective_from,effective_to) VALUES($1,$2,'BUSINESS',$3,$4)
```

Root cause: conflicting key value violates exclusion constraint "no_equal_rank_policy_assignment". Proposed correction: No DDL correction: deliberately invalid synthetic input; supply valid tenant/configuration/state/range instead. Expected rejection: true.

## 20. 23514 — ck_booking_4

```sql
INSERT INTO booking(business_id,branch_id,origin,status,draft_expires_at) VALUES($1,$2,'STAFF','CONFIRMED','2040-01-01Z')
```

Root cause: new row for relation "booking" violates check constraint "ck_booking_4". Proposed correction: No DDL correction: deliberately invalid synthetic input; supply valid tenant/configuration/state/range instead. Expected rejection: true.

## 21. 23514 — ck_booking_5

```sql
INSERT INTO booking(business_id,branch_id,origin,draft_expires_at) VALUES($1,$2,'STAFF','infinity')
```

Root cause: new row for relation "booking" violates check constraint "ck_booking_5". Proposed correction: No DDL correction: deliberately invalid synthetic input; supply valid tenant/configuration/state/range instead. Expected rejection: true.

## 22. 23P01 — no_live_resource_overlap

```sql
INSERT INTO resource_allocation(business_id,resource_id,resource_kind,allocation_kind,busy_starts_at,busy_ends_at) VALUES($1,$2,'STAFF','MAINTENANCE',$3,$4)
```

Root cause: conflicting key value violates exclusion constraint "no_live_resource_overlap". Proposed correction: No DDL correction: deliberately invalid synthetic input; supply valid tenant/configuration/state/range instead. Expected rejection: true.

## 23. 23P01 — no_live_resource_overlap

```sql
INSERT INTO "resource_allocation" ("business_id","resource_id","resource_kind","allocation_kind","busy_starts_at","busy_ends_at") VALUES ($1,$2,$3,$4,$5,$6) RETURNING *
```

Root cause: Session A committed overlapping live interval. Proposed correction: No DDL correction; future engine must handle/retry conflicts. Expected rejection: true.
