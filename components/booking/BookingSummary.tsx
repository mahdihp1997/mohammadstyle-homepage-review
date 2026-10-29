import { demoPolicies } from "@/data/booking-demo";
import { calculatePolicyPreview, calculateTotals, formatToman } from "@/lib/booking/calculations";
import { faNumber, formatJalali } from "@/lib/booking/date-utils";
import type { BookingCatalog, BookingDraft, BookingStep } from "@/types/booking";
import BookingPolicySummary from "./BookingPolicySummary";

export function BookingOverview({ draft, catalog, compact = false }: { draft: BookingDraft; catalog: BookingCatalog; compact?: boolean }) {
  const branch = catalog.branches.find(b => b.id === draft.branchId);
  const selected = catalog.services.filter(s => draft.serviceIds.includes(s.id));
  const totals = calculateTotals(selected);
  const barber = draft.barberId === "any" ? "بدون ترجیح آرایشگر (نمونه)" : catalog.barbers.find(b => b.id === draft.barberId)?.displayName;
  return <div className="booking-overview">
    <dl><div><dt>شعبه</dt><dd>{branch?.name ?? "هنوز انتخاب نشده"}</dd></div>
      {!compact && branch?.location && <div><dt>نشانی</dt><dd>{branch.location}</dd></div>}
      <div><dt>خدمات</dt><dd>{selected.length ? <ul className="booking-selected-services">{selected.map(s => <li key={s.id}>{s.name}</li>)}</ul> : "هنوز انتخاب نشده"}</dd></div>
      <div><dt>آرایشگر</dt><dd>{barber ?? "هنوز انتخاب نشده"}</dd></div>
      <div><dt>تاریخ</dt><dd>{draft.date ? formatJalali(draft.date, { month: "long", day: "numeric", year: "numeric" }) : "هنوز انتخاب نشده"}</dd></div>
      <div><dt>ساعت نمونه</dt><dd>{draft.slot ? <><bdi>{draft.slot.startTime}</bdi><small> · {draft.slot.timeZone === "Asia/Tehran" ? "به وقت تهران" : <bdi>{draft.slot.timeZone}</bdi>}</small></> : "هنوز انتخاب نشده"}</dd></div>
      <div><dt>جمع مدت</dt><dd data-testid={compact ? undefined : "booking-total-duration"}>{totals.durationMinutes === null ? "تأیید نشده" : `${faNumber(totals.durationMinutes)} دقیقه فرضی`}</dd></div>
      <div className="booking-overview-total"><dt>جمع مبلغ</dt><dd data-testid={compact ? undefined : "booking-total-price"}>{formatToman(totals.priceToman)}{totals.priceToman !== null && <small> · فرضی</small>}</dd></div>
    </dl>
    {!!selected.length && (totals.unknownPrices.length > 0 || totals.unknownDurations.length > 0) && <p className="booking-unknown-note">قیمت یا مدت تأییدنشده است؛ جمع کامل و زمان پایان قابل اعلام نیست.</p>}
  </div>;
}
export default function BookingSummary({ draft, catalog, onPolicy, onOptional, onEdit }: { draft: BookingDraft; catalog: BookingCatalog; onPolicy: (id: string | null) => void; onOptional: (value: boolean) => void; onEdit: (step: BookingStep) => void }) {
  const totals = calculateTotals(catalog.services.filter(s => draft.serviceIds.includes(s.id)));
  const policy = demoPolicies.find(p => p.id === draft.policyId) ?? null;
  const calculation = calculatePolicyPreview(policy, totals.priceToman, draft.optionalDeposit);
  return <div className="booking-final-summary">
    <div className="booking-card-heading"><h3>انتخاب‌های این پیش‌نمایش</h3><span className="booking-badge">رزرو ثبت نشده</span></div>
    <BookingOverview draft={draft} catalog={catalog} />
    <div className="booking-edit-links">{([1, 2, 3, 4] as const).map((step, i) => <button type="button" className="booking-text-button" onClick={() => onEdit(step)} key={step}>ویرایش {["شعبه", "خدمات", "آرایشگر", "زمان"][i]}</button>)}</div>
    <div className="booking-policy-picker"><label htmlFor="policy-scenario">سناریوی سیاست نمایشی</label><select id="policy-scenario" value={draft.policyId ?? ""} onChange={e => onPolicy(e.target.value || null)}><option value="">شرایط واقعی هنوز تأیید نشده</option>{demoPolicies.map(item => <option value={item.id} key={item.id}>{item.label}</option>)}</select>
      {policy?.deposit.requirement === "optional" && <label className="booking-switch"><input type="checkbox" checked={draft.optionalDeposit} onChange={e => onOptional(e.target.checked)} />فعال کردن بیعانه اختیاری در نمونه</label>}
    </div>
    <BookingPolicySummary policy={policy} calculation={calculation} />
    <p className="booking-demo-caption">با دکمه پایین فقط پیش‌نمایش را مرور می‌کنید؛ پرداخت، پذیرش قرارداد یا ثبت نوبت انجام نمی‌شود.</p>
  </div>;
}
