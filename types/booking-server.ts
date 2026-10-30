import type { LocalDate } from './booking';
export interface ServerBranch {
    id: string;
    name: string;
    timeZone: string;
    configured: boolean;
    version: string;
    today: LocalDate;
    horizonDays: number;
}
export interface ServerOffering {
    id: string;
    branchId: string;
    serviceId: string;
    name: string;
    priceRial: string;
    durationMinutes: string;
    version: string;
}
export interface ServerStaff {
    id: string;
    name: string;
    offeringIds: string[];
}
export interface ServerCatalog {
    source: 'SERVER';
    isolated: true;
    branches: ServerBranch[];
    offerings: ServerOffering[];
    staff: ServerStaff[];
}
export interface ServerSlot {
    id: string;
    startsAt: string;
    endsAt: string;
    staffId: string;
    timeZone: string;
    expiresAt: string;
}
export interface AvailabilityResult {
    source: 'SERVER';
    slots: ServerSlot[];
    requestKey: string;
    date: LocalDate;
    timeZone: string;
    nextCursor: string | null;
}
export interface FinalQuote {
    id: string;
    contentHash: string;
    expiresAt: string;
    capacityReserved?: false;
    content: {
        schema: 'MS_QUOTE_CONTENT_V2';
        branchId: string;
        timeZone: string;
        startsAt: string;
        endsAt: string;
        totalRial: string;
        depositRial: string;
        remainingRial: string;
        optionalDepositChosen: boolean;
        items: {
            position: string;
            displayName: string;
            offeringId: string;
            durationMinutes: string;
            unitPriceRial: string;
            bufferBeforeMinutes: string;
            bufferAfterMinutes: string;
        }[];
        segments: {
            staffId: string;
        }[];
        policy: {
            snapshotHash: string;
            versionId: string;
            versionNumber: string;
        };
    };
    terms: {
        terms: {
            termsText: string;
            depositRequirement: 'NONE' | 'OPTIONAL' | 'REQUIRED';
            refundability: string;
            cancellationDeadlineMinutes: string;
            amountKind: 'FIXED' | 'PERCENTAGE' | null;
            fixedRial: string | null;
            basisPoints: string | null;
            minimumRial: string | null;
            maximumRial: string | null;
            refundBase: 'DEPOSIT_PAID' | 'ALL_PAID';
            outsideRefundBps: string;
            refundWindows: {thresholdMinutes:string;refundBps:string}[];
            effectiveFrom: string;
            effectiveTo: string | null;
            termsLocale: string;
        };
        resolution: unknown[];
    };
}
export interface ServerBooking {
    id: string;
    branchId: string;
    status: 'DRAFT' | 'HELD' | 'PENDING_PAYMENT' | 'CONFIRMED' | 'CANCELLED' | 'EXPIRED';
    version: string;
    revisionId: string | null;
    quote: FinalQuote | null;
    holdExpiresAt: string | null;
    moneyExecuted: false;
}
export interface CancellationPreview {
    bookingId: string;
    version: string;
    cancellationAllowed: boolean;
    deadline: string | null;
    paidRial: string;
    refundPreviewRial: string;
    moneyExecuted: false;
}
