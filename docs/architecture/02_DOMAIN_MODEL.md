# 02 — Bounded contexts and module contracts

**PROPOSED / REVIEW REQUIRED — Phase 03A specification only.** No backend, database, migration, gateway or notification service was installed or executed. The private Phase 02 frontend remains canonical and unchanged.

Dependency arrows mean consumer → provider port, not table foreign keys. Root composition supplies adapters; a physical FK to an opaque BookingId does not require Scheduling or Policies to import BookingModule. Workflows owns cross-context process managers. Booking does not import Payments/Notifications; payment events are handled by an outer workflow that calls both. No forwardRef escape hatch or bidirectional module import is allowed.

## Identity & Access

- Responsibilities, entities/value objects: Users, identities, sessions, roles/permissions and branch-scoped assignments; opaque SessionToken and ActorContext.
- Invariants/business rules: Deny by default; role does not imply other-branch or other-barber customer access.
- Dependencies: Kernel only; branch IDs are validated at the composition boundary.
- Public application interfaces: Authenticate, Authorize(actor,action,target), GrantRole.
- Events: SessionRevoked, RoleAssignmentChanged.
- Transaction boundary: Session/role mutation + audit/outbox, no booking writes.
- Delivery: MVP.

## Business & Branch

- Responsibilities, entities/value objects: Business, Branch and configuration identity; BranchId, TimeZone, configuration version. Resource identities/occupancy are owned by Scheduling.
- Invariants/business rules: A branch can be active yet unbookable; unknown data remains null; unit-capacity resources identified individually.
- Dependencies: Kernel.
- Public application interfaces: GetBranchContext, ConfigureBranch, RetireResource.
- Events: BranchConfigurationChanged, ResourceRetired.
- Transaction boundary: Lock branch/resources; reject occupied incompatible changes.
- Delivery: MVP.

## Staff Management

- Responsibilities, entities/value objects: Staff, memberships, qualifications; StaffId, validity interval.
- Invariants/business rules: One human/staff resource across branches; qualification is not a shift or free capacity.
- Dependencies: Business, IAM identity query and Catalog.
- Public application interfaces: GetQualifiedStaff, AssignBranch, VerifyCapability.
- Events: StaffAssignmentChanged, QualificationChanged.
- Transaction boundary: Staff/membership/qualification revision + audit; scheduling changes orchestrated outside.
- Delivery: MVP.

## Service Catalog

- Responsibilities, entities/value objects: Global service metadata, later Package/PackageService; ServiceCode and PackageComposition.
- Invariants/business rules: No global tariff/duration; keep the six confirmed service codes; no demo seed numbers.
- Dependencies: Kernel.
- Public application interfaces: GetServiceDefinitions, ManageCatalog, DefinePackage.
- Events: ServiceRetired, PackageChanged.
- Transaction boundary: Catalog aggregate + audit/outbox.
- Delivery: MVP; packages later.

## Branch Service Offerings

- Responsibilities, entities/value objects: Offering, offering-staff and resource requirements; Money, Duration, Buffers, ConfigVersion.
- Invariants/business rules: Active/bookable needs verified price/time/buffer/resources; all staff references match branch/service qualification.
- Dependencies: Business, Catalog, Staff.
- Public application interfaces: GetOfferings, ResolveEligibility, ConfigureOffering.
- Events: OfferingConfigurationChanged.
- Transaction boundary: Offering plus eligibility/resource rows + audit; branch/resource locks before activation.
- Delivery: MVP.

## Staff Scheduling

- Responsibilities, entities/value objects: Recurring hours/rules, published shifts, exceptions, unified resource occupancy ledger.
- Invariants/business rules: Global staff shifts cannot overlap; every hold/booking/block uses the same exclusion-protected resource identity.
- Dependencies: Business, Staff.
- Public application interfaces: ReadSchedule, ValidateWindow, ReserveResources, ReleaseResources, PublishShift.
- Events: SchedulePublished, TimeOffApproved, ResourceBlocked.
- Transaction boundary: Lock branch/resources; validate conflicts then publish/block atomically. Does not call Booking module.
- Delivery: MVP.

## Availability Engine

- Responsibilities, entities/value objects: Pure whole-plan search over read ports; PlanId, segments, fingerprint and expiry.
- Invariants/business rules: Eligibility plus schedules/exceptions/resources/buffers required; search never reserves.
- Dependencies: Business, Offerings, Scheduling, Staff.
- Public application interfaces: SearchPlans, RevalidatePlan.
- Events: No search event required; metrics only.
- Transaction boundary: Read snapshot; reservation belongs to Booking workflow.
- Delivery: MVP.

## Booking Policy Engine

- Responsibilities, entities/value objects: Definitions/versions/assignments, resolutions and acceptances; accepted snapshot/hash.
- Invariants/business rules: Deterministic precedence or explicit conflict; no retroactive accepted-content mutation.
- Dependencies: Business and Catalog; booking/quote context passed as values, no reverse module imports.
- Public application interfaces: ResolvePolicy, PublishVersion, AcceptTerms, CalculateRefundEntitlement.
- Events: PolicyPublished, PolicyAssignmentChanged, TermsAccepted.
- Transaction boundary: Publish assignment/conflict/audit in one transaction; accept frozen artifact in caller transaction.
- Delivery: MVP.

## Pricing & Quotations

- Responsibilities, entities/value objects: Quote/QuoteItem, immutable monetary/time snapshots; Money, QuoteHash and configuration fingerprint.
- Invariants/business rules: Integer money; no partial/unknown totals presented as authoritative; expiry and ownership checked.
- Dependencies: Offerings, Policies, Availability read port.
- Public application interfaces: CreateQuote, ValidateQuote, GetQuote.
- Events: QuoteIssued (optional), QuoteInvalidated.
- Transaction boundary: Immutable quote/items/resolution created with consistent read snapshot.
- Delivery: MVP.

## Customer Management

- Responsibilities, entities/value objects: Customer profile/contact consent boundary; CustomerId, encrypted Contact and lookup HMAC.
- Invariants/business rules: No invented customers; account identity distinct from branch-visible customer data; walk-in may be anonymous.
- Dependencies: IAM and Kernel.
- Public application interfaces: GetOwnProfile, ResolveAuthorizedCustomer, RedactProfile.
- Events: CustomerContactChanged, CustomerRedacted.
- Transaction boundary: Profile/consent/audit; retention decision before destructive redaction.
- Delivery: MVP minimal; CRM later.

## Booking Management

- Responsibilities, entities/value objects: Booking/Revision/Item/Segment/Hold/StatusHistory; BookingPlan and state machine.
- Invariants/business rules: One provider/sequential MVP; complete current plan and accepted quote; no resurrection after expiry.
- Dependencies: Customers, Availability, Pricing, Policies, Scheduling.
- Public application interfaces: AcquireHold, ConfirmBooking, Cancel, Reschedule, CheckIn, Complete.
- Events: BookingHeld, PaymentRequired, BookingConfirmed, BookingCancelled, BookingRescheduled, ServiceCompleted.
- Transaction boundary: One short transaction for aggregate, allocations, acceptance, history, idempotency and outbox.
- Delivery: MVP.

## Payments & Refunds

- Responsibilities, entities/value objects: Intent, verified receipt, application, locked balance, refund and ledger; Money and ProviderReceipt.
- Invariants/business rules: External verification/idempotency required; refund reserved+completed cannot exceed captured funds.
- Dependencies: Kernel and immutable quote/payment-requirement values supplied by Workflows; no Booking import.
- Public application interfaces: CreateIntent, VerifyCapture, ReserveRefund, RecordRefundResult, Reconcile.
- Events: PaymentCaptured, RefundCompleted, CompensationRequired.
- Transaction boundary: Receipt/balance/ledger/outbox atomic; gateway network work outside transaction.
- Delivery: Conditional paid MVP after merchant/legal approval.

## Portfolio & Media

- Responsibilities, entities/value objects: Asset/Variant, consent, portfolio/category/service/tag relations; ObjectKey and ContentHash.
- Invariants/business rules: Quarantine private by default; publication requires verified processing and every applicable consent.
- Dependencies: Business, Catalog, Staff, Customers.
- Public application interfaces: AuthorizeUpload, CompleteUpload, PublishPortfolio, RevokeConsent.
- Events: MediaValidated, PortfolioPublished, PublicationConsentRevoked.
- Transaction boundary: Metadata/consent/publication/audit transaction; idempotent storage processing outside.
- Delivery: Later content tranche.

## Notifications

- Responsibilities, entities/value objects: Templates, channel config/preference, delivery events/attempts and later bot links.
- Invariants/business rules: Transactional/marketing consent separated; no guessed bot identities; reminders recheck current revision.
- Dependencies: Customers, Booking read port, Kernel; no core module imports Notifications.
- Public application interfaces: ScheduleNotification, Deliver, LinkChannel, ReconcileDelivery.
- Events: NotificationDelivered, NotificationFailed.
- Transaction boundary: Outbox consumer dedup + event scheduling atomic; provider call after durable attempt.
- Delivery: MVP transactional channel; bots/marketing later.

## Audit Logging

- Responsibilities, entities/value objects: Append-only redacted audit and financial evidence references; RequestId/ActorId.
- Invariants/business rules: No credentials, PAN or full customer payload logging; evidence cannot be silently edited.
- Dependencies: Kernel; write port supplied by composition.
- Public application interfaces: AppendAudit, SearchAuthorizedAudit.
- Events: AuditRecorded (do not recursively audit its own publication).
- Transaction boundary: Append with the audited mutation transaction; controlled read/export.
- Delivery: MVP.

## Reporting

- Responsibilities, entities/value objects: Read-only branch/owner views and later projections; ReportRange and freshness watermark.
- Invariants/business rules: Owner cross-branch scope; staff restricted to own operational data; no invented metrics.
- Dependencies: Read ports/events from Booking, Payments, Staff and Customers.
- Public application interfaces: ReadBranchCalendar, ReadOwnerSummary, RebuildProjection.
- Events: ProjectionUpdated.
- Transaction boundary: Read-only snapshot or idempotent projection update/inbox; no command-side authority.
- Delivery: MVP operational reads; analytics later.

## Application Workflows / Infrastructure

- Responsibilities, entities/value objects: Composition/process managers, transaction/idempotency/outbox/inbox ports and adapters.
- Invariants/business rules: Only outer workflows commit; never hold DB locks across providers; at-least-once consumers idempotent.
- Dependencies: All contexts through public ports; nothing imports this orchestration layer from below.
- Public application interfaces: ConfirmPaidBooking, ExpireHold, ProcessReschedule, PublishOutbox.
- Events: WorkflowFailed, ReconciliationRequired.
- Transaction boundary: Coordinates shared DB transaction where local; durable saga/outbox across external boundaries.
- Delivery: MVP.

## Shared-kernel limits

Only typed IDs, integer Money, instants/local-date value types, domain error envelopes and transaction/clock/event/authorization port contracts belong in the shared kernel. Do not create a shared mutable Customer/Booking mega-model. Module repositories never query another module’s tables directly; authorized read ports or composition transactions do. Cross-module FKs provide relational integrity in the one database without creating runtime module cycles. Resource ledger ownership is Scheduling; Booking owns segment-to-ledger assignment and initiates reservation/release commands. Outbox/Audit are injected ports, not reverse dependencies into all features.
