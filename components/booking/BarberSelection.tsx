import Icon from "@/components/Icon";
import type { BookingBarber } from "@/types/booking";
import { faNumber } from "@/lib/booking/date-utils";

export function BarberProfile({ barber, selected, onSelect }: { barber: BookingBarber; selected: boolean; onSelect: (id: string) => void }) {
  return <label className={`booking-barber-card ${selected ? "is-selected" : ""}`}>
    <div className="booking-avatar" aria-hidden="true"><Icon name="scissors" size={28} /></div>
    <div><div className="booking-choice-title"><h3>{barber.displayName}</h3><input type="radio" name="booking-barber" value={barber.id} checked={selected} onChange={() => onSelect(barber.id)} /></div><p>پروفایل فرضی برای آزمون رابط</p><small>{faNumber(barber.branchIds.length)} تخصیص شعبه در داده نمونه · بدون امتیاز یا سابقه واقعی</small></div>
  </label>;
}
export default function BarberSelection({ eligible, selected, onSelect, error }: { eligible: BookingBarber[]; selected: string | null; onSelect: (id: string) => void; error: string | null }) {
  return <fieldset className="booking-fieldset" aria-describedby={error ? "booking-error" : "barber-hint"}><legend className="sr-only">انتخاب آرایشگر نمایشی</legend>
    <p className="booking-intro" id="barber-hint">فقط پروفایل‌های فرضی سازگار با شعبه و تمام خدمات انتخابی نمایش داده می‌شوند. فهرست واقعی کارکنان هنوز تأیید نشده است.</p>
    {eligible.length ? <div className="booking-barber-list">
      <label className={`booking-any-barber ${selected === "any" ? "is-selected" : ""}`}><span className="booking-avatar" aria-hidden="true"><Icon name="sparkle" size={26} /></span><div><div className="booking-choice-title"><strong>بدون ترجیح آرایشگر</strong><input type="radio" name="booking-barber" value="any" checked={selected === "any"} onChange={() => onSelect("any")} /></div><p>هر آرایشگر واجد شرایط در داده‌های نمایشی</p></div></label>
      {eligible.map(barber => <BarberProfile key={barber.id} barber={barber} selected={barber.id === selected} onSelect={onSelect} />)}
    </div> : <div className="booking-empty" role="status">برای این ترکیب، پروفایل نمایشی سازگار وجود ندارد. خدمات را ویرایش کنید.</div>}
  </fieldset>;
}
