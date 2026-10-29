# Phase03A hardening visual review

26 actual editable-source/SVG/PNG pairs,16 bounded-context ERDs and a contact sheet. No private photos/fonts/reference boards/screenshots or original task sources. Full ERD remains available.

Start with [local visual index](REVIEW.html), [overview](diagrams/rendered/overview.png), [module map](diagrams/rendered/backend-modules.svg), [payment/refund sequence](diagrams/rendered/payment-sequence.svg) and [complete ERD](diagrams/rendered/database-erd.svg). Exact module dependencies: [DAG](diagrams/rendered/backend-module-dependencies.svg). Payment primary source: [sequence JSON](diagrams/payment-sequence.sequence.json) and [editable SVG](diagrams/payment-sequence.source.svg).

| Bounded context | Owned tables | Individual files |
| --- | --- | --- |
| Business | 2 | [SVG](diagrams/rendered/context-business.svg) · [PNG](diagrams/rendered/context-business.png) · [DOT](diagrams/context-business.dot) |
| IAM | 7 | [SVG](diagrams/rendered/context-iam.svg) · [PNG](diagrams/rendered/context-iam.png) · [DOT](diagrams/context-iam.dot) |
| Scheduling | 7 | [SVG](diagrams/rendered/context-scheduling.svg) · [PNG](diagrams/rendered/context-scheduling.png) · [DOT](diagrams/context-scheduling.dot) |
| Catalog | 3 | [SVG](diagrams/rendered/context-catalog.svg) · [PNG](diagrams/rendered/context-catalog.png) · [DOT](diagrams/context-catalog.dot) |
| Offerings | 3 | [SVG](diagrams/rendered/context-offerings.svg) · [PNG](diagrams/rendered/context-offerings.png) · [DOT](diagrams/context-offerings.dot) |
| Staff | 3 | [SVG](diagrams/rendered/context-staff.svg) · [PNG](diagrams/rendered/context-staff.png) · [DOT](diagrams/context-staff.dot) |
| Customers | 1 | [SVG](diagrams/rendered/context-customers.svg) · [PNG](diagrams/rendered/context-customers.png) · [DOT](diagrams/context-customers.dot) |
| Availability | 1 | [SVG](diagrams/rendered/context-availability.svg) · [PNG](diagrams/rendered/context-availability.png) · [DOT](diagrams/context-availability.dot) |
| Policies | 7 | [SVG](diagrams/rendered/context-policies.svg) · [PNG](diagrams/rendered/context-policies.png) · [DOT](diagrams/context-policies.dot) |
| Pricing | 2 | [SVG](diagrams/rendered/context-pricing.svg) · [PNG](diagrams/rendered/context-pricing.png) · [DOT](diagrams/context-pricing.dot) |
| Booking | 8 | [SVG](diagrams/rendered/context-booking.svg) · [PNG](diagrams/rendered/context-booking.png) · [DOT](diagrams/context-booking.dot) |
| Payments | 7 | [SVG](diagrams/rendered/context-payments.svg) · [PNG](diagrams/rendered/context-payments.png) · [DOT](diagrams/context-payments.dot) |
| Infrastructure | 3 | [SVG](diagrams/rendered/context-infrastructure.svg) · [PNG](diagrams/rendered/context-infrastructure.png) · [DOT](diagrams/context-infrastructure.dot) |
| Media | 10 | [SVG](diagrams/rendered/context-media.svg) · [PNG](diagrams/rendered/context-media.png) · [DOT](diagrams/context-media.dot) |
| Notifications | 7 | [SVG](diagrams/rendered/context-notifications.svg) · [PNG](diagrams/rendered/context-notifications.png) · [DOT](diagrams/context-notifications.dot) |
| Audit | 1 | [SVG](diagrams/rendered/context-audit.svg) · [PNG](diagrams/rendered/context-audit.png) · [DOT](diagrams/context-audit.dot) |

[Booking flow](diagrams/rendered/booking-flow.svg), [policy resolution](diagrams/rendered/policy-resolution.svg), [multi-branch model](diagrams/rendered/multi-branch-model.svg), [state machine](diagrams/rendered/booking-state-machine.svg), [concurrency specification](diagrams/rendered/booking-concurrency.svg).

SVG retains detail; PNG files are independent individual images. Contexts omit common actor/business arrows and show key fields only; dictionary/full source retain every column and FK. No backend/migration/concurrency success claimed.
