import type { AvailabilityResult, FinalQuote, ServerCatalog, ServerBooking, CancellationPreview } from '@/types/booking-server';
export class BookingApiError extends Error {
    constructor(readonly code: string, readonly status: number) { super(code); }
}
async function request<T>(path: string, data: unknown, key?: string, signal?: AbortSignal): Promise<T> {
    const csrf = document.cookie.split(';').map(x => x.trim()).find(x => x.startsWith('ms_csrf='))?.slice(8) ?? '';
    const r = await fetch('/api/booking-server/' + path, { method: 'POST', credentials: 'same-origin', cache: 'no-store', signal, headers: { 'content-type': 'application/json', 'x-csrf-token': csrf, ...(key ? { 'idempotency-key': key } : {}) }, body: JSON.stringify(data) });
    const result = await r.json() as T & {
        code?: string;
    };
    if (!r.ok)
        throw new BookingApiError(result.code ?? 'UNAVAILABLE', r.status);
    return result;
}
export const serverBooking = {
    catalog: (signal?: AbortSignal) => request<ServerCatalog>('read/catalog', { entityId: null, pageOffset: 0 }, undefined, signal),
    availability: (data: unknown, signal?: AbortSignal) => request<AvailabilityResult>('commands/availability', data, crypto.randomUUID(), signal),
    quote: (id: string, signal?: AbortSignal) => request<FinalQuote>('commands/quote', { planId: id }, crypto.randomUUID(), signal),
    command: (op: string, data: unknown, key: string) => request<ServerBooking>('commands/' + op, data, key),
    history: () => request<{
        items: ServerBooking[];
    }>('read/history', { entityId: null, pageOffset: 0 }),
    booking: (id: string) => request<ServerBooking>('read/booking', { entityId: id, pageOffset: 0 }),
    cancellation: (id: string) => request<CancellationPreview>('read/cancellation-preview', { entityId: id, pageOffset: 0 }),
};
export function bookingError(error: unknown): string {
    const code = error instanceof BookingApiError ? error.code : '';
    if (['UNAUTHENTICATED', 'VERIFIED_IDENTITY_REQUIRED', 'FORBIDDEN'].includes(code))
        return 'نشست آزمایشی تأییدشده لازم است. نشست را با ابزار محلی B4 آماده کنید و دوباره تلاش کنید.';
    if (['PLAN_STALE', 'PLAN_EXPIRED', 'QUOTE_STALE', 'QUOTE_EXPIRED', 'RESOURCE_CONFLICT', 'STALE_BOOKING', 'HOLD_EXPIRED'].includes(code))
        return 'این انتخاب دیگر معتبر نیست. وضعیت رزرو و زمان‌های موجود را دوباره بارگذاری کنید و شرایط تازه را بپذیرید.';
    if (code === 'POLICY_CONFLICT')
        return 'شرایط خدمات انتخاب‌شده با هم سازگار نیستند؛ ثبت تا بررسی مسئول مجموعه بسته است.';
    if (['BOOKING_UNCONFIGURED', 'RESOURCES_UNCONFIGURED', 'OFFERING_UNCONFIGURED', 'POLICY_REQUIRED'].includes(code))
        return 'اطلاعات لازم برای رزرو کامل نیست. تا تأیید پیکربندی، نوبتی ثبت نمی‌شود.';
    if (code === 'RESCHEDULE_REQUIRES_REVIEW')
        return 'این جابه‌جایی به بررسی شرایط و مبالغ نیاز دارد و در این مرحله مجاز نیست.';
    if (code === 'RATE_LIMITED')
        return 'تعداد درخواست‌ها زیاد است. یک دقیقه بعد دوباره تلاش کنید.';
    return 'درخواست کامل نشد. برای جلوگیری از ثبت تکراری، تلاش دوباره با همان شناسه انجام می‌شود. وضعیت رزرو را هم بررسی کنید.';
}
export function rialLabel(value: string): string { return new Intl.NumberFormat('fa-IR').format(BigInt(value)) + ' ریال'; }
