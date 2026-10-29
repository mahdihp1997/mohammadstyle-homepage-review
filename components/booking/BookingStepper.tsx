import Icon from "@/components/Icon";
import { faNumber } from "@/lib/booking/date-utils";
import type { BookingStep } from "@/types/booking";

export const bookingSteps = ["انتخاب شعبه", "انتخاب خدمات", "انتخاب آرایشگر", "تاریخ و ساعت", "مرور نهایی"] as const;
export default function BookingStepper({ step, onGo }: { step: BookingStep; onGo: (step: BookingStep) => void }) {
  return <nav className="booking-stepper" aria-label="مراحل پیش‌نمایش رزرو"><ol>
    {bookingSteps.map((label, index) => {
      const number = (index + 1) as BookingStep;
      return <li key={label} className={number === step ? "is-current" : number < step ? "is-complete" : ""}>
        <button type="button" disabled={number > step} aria-current={number === step ? "step" : undefined} onClick={() => onGo(number)} aria-label={`مرحله ${faNumber(number)}: ${label}`}>
          <span className="booking-step-number" aria-hidden="true">{number < step ? <Icon name="check" size={17} /> : faNumber(number)}</span><span>{label}</span>
        </button>
      </li>;
    })}
  </ol></nav>;
}
