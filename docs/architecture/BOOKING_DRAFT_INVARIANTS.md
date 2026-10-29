# Persisted draft and admitted-plan invariants

**PROPOSED / Phase03A architecture hardening only.** No backend, migration, database execution, payment or messaging implementation. Original Homepage/Booking/source/assets/tests are unchanged.

Persisted revisionless DRAFT is allowed for an actor-owned booking draft, including future explicit booking-scoped policy workflows. It reserves no slot/resources, has no accepted policy/payment and has a finite configured draft_expires_at. POST /api/v1/booking-drafts is a **proposed** contract only. The client-side Phase02 BookingDraft is unrelated local UI state and remains unchanged.

The draft SQL replaces status='DRAFT' OR active_revision_id IS NOT NULL with the following row-shape contract:

| plan_committed | revision | draft expiry | Allowed states |
| --- | --- | --- | --- |
| false | NULL | finite, later than created_at; retained after draft abort | DRAFT,CANCELLED,EXPIRED |
| true | required, same booking via deferred composite FK | NULL (hold has separate expiry) | HELD,PENDING_PAYMENT,CONFIRMED,CHECKED_IN,IN_SERVICE,COMPLETED,CANCELLED,NO_SHOW,EXPIRED |

plan_committed means a complete plan was admitted/accepted, **not payment or confirmation**. It changes false→true exactly once in hold acquisition and never resets, including cancellation/expiry/completion. Transition guards/content grants must enforce monotonicity; CHECK alone cannot inspect old values/history. Cancelled/expired admitted bookings retain revision/items/acceptance/history for audit; aborted unplanned drafts need no invented revision or fake quote.

## Atomic admission

Inside one canonical admission transaction create or lock a live actor-owned DRAFT, check its expiry/context, create revision/items/segments/acceptance/hold/allocations, then update status=HELD,plan_committed=true,active_revision_id=new revision,draft_expires_at=NULL in **one statement**. Do not first set a revision on DRAFT and violate the immediate CHECK. Root may be transient inside that transaction when no persisted draft ID was supplied. Deferred root→active revision FK permits the aggregate cycle. Any failure rolls the whole command back.

## Aborting drafts and retaining operational history

DRAFT→CANCELLED or EXPIRED atomically writes root/history/audit/outbox with plan_committed=false,revision=NULL and original draft expiry retained. No allocation-release or refund success is fabricated: none existed. The expiry sweep distinguishes unplanned DRAFT roots from ACTIVE booking_hold expiry. Admission/cancel/draft-expiry serialize on the root and recheck DB time/row version; if admission wins, abort logic cannot treat it as revisionless. Existing BookingStatusHistory edges still include both draft abort transitions. Held/planned cancellation/expiry keeps plan_committed=true and revision required. No transition resurrects a terminal booking.

The API Booking response is a disjoint UnplannedBooking/PlannedBooking union. Draft fields do not fabricate plan timestamps/quote IDs. A future adapter must discriminate planCommitted before accessing planned fields; no current frontend changes are made. Final-step server operational validation is unchanged. See V25–V26 and ADR015; no working backend transitions executed.
