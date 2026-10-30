"use client";
export type Row = { id: string; [key: string]: unknown };
export type Page = {
  items: Row[];
  version?: string;
  limit?: number;
  offset?: number;
};
export const text = (value: unknown) =>
  value === null || value === undefined ? "" : String(value);
export const name = (row: Row) =>
  text(
    row.displayName ??
      row.display_name ??
      row.name ??
      row.title ??
      row.label ??
      row.code,
  );
export const statuses: Record<string, string> = {
  DRAFT: "پیش‌نویس",
  HELD: "نگه‌داری موقت",
  PENDING_PAYMENT: "در انتظار پرداخت",
  CONFIRMED: "تأییدشده",
  CANCELLED: "لغوشده",
  EXPIRED: "منقضی‌شده",
  READY: "خصوصی",
  PUBLISHED: "منتشرشده",
  ARCHIVED: "بایگانی",
  ACTIVE: "فعال",
  RETIRED: "بازنشسته",
  PENDING: "در انتظار بررسی",
  REQUESTED: "در انتظار بررسی",
  LEGACY_UNREVIEWED: "نیازمند بررسی سابقه",
  APPROVED: "تأیید",
  REJECTED: "رد شده",
};
export function money(value: unknown) {
  try {
    const v = text(value);
    if (!/^(0|[1-9][0-9]*)$/.test(v)) return "تأیید نشده";
    return new Intl.NumberFormat("fa-IR").format(BigInt(v)) + " ریال";
  } catch {
    return "تأیید نشده";
  }
}
export function dateTime(value: unknown, zone = "Asia/Tehran") {
  try {
    return new Intl.DateTimeFormat("fa-IR", {
      timeZone: zone,
      dateStyle: "medium",
      timeStyle: "short",
    }).format(new Date(text(value)));
  } catch {
    return "—";
  }
}
export function addDays(date: string, n: number) {
  const d = new Date(date + "T12:00:00Z");
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}
export function today(zone = "Asia/Tehran") {
  const p = new Intl.DateTimeFormat("en-CA", {
    timeZone: zone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());
  return ["year", "month", "day"]
    .map((k) => p.find((x) => x.type === k)!.value)
    .join("-");
}
export const minute = (value: unknown) => {
  const n = Number(value);
  return (
    String(Math.floor(n / 60)).padStart(2, "0") +
    ":" +
    String(n % 60).padStart(2, "0")
  );
};
export const toMinute = (s: unknown) => {
  if (!/^\d\d:\d\d$/.test(text(s))) throw Error("ساعت معتبر وارد کنید.");
  const [h, m] = text(s).split(":").map(Number);
  return h * 60 + m;
};
const messages: Record<string, string> = {
  UNAUTHENTICATED:
    "نشست معتبر لازم است. نشست آزمایشی را با ابزار محلی باز کنید.",
  FORBIDDEN: "مجوز این کار را در این شعبه ندارید.",
  STALE_VERSION: "داده تغییر کرده است؛ تازه‌سازی کنید و دوباره بررسی کنید.",
  STALE_CONFIGURATION: "پیکربندی تغییر کرده است؛ دادهٔ تازه را بررسی کنید.",
  STALE_CALENDAR_VERSION: "تقویم تغییر کرده است؛ تازه‌سازی کنید.",
  CONFLICT: "رکورد تکراری یا متداخل است؛ مقدارها را بررسی کنید.",
  RESOURCE_CONFLICT: "این ظرفیت دیگر آزاد نیست.",
  LIVE_RESERVATIONS_REQUIRE_REVIEW:
    "رزرو فعال وجود دارد؛ تغییر ظرفیت یا برنامه نیاز به بررسی و تعیین تکلیف رزروها دارد.",
  TIMEZONE_RECONCILIATION_REQUIRED:
    "منطقهٔ زمانیِ شعبهٔ دارای برنامه یا رزرو را نمی‌توان بدون بازبینی تغییر داد.",
  CALENDAR_RECONCILIATION_REQUIRED: "این تغییر به بازبینی تقویم نیاز دارد.",
  PUBLICATION_RIGHTS_REQUIRED:
    "ابتدا حق استفاده برای وب‌سایت را با مرجع معتبر تأیید کنید.",
  EXPLICIT_RIGHTS_REQUIRED: "تأیید صریح و مرجع حق استفاده لازم است.",
  MEDIA_TEXT_REQUIRED: "عنوان و متن جایگزین را پیش از انتشار تکمیل کنید.",
  UNSAFE_ZIP:
    "ZIP قابل واردکردن نیست؛ مسیرها، نوع فایل‌ها، تعداد و حجم را بررسی کنید.",
  INVALID_ZIP: "فایل ZIP معتبر نیست.",
  EMPTY_ZIP: "ZIP رسانهٔ قابل واردکردن ندارد.",
  UNSUPPORTED_MEDIA:
    "فقط JPEG، PNG، WebP و ویدئوی MP4/MOV/WebM پذیرفته می‌شود.",
  UPLOAD_SIZE: "هر فایل و ZIP حداکثر ۳۲ مگابایت است.",
  MEDIA_PROCESSING_FAILED:
    "پردازش رسانه موفق نبود؛ نوع فایل، حداکثر ۱۲۰ ثانیه و دسترسی به پردازشگر را بررسی کنید.",
  MEDIA_PROCESSOR_BUSY: "پردازش رسانهٔ دیگری در جریان است؛ دوباره تلاش کنید.",
  MEDIA_BATCH_TIMEOUT:
    "پردازش بسته بیش از دو دقیقه طول کشید؛ ZIP را به بسته‌های کوچک‌تر تقسیم کنید.",
  MEDIA_ARCHIVED: "رسانه بایگانی شده است.",
  VIDEO_LIMIT: "ویدئو باید حداکثر ۱۲۰ ثانیه و در محدودهٔ حجم و ابعاد باشد.",
  MEDIA_TEXT: "عنوان و توضیح جایگزین لازم است.",
  RATE_LIMITED: "درخواست‌ها زیاد بوده‌اند؛ کمی بعد دوباره تلاش کنید.",
  UNAVAILABLE: "ارتباط کامل نشد؛ برای تلاش دوباره همان فرم را ارسال کنید.",
  MVP_DISABLED: "محیط یکپارچه‌سازی فعال نیست.",
  CANCELLATION_REQUIRES_REVIEW:
    "طبق شرایط پذیرفته‌شده، این لغو به بررسی نیاز دارد.",
  POLICY_CONFLICT:
    "چند سیاست ناسازگار منطبق شده‌اند؛ محدوده و اولویت‌ها را اصلاح کنید.",
  INVALID_CONFIGURATION:
    "داده با قرارداد سرور سازگار نیست؛ مقدارها و وابستگی‌های لازم را بررسی کنید.",
  INVALID_FIELDS: "همهٔ فیلدهای لازم را به‌درستی تکمیل کنید.",
  INVALID_MONEY: "مبلغ صحیح ریالی، با گام ۱۰ ریال، وارد کنید.",
};
export class ApiError extends Error {
  constructor(
    readonly code: string,
    readonly status: number,
  ) {
    super(
      messages[code] ??
        "درخواست پذیرفته نشد (" +
          code +
          "). مقدارها و وابستگی‌ها را بررسی کنید.",
    );
  }
}
export async function api<T = Record<string, unknown>>(
  path: string,
  options: {
    method?: "GET" | "POST" | "PUT";
    data?: unknown;
    key?: string;
    version?: string;
    signal?: AbortSignal;
  } = {},
): Promise<T> {
  const method = options.method ?? "GET",
    csrf =
      document.cookie
        .split(";")
        .map((x) => x.trim())
        .find((x) => x.startsWith("ms_csrf="))
        ?.slice(8) ?? "";
  let r: Response;
  try {
    r = await fetch("/api/mvp/" + path, {
      method,
      credentials: "same-origin",
      cache: "no-store",
      signal: options.signal,
      headers: {
        ...(method !== "GET"
          ? { "content-type": "application/json", "x-csrf-token": csrf }
          : {}),
        ...(options.key ? { "idempotency-key": options.key } : {}),
        ...(options.version ? { "if-match": '"' + options.version + '"' } : {}),
      },
      body:
        options.data === undefined ? undefined : JSON.stringify(options.data),
    });
  } catch (e) {
    if ((e as Error).name === "AbortError") throw e;
    throw new ApiError("UNAVAILABLE", 503);
  }
  const data = await r.json();
  if (!r.ok) throw new ApiError(text(data.code) || "UNAVAILABLE", r.status);
  return data as T;
}
export const query = (params: Record<string, unknown>) => {
  const q = new URLSearchParams();
  for (const [k, v] of Object.entries(params))
    if (v !== null && v !== undefined && v !== "") q.set(k, text(v));
  return q.size ? "?" + q.toString() : "";
};
export const pageItems = (data: Page | undefined) =>
  Array.isArray(data?.items) ? data!.items : [];
