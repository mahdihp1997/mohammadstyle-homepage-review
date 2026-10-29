import Icon from "@/components/Icon";
import JalaliCalendar from "./JalaliCalendar";
import { addDays, formatJalali } from "@/lib/booking/date-utils";
import type { AvailabilityState, DemoTimeSlot, LocalDate } from "@/types/booking";

export default function DateTimeSelection({ min, max, selectedDate, selectedSlot, timeZone, availability, onDate, onSlot, onRetry, error }: { min: LocalDate; max: LocalDate; selectedDate: LocalDate | null; selectedSlot: DemoTimeSlot | null; timeZone: string; availability: AvailabilityState; onDate: (date: LocalDate) => void; onSlot: (slot: DemoTimeSlot) => void; onRetry: () => void; error: string | null }) {
  return <fieldset className="booking-fieldset" aria-describedby={error ? "booking-error" : "datetime-hint"}><legend className="sr-only">تاریخ و ساعت نمایشی</legend>
    <p className="booking-intro" id="datetime-hint">تمام ساعت‌ها داده نمونه‌اند؛ هیچ ادعایی درباره ظرفیت واقعی سالن ندارند. منطقه زمانی نمایش ساعت: <bdi>{timeZone}</bdi>{timeZone === "Asia/Tehran" && " (تهران)"}.</p>
    <div className="booking-datetime-grid"><JalaliCalendar min={min} max={max} selected={selectedDate} onSelect={onDate} />
      <section className="booking-times" aria-labelledby="times-heading" aria-busy={availability.status === "loading"}><h3 id="times-heading"><Icon name="clock" size={19} />ساعت‌های نمایشی</h3>
        <p>{selectedDate ? formatJalali(selectedDate) : "ابتدا یک روز در تقویم انتخاب کنید."}</p>
        <div className="booking-slot-status" role="status">
          {availability.status === "loading" && <span>در حال آماده‌سازی ساعت‌های نمونه…</span>}
          {availability.status === "error" && <><p>{availability.message}</p><button type="button" className="booking-text-button" onClick={onRetry}>تلاش دوباره</button></>}
          {availability.status === "ready" && !availability.slots.length && <div className="booking-empty"><Icon name="calendar" size={30} /><strong>در این روز زمان نمایشی وجود ندارد.</strong><span>روز دیگری انتخاب کنید؛ این وضعیت هم بخشی از سناریوی آزمایشی است.</span></div>}
        </div>
        {availability.status === "ready" && availability.slots.length > 0 && <div className="booking-time-slots">{availability.slots.map(slot => <button key={slot.id} type="button" disabled={!slot.selectable} data-time={slot.startTime} aria-pressed={selectedSlot?.id === slot.id} onClick={() => onSlot(slot)}><bdi>{slot.startTime}</bdi><small>{slot.selectable ? "نمایشی" : "غیرقابل انتخاب"}</small></button>)}</div>}
        <p className="booking-demo-caption">برای آزمون حالت بدون زمان: {formatJalali(addDays(min, 1))}. روزهای خارج از بازه غیرفعال‌اند.</p>
      </section>
    </div>
  </fieldset>;
}
