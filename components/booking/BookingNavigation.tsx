import Icon from "@/components/Icon";
import type { BookingStep } from "@/types/booking";

export default function BookingNavigation({ step, onBack }: { step: BookingStep; onBack: () => void }) {
  return <div className="booking-navigation"><button type="button" className="btn btn-ghost booking-back" disabled={step === 1} onClick={onBack}><Icon name="chevron" size={17} />مرحله قبل</button><button type="submit" className="btn btn-gold booking-next">{step === 5 ? "نمایش پیش‌نمایش نهایی" : "مرحله بعد"}<Icon name="arrow" size={18} /></button></div>;
}
