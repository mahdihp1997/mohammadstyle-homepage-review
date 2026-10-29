# Actual production-boundary concurrency evidence

8 races use distinct real PostgreSQL pids, explicit transactions and the EXECUTE-only API role. A trusted harness monitor reads pg_stat_activity only to observe waits. The harness holds transaction A after executing a production command, starts B, confirms a lock wait, commits A, then checks B's result. This does not mock the production command or use a JavaScript-only lock.

Canonical order: verified actor user/session and permission evidence -> business advisory gate -> all business branches sorted UUID -> all global/physical resource rows sorted UUID -> workforce revision -> affected membership/exception rows. No lock set expansion or external calls while held. All writes use the same gate; the legacy configuration wrapper coordinates too.

A different mutation with the same If-Match cannot commit after the winner;412 requires explicit reload. After reload, domain conflicts still reject. Same actor/route/key/body replays the committed receipt; same key/different body409. Native no_cross_branch_staff_shift is the independent exclusion backstop exercised by preserved B2A races. Application-level cross-branch races here intentionally fail before relying on that backstop.

READ COMMITTED statement transactions plus a complete shared gate are intentional. Whole-statement retries are bounded to two proven40001/40P01 aborts; ambiguous network outcomes are not blindly retried. No external side effect exists.

```json
[
  {
    "name": "publication vs publication",
    "pids": [
      8516,
      8517
    ],
    "wait": {
      "wait_event_type": "Lock",
      "wait_event": "advisory"
    },
    "loserSqlstate": "MS412"
  },
  {
    "name": "close vs publication",
    "pids": [
      8518,
      8519
    ],
    "wait": {
      "wait_event_type": "Lock",
      "wait_event": "advisory"
    },
    "loserSqlstate": "MS412"
  },
  {
    "name": "timeoff vs publication",
    "pids": [
      8520,
      8521
    ],
    "wait": {
      "wait_event_type": "Lock",
      "wait_event": "advisory"
    },
    "loserSqlstate": "MS412"
  },
  {
    "name": "closure vs publication",
    "pids": [
      8522,
      8523
    ],
    "wait": {
      "wait_event_type": "Lock",
      "wait_event": "advisory"
    },
    "loserSqlstate": "MS412"
  },
  {
    "name": "qualification vs publication",
    "pids": [
      8532,
      8533
    ],
    "wait": {
      "wait_event_type": "Lock",
      "wait_event": "advisory"
    },
    "loserSqlstate": "MS412"
  },
  {
    "name": "stale resource writers",
    "pids": [
      8534,
      8535
    ],
    "wait": {
      "wait_event_type": "Lock",
      "wait_event": "advisory"
    },
    "loserSqlstate": "MS412"
  },
  {
    "name": "duplicate idempotency",
    "pids": [
      8536,
      8537
    ],
    "wait": {
      "wait_event_type": "Lock",
      "wait_event": "transactionid"
    },
    "loserSqlstate": null
  },
  {
    "name": "cross-branch publication",
    "pids": [
      8538,
      8539
    ],
    "wait": {
      "wait_event_type": "Lock",
      "wait_event": "advisory"
    },
    "loserSqlstate": "MS412"
  }
]
```
