import type {FinalQuote} from '@/types/booking-server';
import {faNumber} from '@/lib/booking/date-utils';
import {rialLabel} from '@/lib/booking/server-adapter';

/** Readable projection of every financial/cancellation field in the accepted artifact. */
export default function ServerFrozenTerms({quote}:{quote:FinalQuote}) {
  const t=quote.terms.terms;
  const percent=(bps:string)=>new Intl.NumberFormat('fa-IR',{maximumFractionDigits:2}).format(Number(bps)/100)+'٪';
  const instant=(value:string)=>new Intl.DateTimeFormat('fa-IR',{timeZone:quote.content.timeZone,dateStyle:'medium',timeStyle:'short'}).format(new Date(value));
  return <div className="booking-fixture-switch">
    <strong>نسخه {faNumber(Number(quote.content.policy.versionNumber))} شرایط</strong>
    <p className="server-terms-text" lang={t.termsLocale}>{t.termsText}</p>
    <dl className="server-quote-values">
      <div><dt>وضعیت بیعانه</dt><dd>{{NONE:'بدون بیعانه',OPTIONAL:'اختیاری',REQUIRED:'الزامی'}[t.depositRequirement]}</dd></div>
      {t.amountKind==='FIXED'&&t.fixedRial!==null&&<div><dt>مبلغ ثابت سیاست</dt><dd>{rialLabel(t.fixedRial)}</dd></div>}
      {t.amountKind==='PERCENTAGE'&&t.basisPoints!==null&&<div><dt>درصد بیعانه</dt><dd>{percent(t.basisPoints)}</dd></div>}
      {t.minimumRial!==null&&<div><dt>حداقل بیعانه</dt><dd>{rialLabel(t.minimumRial)}</dd></div>}
      {t.maximumRial!==null&&<div><dt>حداکثر بیعانه</dt><dd>{rialLabel(t.maximumRial)}</dd></div>}
      <div><dt>بازپرداخت</dt><dd>{({FULL:'کامل',NONE:'بدون بازپرداخت',PARTIAL:'بخشی از وجه',CONDITIONAL:'طبق بازه‌های زیر'} as Record<string,string>)[t.refundability]}</dd></div>
      <div><dt>مبنای بازپرداخت</dt><dd>{t.refundBase==='DEPOSIT_PAID'?'بیعانه پرداخت‌شده':'کل وجه پرداخت‌شده'}</dd></div>
      <div><dt>نرخ خارج از بازه‌ها</dt><dd>{percent(t.outsideRefundBps)}</dd></div>
      <div><dt>مهلت لغو پیش از شروع</dt><dd>{faNumber(Number(t.cancellationDeadlineMinutes))} دقیقه</dd></div>
    </dl>
    {!!t.refundWindows.length&&<ul>{t.refundWindows.map(w=><li key={w.thresholdMinutes}>از {faNumber(Number(w.thresholdMinutes))} دقیقه پیش از شروع: {percent(w.refundBps)} از مبنای پرداخت‌شده.</li>)}</ul>}
    <p>شروع اعتبار شرایط: {instant(t.effectiveFrom)}{t.effectiveTo?`؛ پایان اعتبار: ${instant(t.effectiveTo)}`:'؛ پایان اعتبار تعیین نشده است.'}</p>
    <p>وجهی در این محیط دریافت نشده است؛ هیچ بازپرداخت اجرایی انجام نمی‌شود.</p>
    <details><summary>شناسه‌های سند پذیرفته‌شده</summary><p><bdi className="server-hash">{quote.contentHash}</bdi></p><p><bdi className="server-hash">{quote.content.policy.snapshotHash}</bdi></p></details>
  </div>;
}
