# Reviewed proposal → concrete isolated B4 contract

The03A OpenAPI file remains an architecture proposal and is preserved. B4 follows its ownership, immutable quote/consent, state, idempotency, capacity and financial boundaries, while using the existing B3 command convention for the isolated integration. This is an explicit wire-contract adaptation for review, not a claim that every proposed REST route or production public-discovery endpoint is enabled.

| Proposed operation | Concrete B4 operation |
|---|---|
| Public branch/service/barber discovery | Authenticated `read/catalog`, scoped to the session tenant; public discovery stays closed |
| `POST availability/search` | `commands/availability`; verified local session, bounded cursor, durable owned non-capacity plan references and idempotency |
| `POST booking-quotes` | `commands/quote`; optional-deposit/context choice is frozen into the selected plan and revalidated |
| `POST booking-drafts` | `commands/draft`; explicit persisted revisionless DRAFT |
| `POST booking-holds` | `commands/hold`; an explicit owned draft, version and exact quote/terms acceptance are required |
| `POST bookings` confirmation | `commands/confirm`; booking ID/version selects its active owned hold, never an arbitrary client hold object |
| `GET bookings` / one booking | Authenticated `read/history` / `read/booking`; finite pagination and full owned quote evidence |
| cancel / reschedule | `read/cancellation-preview`, `commands/cancel` / `commands/reschedule`; DB-clock evaluation and exact revision CAS |

All concrete operations use POST with CSRF/Origin, including local reads. Mutations use an exact decimal body version instead of the proposal's If-Match header; durable receipts bind the whole request. Opaque persisted plan UUIDs replace self-contained signed tokens; no digest or handle authorizes an actor without session/tenant/owner checks. Search creates only immutable short-lived plan artifacts and receipts, not a hold/allocation. This differs from the proposed side-effect-free public search and avoids introducing a public tenant/identity routing or signing-key service before approval.

The concrete JSON DTOs, exact allowlists and OpenAPI are provided with this phase. These changes affect only SERVER mode; DEMO types/guards and behavior are preserved. The production REST facade, customer.self enrollment/customer-profile linkage, stateless public search, final external wire shape and signing-key strategy require review before enabling production consumers. No payment, webhook, walk-in, attendance or CMS endpoint is claimed as implemented.
