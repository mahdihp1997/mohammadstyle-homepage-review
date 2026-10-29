import { calculatePolicyPreview, formatToman } from "@/lib/booking/calculations";
import { faNumber, formatJalali, isLocalDate } from "@/lib/booking/date-utils";
import type { BookingPolicyVersion } from "@/types/booking";

const refundLabels = { full: "بازگشت کامل", none: "غیرقابل‌استرداد", partial: "بازگشت بخشی، بر اساس زمان لغو" } as const;
const requirementLabels = { none: "بدون بیعانه", optional: "بیعانه اختیاری", required: "بیعانه الزامی در این نمونه" } as const;
export default function BookingPolicySummary({ policy, calculation }: { policy: BookingPolicyVersion | null; calculation: ReturnType<typeof calculatePolicyPreview> }) {
  const effectiveDate = policy?.effectiveFrom.slice(0, 10);
  const scopeLabel = policy ? { branch: "شعبه نمونه", service: "خدمت نمونه", package: "بسته نمونه", booking: "همین پیش‌نمایش" }[policy.scope.kind] : "";
  return <section className="booking-policy" aria-labelledby="policy-heading"><div className="booking-card-heading"><h3 id="policy-heading">بیعانه و شرایط لغو</h3><span className="booking-badge">پیش‌نمایش سیاست</span></div>
    {!policy ? <><p>شرایط واقعی بیعانه، لغو و استرداد هنوز تأیید نشده‌اند.</p><dl><div><dt>بیعانه</dt><dd>تأیید نشده</dd></div><div><dt>باقی‌مانده</dt><dd>قابل محاسبه نیست</dd></div></dl></> : <>
      <p className="booking-demo-caption">فقط سناریوی فرضی رابط؛ این شرایط، سیاست سالن نیست و اجرا نمی‌شود.</p>
      <dl><div><dt>نوع بیعانه</dt><dd>{requirementLabels[policy.deposit.requirement]}</dd></div>
        {policy.deposit.requirement !== "none" && <div><dt>قاعده فرضی</dt><dd>{policy.deposit.amount.kind === "fixed" ? formatToman(policy.deposit.amount.amountToman) : `${faNumber(policy.deposit.amount.basisPoints / 100)}٪ مبلغ فرضی خدمات`}</dd></div>}
        <div><dt>بیعانه نمونه</dt><dd data-testid="policy-deposit">{calculation.deposit === null ? "قابل محاسبه نیست" : formatToman(calculation.deposit)}</dd></div>
        <div><dt>باقی‌مانده نمونه</dt><dd data-testid="policy-remaining">{calculation.remaining === null ? "قابل محاسبه نیست" : formatToman(calculation.remaining)}</dd></div>
        <div><dt>نوع بازگشت</dt><dd>{refundLabels[policy.cancellation.refundability]}</dd></div>
      </dl>
      {calculation.error && <p className="booking-inline-error" role="status">{calculation.error}</p>}
      {policy.cancellation.windows.length > 0 ? <ul>{policy.cancellation.windows.map(window => <li key={window.beforeStartMinutes}>لغو حداقل {faNumber(window.beforeStartMinutes / 60)} ساعت قبل: بازگشت {faNumber(window.refundBasisPoints / 100)}٪ بیعانه نمونه.</li>)}<li>خارج از بازه‌های بالا: بازگشت {faNumber(policy.cancellation.outsideWindowRefundBasisPoints / 100)}٪ بیعانه نمونه.</li></ul> : <p>در این نمونه، بازگشت بیعانه {faNumber(policy.cancellation.outsideWindowRefundBasisPoints / 100)}٪ است؛ پنجره زمانی جداگانه ندارد.</p>}
      <details><summary>درباره این سناریوی نمونه</summary><p>{policy.label} · نسخه {faNumber(policy.version)} · مربوط به {scopeLabel}</p><p>شروع اعتبار در سناریوی فرضی: {effectiveDate && isLocalDate(effectiveDate) ? formatJalali(effectiveDate, { year: "numeric", month: "long", day: "numeric" }) : "اعلام نشده"}. این تاریخ بیانگر اعتبار یک سیاست واقعی نیست.</p></details>
    </>}
  </section>;
}
