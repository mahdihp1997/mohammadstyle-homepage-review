# 07 — Unified notification center

**PROPOSAL / ARCHITECTURE ONLY.** No implementation, real booking, payment, external message, database service or migration was executed.

## Responsibility and event contracts

Booking/payment transactions append versioned outbox events containing aggregate/revision IDs and minimal facts, not raw phone/chat IDs or entire customer objects. Consumers schedule NotificationEvent rows for BookingConfirmed/Changed/Cancelled, AppointmentReminder, PaymentConfirmed, RefundCompleted, ServiceCompleted and optional RebookingReminder. Event/revision/channel/template/purpose form a deterministic dedup key. Template versions are immutable; branch override falls back to a business template through an explicit, audited choice. A template version and bounded parameter snapshot are captured for each delivery.

Outbox insertion commits with business state. A publisher leases/locks eligible unpublished records briefly, enqueues a deterministic BullMQ job, then marks publication. A crash between enqueue and mark can duplicate a job; Inbox and event/attempt keys make processing idempotent. Redis/BullMQ is at-least-once transport, not the only copy of a notification or hold-expiry decision. Workers must tolerate retry without changing a completed result ([BullMQ idempotent jobs](https://docs.bullmq.io/patterns/idempotent-jobs)). Configure durable Redis persistence and bounded memory/no-eviction for queue data; cache can use a separate instance/policy. Rebuild recoverable work from PostgreSQL outbox/scheduled events after Redis loss.

## Channels and consent

SMS, Telegram Bot and Bale Bot implement one adapter port: send(eventId, deliveryKey, authorizedDestination, renderedTemplate) → submitted/providerRef/unknown; queryStatus(providerRef) where supported. No selected vendor, credentials or actual API integration is supplied. Configuration stores secret-manager references, never bot tokens. Branch/channel enabling and template changes require permission/audit.

NotificationPreference separates TRANSACTIONAL from MARKETING purpose, channel and consent text/version/time/revocation. Marketing/rebooking defaults off. Transactional message legal basis and opt-in exceptions need local review; the system must not assume every booking authorizes promotional messages. Read consent, destination validity, channel configuration and current booking revision again at delivery time. Cancellation/reschedule invalidates old reminders; dedup includes revision so a replacement reminder is distinct. Time calculations use branch timezone and resolved appointment instants, not a permanently hardcoded UTC offset.

Telegram/Bale linking is initiated by the authenticated user: create a high-entropy, hashed, expiring one-time challenge bound to customer/channel; user opens the official bot/start workflow; verify the selected provider's webhook protocol and challenge; atomically consume and bind the returned platform identity with explicit consent. Prevent linking an already-owned identity to another customer, replay, guessed chat IDs and reassignment without re-authentication. Store external IDs encrypted with lookup HMAC, revoke/unlink visibly. Provider-specific permitted linking rules must be checked against official docs during adapter implementation. No contacts are scraped or messages sent now.

## Delivery, retries and recovery

Persist an attempt before provider submission with a stable delivery operation key. Network calls occur after committing the attempt. Definitive temporary failure schedules bounded exponential backoff+jitter, permanent rejection marks failed and surfaces a redacted owner alert; ambiguous outcomes remain UNKNOWN and are reconciled before resending. Some channels cannot prove exactly-once external delivery; document duplicate risk rather than promise it. Delivery receipts update status only after authenticated provider validation.

Fallback to SMS is allowed only when the customer's preference/consent and channel policy permit that purpose. It uses a new channel attempt tied to the same logical event; never bypass a marketing opt-out or send concurrently just because a bot timed out. Quiet hours, reminder lead times, retry limits, message retention and provider rate limits are configuration/approval inputs, not guessed working hours. Queue job bodies hold IDs only. Dead-letter/reconciliation views, metrics and Inbox/outbox retention must support safe replay after a worker crash. No messaging endpoint was called in this phase.
