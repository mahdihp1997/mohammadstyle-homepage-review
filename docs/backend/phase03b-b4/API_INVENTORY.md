# B4 API inventory

All13 operations are POST, return200 on success and require the existing session + exact Origin/CSRF. Commands additionally require Idempotency-Key. Tenant identity comes only from the verified session. Exact request schemas are in openapi.b4.json; booking versions are lossless decimal strings in the body.

- `/api/v1/booking/commands/availability`
- `/api/v1/booking/commands/quote`
- `/api/v1/booking/commands/draft`
- `/api/v1/booking/commands/hold`
- `/api/v1/booking/commands/reschedule`
- `/api/v1/booking/commands/confirm`
- `/api/v1/booking/commands/cancel`
- `/api/v1/booking/commands/configuration.enable`
- `/api/v1/booking/read/catalog`
- `/api/v1/booking/read/history`
- `/api/v1/booking/read/booking`
- `/api/v1/booking/read/events`
- `/api/v1/booking/read/cancellation-preview`

The Next proxy exposes only customer operations, never configuration.enable. Reads return owner-scoped catalog/history/status/events/cancellation preview; history uses finite25-row pages. No client time/price/resource calculations or arbitrary SQL operations enter final quote/admission. A final quote requires a current owned planId; a hold/reschedule binds quoteId + contentHash + snapshotHash + accepted=true. Confirmation with required/chosen deposits stays pending.
