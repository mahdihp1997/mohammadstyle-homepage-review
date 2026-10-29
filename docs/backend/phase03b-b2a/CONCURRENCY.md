# Actual two-session concurrency evidence

Both sessions connect to marked ms_b2a_dev as the isolated migration role; server pids differ. B waits while A holds the actual conflicting uncommitted row/index lock; pg_stat_activity observes wait_event_type=Lock before A commits. No in-memory barrier is substituted for a PostgreSQL conflict.

## same-branch membership race

{
  "name": "same-branch membership race",
  "pids": [
    4514,
    4515
  ],
  "observedWait": {
    "wait_event_type": "Lock",
    "wait_event": "transactionid"
  },
  "firstCommitted": true,
  "secondSqlstate": "23P01",
  "constraint": "no_overlapping_membership_period",
  "secondRows": 0
}

## cross-branch shift race

{
  "name": "cross-branch shift race",
  "pids": [
    4516,
    4517
  ],
  "observedWait": {
    "wait_event_type": "Lock",
    "wait_event": "transactionid"
  },
  "firstCommitted": true,
  "secondSqlstate": "23P01",
  "constraint": "no_cross_branch_staff_shift",
  "secondRows": 0
}

## optimistic resource CAS

{
  "name": "optimistic resource CAS",
  "pids": [
    4524,
    4526
  ],
  "observedWait": {
    "wait_event_type": "Lock",
    "wait_event": "transactionid"
  },
  "firstCommitted": true,
  "secondSqlstate": null,
  "constraint": null,
  "secondRows": 0
}

Migration concurrency is independently tested with two real clients: exactly one applies5 versions, the other applies0. These tests prove the tested persistence races, not end-to-end booking safety.
