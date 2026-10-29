"use client";

import { useEffect, useMemo, useReducer, useRef, useState } from "react";
import Icon from "@/components/Icon";
import { business, type ServiceId } from "@/data/site";
import { bookingCatalog, createDemoAvailability } from "@/data/booking-demo";
import { addDays, faNumber } from "@/lib/booking/date-utils";
import { calculateTotals } from "@/lib/booking/calculations";
import { createBookingReducer, initialBookingState } from "@/lib/booking/state";
import { eligibleBarbers, validBarber, validServices } from "@/lib/booking/validation";
import type { AvailabilityRequest, AvailabilityState, LocalDate } from "@/types/booking";
import BookingStepper, { bookingSteps } from "./BookingStepper";
import BranchSelection from "./BranchSelection";
import ServiceSelection from "./ServiceSelection";
import BarberSelection from "./BarberSelection";
import DateTimeSelection from "./DateTimeSelection";
import BookingSummary, { BookingOverview } from "./BookingSummary";
import BookingNavigation from "./BookingNavigation";

export default function BookingWizard({ today, initialService }: { today: LocalDate; initialService: ServiceId | null }) {
  const min = addDays(today, 1), max = addDays(today, 60);
  const reducer = useMemo(() => createBookingReducer(min, max), [min, max]);
  const [state, dispatch] = useReducer(reducer, initialService, initialBookingState);
  const [interactive, setInteractive] = useState(false);
  useEffect(() => { setInteractive(true); }, []);
  const { draft, step } = state;
  const catalog = useMemo(() => bookingCatalog(draft.pricingMode), [draft.pricingMode]);
  const eligible = eligibleBarbers(catalog, draft.branchId, draft.serviceIds);
  const totals = calculateTotals(catalog.services.filter(s => draft.serviceIds.includes(s.id)));
  const provider = useMemo(() => createDemoAvailability(today), [today]);
  const [availability, setAvailability] = useState<AvailabilityState>({ status: "idle", key: "", slots: [] });
  const [retry, setRetry] = useState(0);
  const request = useMemo<AvailabilityRequest | null>(() => {
    if (!draft.branchId || !draft.date || !validServices(draft, catalog) || !validBarber(draft, catalog)) return null;
    const branch = catalog.branches.find(b => b.id === draft.branchId)!;
    return { branchId: branch.id, serviceIds: [...draft.serviceIds].sort(), barberIds: eligibleBarbers(catalog, draft.branchId, draft.serviceIds).filter(b => draft.barberId === "any" || b.id === draft.barberId).map(b => b.id), date: draft.date, timeZone: branch.timeZone, durationMinutes: totals.durationMinutes };
  }, [catalog, draft.branchId, draft.serviceIds, draft.barberId, draft.date, totals.durationMinutes]);
  const requestKey = request ? JSON.stringify(request) : "";
  useEffect(() => {
    if (!request) { setAvailability({ status: "idle", key: "", slots: [] }); return; }
    const abort = new AbortController();
    setAvailability({ status: "loading", key: requestKey, slots: [] });
    provider.loadSlots(request, abort.signal).then(slots => {
      if (!abort.signal.aborted) setAvailability({ status: "ready", key: requestKey, slots });
    }).catch((error: unknown) => {
      if (!abort.signal.aborted) setAvailability({ status: "error", key: requestKey, slots: [], message: "بارگذاری داده نمونه انجام نشد. دوباره تلاش کنید." });
      // Abort is an expected lifecycle event; other failures are represented in the UI.
      void error;
    });
    return () => abort.abort();
  }, [requestKey, provider, retry]); // The key includes every field of the immutable request.
  const shownAvailability: AvailabilityState = request && availability.key !== requestKey ? { status: "loading", key: requestKey, slots: [] } : availability;
  const slots = shownAvailability.status === "ready" ? shownAvailability.slots : [];
  const headingRef = useRef<HTMLHeadingElement>(null), errorRef = useRef<HTMLDivElement>(null), resultRef = useRef<HTMLDivElement>(null);
  const previousStep = useRef(step);
  useEffect(() => { if (previousStep.current !== step) { headingRef.current?.focus(); previousStep.current = step; } }, [step]);
  useEffect(() => { if (state.error) errorRef.current?.focus(); else if (state.previewViewed) resultRef.current?.focus(); }, [state]);

  return <div className="booking-page"><a className="skip-link" href="#booking-main">رفتن به مراحل رزرو</a>
    <header className="booking-header"><div className="booking-shell"><a href="/" className="brand" aria-label="محمد استایل؛ صفحه اصلی"><span className="brand-crown"><Icon name="crown" size={26} /></span><span className="brand-name">{business.brand}<span>MOHAMMAD STYLE</span></span></a><a className="booking-home-link" href="/">بازگشت به خانه<Icon name="chevron" size={17} /></a></div></header>
    <main id="booking-main" tabIndex={-1} className="booking-shell booking-main">
      <div className="booking-title-row"><div><span className="section-eyebrow"><span className="gold-dot" />THE NEXT CHAPTER</span><h1>زمانی برای <em>استایل شما.</em></h1><p>پیش‌نمایش مسیر رزرو، با همان توجه به جزئیات.</p></div><span className="booking-edition">BOOKING / PREVIEW<br /><b>PHASE 02</b></span></div>
      <div className="booking-demo-notice"><Icon name="sparkle" size={20} /><p><strong>نسخه نمایشی؛ هیچ نوبتی ثبت نمی‌شود.</strong> آرایشگران، تخصیص خدمات و ساعت‌ها داده آزمایشی‌اند. قیمت، مدت و سیاست واقعی هنوز تأیید نشده‌اند.</p></div>
      <BookingStepper step={step} onGo={target => dispatch({ type: "go", step: target })} />
      <div className="booking-workspace"><form className="booking-panel" aria-busy={!interactive} onSubmit={event => { event.preventDefault(); dispatch({ type: step === 5 ? "preview" : "next", slots }); }} noValidate>
        <fieldset className="booking-hydration-guard" disabled={!interactive}><legend className="sr-only">فرایند رزرو نمایشی</legend>
        <div className="booking-panel-title"><div><span>مرحله {faNumber(step)} از {faNumber(5)}</span><h2 ref={headingRef} tabIndex={-1}>{bookingSteps[step - 1]}</h2></div><Icon name={["location", "scissors", "crown", "calendar", "check"][step - 1]} size={26} /></div>
        {state.error && <div ref={errorRef} id="booking-error" className="booking-error" role="alert" tabIndex={-1}><strong>انتخاب را کامل کنید</strong><p>{state.error}</p><a href="#booking-choices" onClick={event => { event.preventDefault(); document.querySelector<HTMLElement>('#booking-choices input:not(:disabled), #booking-choices button:not(:disabled)')?.focus(); }}>رفتن به گزینه‌های این مرحله</a></div>}
        <div id="booking-choices" tabIndex={-1}>
          {step === 1 && <BranchSelection branches={catalog.branches} selected={draft.branchId} onChange={id => dispatch({ type: "branch", id })} error={state.error} />}
          {step === 2 && <ServiceSelection services={catalog.services} branchId={draft.branchId} selected={draft.serviceIds} mode={draft.pricingMode} onMode={mode => dispatch({ type: "pricing", mode })} onToggle={id => dispatch({ type: "service", id })} error={state.error} />}
          {step === 3 && <BarberSelection eligible={eligible} selected={draft.barberId} onSelect={id => dispatch({ type: "barber", id })} error={state.error} />}
          {step === 4 && <DateTimeSelection min={min} max={max} selectedDate={draft.date} selectedSlot={draft.slot} timeZone={catalog.branches.find(b => b.id === draft.branchId)?.timeZone ?? "Asia/Tehran"} availability={shownAvailability} onDate={date => dispatch({ type: "date", date })} onSlot={slot => dispatch({ type: "slot", slot })} onRetry={() => setRetry(n => n + 1)} error={state.error} />}
          {step === 5 && <BookingSummary draft={draft} catalog={catalog} onPolicy={id => dispatch({ type: "policy", id })} onOptional={value => dispatch({ type: "optionalDeposit", value })} onEdit={target => dispatch({ type: "go", step: target })} />}
        </div>
        {state.previewViewed && <div ref={resultRef} className="booking-preview-result" role="status" tabIndex={-1}><Icon name="check" size={24} /><div><h3>پیش‌نمایش آماده بررسی است.</h3><p>هیچ نوبت یا پرداختی ثبت نشده است. اطلاعات فقط در حافظه همین صفحه است و با بارگذاری مجدد پاک می‌شود.</p>{state.policyPreview && <p>نسخه {faNumber(state.policyPreview.version)} از سیاست نمونه در این پیش‌نمایش نگهداری شد؛ به معنی پذیرش قرارداد نیست.</p>}</div></div>}
        <BookingNavigation step={step} onBack={() => dispatch({ type: "back" })} />
        </fieldset><noscript><p>برای استفاده از پیش‌نمایش تعاملی، جاوااسکریپت مرورگر را فعال کنید. هیچ نوبتی ثبت نمی‌شود.</p></noscript>
      </form>
      <aside className="booking-aside" aria-label="خلاصه انتخاب‌های فعلی"><div className="booking-aside-photo"><img src="/images/barber-working.webp" alt="جای‌نگهدار نسخه عمومی برای تصویر آرایشگر؛ عکس خصوصی حذف شده است" /><span>THE ART IS IN THE DETAILS</span></div><details open className="booking-aside-details"><summary>انتخاب‌های شما<span>فقط پیش‌نمایش</span></summary><BookingOverview draft={draft} catalog={catalog} compact /></details><p className="booking-aside-note"><Icon name="clock" size={16} />زمان پایان، ظرفیت واقعی و تعرفه‌ها پس از تأیید و اتصال سامانه مشخص می‌شوند.</p></aside>
      </div><footer className="booking-footer"><span>محمد استایل · سالن ممتاز پونک</span><span>رزرو واقعی و پرداخت در این نسخه فعال نیستند.</span></footer>
    </main>
  </div>;
}
