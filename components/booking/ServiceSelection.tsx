import Icon from "@/components/Icon";
import type { ServiceId } from "@/data/site";
import type { BookingServiceOption, PricingMode } from "@/types/booking";
import { formatToman } from "@/lib/booking/calculations";
import { faNumber } from "@/lib/booking/date-utils";

export default function ServiceSelection({ services, selected, branchId, mode, onMode, onToggle, error }: { services: BookingServiceOption[]; selected: ServiceId[]; branchId: string | null; mode: PricingMode; onMode: (mode: PricingMode) => void; onToggle: (id: ServiceId) => void; error: string | null }) {
  return <>
    <div className="booking-fixture-switch"><div><strong>قیمت و مدت واقعی هنوز تأیید نشده‌اند.</strong><p>برای آزمایش جمع مبلغ و مدت، می‌توانید اعداد کاملاً فرضی را روشن کنید.</p></div>
      <label className="booking-switch"><input type="checkbox" checked={mode === "demo"} onChange={e => onMode(e.target.checked ? "demo" : "unconfirmed")} /> استفاده از اعداد فرضی</label>
    </div>
    {mode === "demo" && <p className="booking-demo-caption" role="status">حالت آزمایشی روشن است؛ همه قیمت‌ها و مدت‌های زیر فرضی‌اند و تعرفه سالن نیستند.</p>}
    <fieldset className="booking-fieldset" aria-describedby={error ? "booking-error" : "service-hint"}>
      <legend className="sr-only">انتخاب یک یا چند خدمت</legend><p id="service-hint" className="booking-intro">یک یا چند خدمت انتخاب کنید؛ می‌توانید در مرحله بعد انتخاب‌ها را ویرایش کنید.</p>
      <div className="booking-service-grid">{services.map(service => {
        const active = selected.includes(service.id), eligible = !!service.offering?.active && service.offering.branchId === branchId;
        const { durationMinutes = null, priceToman = null } = service.offering ?? {};
        return <label className={`booking-service-card ${active ? "is-selected" : ""}`} key={service.id}>
          <div className="booking-service-image">{service.image ? <img src={service.image} alt={service.conceptual ? `تصویر مفهومی ${service.name}` : `جای‌نگهدار نسخه عمومی برای ${service.name}`} loading="lazy" /> : <Icon name={service.icon} size={34} />}{service.conceptual && <span>تصویر مفهومی</span>}</div>
          <div className="booking-service-copy"><div className="booking-choice-title"><strong>{service.name}</strong><input type="checkbox" name="booking-services" value={service.id} checked={active} disabled={!eligible} onChange={() => onToggle(service.id)} /></div><p>{service.description}</p>
            <div className="booking-service-values"><span><Icon name="clock" size={14} />{durationMinutes === null ? "مدت تأیید نشده" : `${faNumber(durationMinutes)} دقیقه فرضی`}</span><b>{formatToman(priceToman)}{priceToman !== null && <small> · فرضی</small>}</b></div>
          </div>
        </label>;
      })}</div>
    </fieldset>
  </>;
}
