# 09 — Proposed REST API contracts and frontend mapping

**Architecture only.** openapi.yaml is the normative machine-readable shape; each operation specifies auth/scope, request/response schemas, error codes, input rules, idempotency and concurrency via standard fields and x-* extensions. No API/server was implemented. The non-routable example.invalid server is deliberate. The chosen gateway and identity provider must receive reviewed concrete wire contracts before enabling them.

## Global rules

Strict DTO whitelists reject unknown properties. UUIDs are business-owned; server derives authenticated business/customer context, never trusts arbitrary body scope. Scope validation precedes reads and writes. Session mutations require CSRF and Origin checks plus durable Idempotency-Key; equal key/body replays result, different body409. Safe read-only availability POST has no side effects or idempotency requirement. Bounded pagination/cursors never bypass branch/resource filters. If-Match uses a quoted row version; missing/stale412. Errors have code/message/requestId/retryable and optional fieldErrors, no SQL/secrets. 409 handles occupancy/stale/context conflict,422 unconfigured/incompatible business rules,503 bounded retry for unavailable infrastructure. Return decimal strings for bigint money/version fields.

Operational rows need actor/time/scope auditing; accepted quote and policy artifacts are immutable. Occupancy mutations use the canonical lock hierarchy, database clock, bounded SERIALIZABLE retries and final GiST exclusion. Gateway work is outside locks. Authentication/OTP enrollment, actual gateway wire format and bot webhook schemas are provider-specific open decisions: the proposed normalized callback is explicitly disabled, not a production gateway contract. Security exception for signed provider ingress cannot authorize booking confirmation from its body.

## Endpoint inventory

69 paths /71 operations /82 schemas. Proposed only; no endpoint implementation.

| Method | Path | Request → response | Access |
| --- | --- | --- | --- |
| GET | /api/v1/session | — → SessionView | session.self |
| GET | /api/v1/branches | — → ListBranches | Public, rate-limited; approved public fields only |
| GET | /api/v1/branches/{branchId}/services | — → ListOfferings | Public, rate-limited; approved public fields only |
| GET | /api/v1/branches/{branchId}/barbers | — → ListBarbers | Public, rate-limited; approved public fields only |
| POST | /api/v1/availability/search | AvailabilitySearch → AvailabilityResult | Public, rate-limited; approved public fields only |
| POST | /api/v1/booking-quotes | QuoteRequest → Quote | customer.self |
| POST | /api/v1/booking-holds | HoldRequest → Hold | customer.self |
| POST | /api/v1/bookings | ConfirmBookingRequest → Booking | customer.self |
| GET | /api/v1/bookings | — → ListBookings | customer.self |
| GET | /api/v1/bookings/{bookingId} | — → Booking | customer.self |
| POST | /api/v1/bookings/{bookingId}/cancel | Reason → CancellationResult | customer.self |
| POST | /api/v1/bookings/{bookingId}/reschedule | RescheduleRequest → Booking | customer.self |
| POST | /api/v1/payment-intents | PaymentIntentRequest → PaymentIntent | customer.self |
| GET | /api/v1/payment-intents/{intentId} | — → PaymentIntent | customer.self |
| GET | /api/v1/refunds/{refundId} | — → Refund | customer.self |
| POST | /api/v1/providers/{providerKey}/payment-callbacks | GatewaySignal → Acknowledgement | Selected provider authentication + independent server verification; no customer auth; no customer data response |
| POST | /api/v1/me/notification-preferences | NotificationPreferenceWrite → RecordVersion | customer.self |
| POST | /api/v1/me/channel-links | ChannelLinkRequest → ChannelLinkChallenge | customer.self |
| POST | /api/v1/me/channel-links/{linkId}/revoke | Reason → RecordVersion | customer.self |
| POST | /api/v1/admin/branches | BranchWrite → Branch | branch.manage:business |
| PUT | /api/v1/admin/branches/{branchId} | BranchWrite → Branch | branch.manage:targetBranch |
| POST | /api/v1/admin/services | ServiceWrite → RecordVersion | catalog.manage:business |
| PUT | /api/v1/admin/services/{serviceId} | ServiceWrite → RecordVersion | catalog.manage:business |
| PUT | /api/v1/admin/branches/{branchId}/offerings/{offeringId} | OfferingWrite → RecordVersion | offering.manage:targetBranch |
| POST | /api/v1/admin/branches/{branchId}/offerings | OfferingWrite → RecordVersion | offering.manage:targetBranch |
| POST | /api/v1/admin/staff | StaffWrite → StaffView | staff.manage:business |
| GET | /api/v1/admin/staff | — → ListStaff | staff.read:assignedBranches |
| PUT | /api/v1/admin/staff/{staffId} | StaffWrite → StaffView | staff.manage:targetStaffBranches |
| POST | /api/v1/admin/staff/{staffId}/branch-assignments | StaffAssignmentWrite → RecordVersion | staff.manage:targetBranch |
| PUT | /api/v1/admin/staff/{staffId}/qualifications/{serviceId} | QualificationWrite → RecordVersion | staff.qualify:business |
| PUT | /api/v1/admin/branches/{branchId}/working-hours | BranchHoursWrite → RecordVersion | schedule.manage:targetBranch |
| PUT | /api/v1/admin/staff/{staffId}/schedule | ScheduleWrite → RecordVersion | schedule.manage:allAffectedBranches |
| POST | /api/v1/admin/staff/{staffId}/time-off | TimeBlockWrite → RecordVersion | schedule.manage:allAffectedBranches |
| POST | /api/v1/admin/branches/{branchId}/closures | TimeBlockWrite → RecordVersion | schedule.manage:targetBranch |
| POST | /api/v1/admin/branches/{branchId}/resources | ResourceWrite → RecordVersion | resource.manage:targetBranch |
| PUT | /api/v1/admin/branches/{branchId}/resources/{resourceId} | ResourceWrite → RecordVersion | resource.manage:targetBranch |
| POST | /api/v1/admin/policies | PolicyDefinitionWrite → RecordVersion | policy.manage:business |
| POST | /api/v1/admin/policies/{policyId}/versions | PolicyVersionWrite → RecordVersion | policy.manage:business |
| PUT | /api/v1/admin/policy-versions/{versionId} | PolicyVersionWrite → RecordVersion | policy.manage:business |
| POST | /api/v1/admin/policy-versions/{versionId}/publish | Reason → RecordVersion | policy.manage:business |
| POST | /api/v1/admin/policy-versions/{versionId}/retire | Reason → RecordVersion | policy.manage:business |
| POST | /api/v1/admin/policy-assignments | PolicyAssignmentWrite → RecordVersion | policy.manage:targetScope AND policy.override for override scopes |
| POST | /api/v1/admin/policy-assignments/{assignmentId}/revoke | Reason → RecordVersion | policy.manage:targetScope |
| GET | /api/v1/admin/bookings | — → ListBookings | booking.read:assignedBranch or assignedStaff; projection excludes unrelated contacts/finance |
| POST | /api/v1/admin/walk-ins | WalkInRequest → Booking | booking.walkin:targetBranch; explicit override permission if needed |
| POST | /api/v1/admin/bookings/{bookingId}/check-in | Reason → Booking | booking.attendance:targetBranch |
| POST | /api/v1/admin/bookings/{bookingId}/start | Reason → Booking | booking.service:assignedStaff or authorizedManager |
| POST | /api/v1/admin/bookings/{bookingId}/complete | Reason → Booking | booking.service:assignedStaff or authorizedManager |
| POST | /api/v1/admin/bookings/{bookingId}/no-show | Reason → Booking | booking.attendance:targetBranch |
| POST | /api/v1/admin/bookings/{bookingId}/cancel | Reason → CancellationResult | booking.cancel:targetBranch; incident override for IN_SERVICE |
| POST | /api/v1/admin/refunds | RefundRequest → Refund | finance.refund:targetBranch/business |
| GET | /api/v1/admin/customers | — → ListCustomers | customer.read:documented assigned relationship, not broad barber role |
| POST | /api/v1/admin/role-assignments | RoleGrantWrite → RecordVersion | iam.grant:businessOwner; cannot elevate beyond own grant authority |
| GET | /api/v1/admin/audit | — → ListAudit | audit.read:business/allowedBranch; redacted projection |
| POST | /api/v1/admin/media/upload-authorizations | UploadRequest → UploadAuthorization | media.manage:targetBranch |
| POST | /api/v1/admin/media/{assetId}/finalize | Reason → MediaAsset | media.manage:targetBranch |
| GET | /api/v1/admin/media | — → ListMedia | media.read:targetBranch |
| POST | /api/v1/admin/portfolio | PortfolioWrite → RecordVersion | media.manage:targetBranch |
| PUT | /api/v1/admin/portfolio/{itemId} | PortfolioWrite → RecordVersion | media.manage:targetBranch |
| POST | /api/v1/admin/portfolio/{itemId}/publish | Reason → RecordVersion | media.publish:targetBranch |
| POST | /api/v1/admin/portfolio/{itemId}/unpublish | Reason → RecordVersion | media.publish:targetBranch |
| POST | /api/v1/admin/media-consents | ConsentWrite → RecordVersion | privacy.consent.manage:verifiedSubject |
| POST | /api/v1/admin/media-consents/{consentId}/revoke | Reason → RecordVersion | privacy.consent.manage:verifiedSubject |
| POST | /api/v1/admin/portfolio-categories | TaxonomyWrite → RecordVersion | media.manage:business |
| POST | /api/v1/admin/portfolio-tags | TaxonomyWrite → RecordVersion | media.manage:business |
| POST | /api/v1/admin/notification-templates | TemplateWrite → RecordVersion | notification.configure:business |
| PUT | /api/v1/admin/branches/{branchId}/notification-configuration | NotificationConfigWrite → RecordVersion | notification.configure:targetBranch |
| GET | /api/v1/admin/notifications | — → ListNotifications | notification.read:targetBranch; minimal/redacted projection |
| POST | /api/v1/admin/notifications/{notificationId}/retry | Reason → NotificationStatus | notification.retry:targetBranch |
| POST | /api/v1/booking-drafts | CreateBookingDraft → UnplannedBooking | customer.self |
| POST | /api/v1/admin/staff/{staffId}/branch-assignments/{assignmentId}/end | EndStaffAssignment → RecordVersion | staff.manage:targetBranch and all affected scheduling/booking scopes |

## Existing frontend boundary — explicit integration proposal

| Current private contract | Future authoritative representation | Required reviewed integration |
| --- | --- | --- |
| BookingBranch (poonak/pending string aliases) | Branch UUID + stable code + timeZone/bookable | Resolve configured codes to IDs, retain aliases only at adapter boundary; two active branches does not mean configured bookability |
| ServiceId six-key union / BookingService | Service UUID + stable code; Offering per branch | Map six known codes without changing approved labels; dynamic future catalog requires explicitly widening the six-key union |
| BranchServiceOffering.priceToman/durationMinutes/bufferMinutes | Offering Money + duration/buffer-before/buffer-after + version/resource/staff rules | Checked integer conversion only; preserve unknowns, no demo defaults; split buffer concept explicitly rather than silently reinterpret |
| AvailabilityProvider.loadSlots(request,signal) → DemoTimeSlot[] | AvailabilitySearch → feasible BookingPlan[] | Keep cancellation/generation ownership; ID-only selection. Server recomputes plan on quote/hold/confirmation. Local requestKey is not a server capability |
| DemoTimeSlot.source literal demo and reducer demo guard | BookingPlan.source SERVER | **Explicit minimal breaking union/guard/adapter proposal required later.** Never cast server data as demo or weaken identity validation. Existing source remains unchanged now |
| ISO local date, HH:mm, timezone, Jalali calendar | Local date/time for display + finite UTC instants and IANA timezone | Preserve Jalali presentation; reject DST ambiguity/nonexistent times unless approved explicit offset resolution |
| BookingDraft selected services/provider/slot | Client editable draft + opaque plan/quote/hold/booking IDs and versions | Server is authoritative; reducer still rejects forged/stale client objects; stale409 resets dependent preview and requests re-consent |
| BookingPolicyVersion / preview snapshot | PolicyTerms immutable quote resolution and AcceptanceInput | Keep presentation; server owns scope resolution and artifact hashes, affirmative consent per quote/revision |
| Preview totals/optional deposit math | Quote total/deposit/remaining exact Money | Server quote wins; show accepted terms and explicit staleness. No automatic submit or claimed success from local preview |
| Final frontend preview | HELD/PENDING_PAYMENT/CONFIRMED with pending/refund state | A future approved integration must distinguish actual confirmed reservation from preview and paid-but-not-booked; no change in03A |

Whole-plan DTOs accommodate ordered per-item providers/resource assignments, but server enforces single-provider sequential MVP. Parallel/dependency planning is disabled pending business rules. Existing UI is preserved; it is not claimed that replacing a demo function alone makes real booking safe. Any source changes in03B require typecheck/build/Playwright and visual review. No tests were weakened.


## Hardened proposed contracts

Quote now carries hashVersion=MS_QUOTE_CONTENT_V2 and a64-character non-unique content digest. Exact internal artifact schema and excluded identity/TTL fields are in QUOTE_HASH_CONTRACT.md; caller ownership/idempotency are separate. POST booking-drafts and optional HoldRequest.bookingDraftId support an explicitly persisted revisionless draft. Booking DTO is a disjoint planCommitted=false UnplannedBooking / true PlannedBooking union; future consumers must not fabricate plan fields for drafts. Membership creation returns a new period ID; POST admin/staff/{staffId}/branch-assignments/{assignmentId}/end closes one exclusive-date period using If-Match, reason and affected-booking checks. Existing Frontend types/source remain unchanged; these are reviewed future integration proposals only. Mixed-service policy aggregation remains undecided and heterogeneous winners409.
