"use client";
import { useEffect, useRef, useState } from 'react';
import Icon from '@/components/Icon';
import { business } from '@/data/site';
import { addDays, faNumber, formatJalali, localToday } from '@/lib/booking/date-utils';
import type { LocalDate, BookingStep } from '@/types/booking';
import type { ServerCatalog, ServerSlot, FinalQuote, ServerBooking, CancellationPreview } from '@/types/booking-server';
import { serverBooking, bookingError, rialLabel } from '@/lib/booking/server-adapter';
import ServerFrozenTerms from './ServerFrozenTerms';
import BookingStepper, { bookingSteps } from './BookingStepper';
import JalaliCalendar from './JalaliCalendar';
const statusLabel: Record<ServerBooking['status'], string> = { DRAFT: 'پیش‌نویس', HELD: 'ظرفیت موقت نگه داشته شد', PENDING_PAYMENT: 'در انتظار پرداخت واقعی', CONFIRMED: 'رزرو تأییدشده در محیط آزمایشی', CANCELLED: 'لغوشده', EXPIRED: 'منقضی‌شده' };
export default function ServerBookingWizard() {
    const [catalog, setCatalog] = useState<ServerCatalog | null>(null), [step, setStep] = useState(1), [branchId, setBranch] = useState<string | null>(null), [offeringIds, setOfferings] = useState<string[]>([]), [staffId, setStaff] = useState<string | null>(null), [date, setDate] = useState<LocalDate | null>(null);
    const [slots, setSlots] = useState<ServerSlot[]>([]), [slotId, setSlot] = useState<string | null>(null), [quote, setQuote] = useState<FinalQuote | null>(null), [accepted, setAccepted] = useState(false), [optional, setOptional] = useState(false);
    const [cursor, setCursor] = useState('0'), [nextCursor, setNextCursor] = useState<string | null>(null);
    const [slotsKey,setSlotsKey]=useState('');
    const [busy, setBusy] = useState(false), [loading, setLoading] = useState(true), [availabilityLoading, setAvailabilityLoading] = useState(false), [error, setError] = useState<string | null>(null), [retry, setRetry] = useState(0), [catalogRetry, setCatalogRetry] = useState(0);
    const [result, setResult] = useState<ServerBooking | null>(null), [history, setHistory] = useState<ServerBooking[]>([]), [preview, setPreview] = useState<CancellationPreview | null>(null), [rescheduling, setRescheduling] = useState<ServerBooking | null>(null), [now, setNow] = useState(() => Date.now());
    const errorRef = useRef<HTMLDivElement>(null), headingRef = useRef<HTMLHeadingElement>(null), resultRef = useRef<HTMLDivElement>(null), busyRef = useRef(false), draftRef = useRef<ServerBooking | null>(null), keys = useRef(new Map<string, string>());
    const branch = catalog?.branches.find(x => x.id === branchId), offerings = catalog?.offerings.filter(x => x.branchId === branchId) ?? [], selected = offerings.filter(x => offeringIds.includes(x.id));
    const eligible = catalog?.staff.filter(x => offeringIds.length > 0 && offeringIds.every(id => x.offeringIds.includes(id))) ?? [];
    const zone = branch?.timeZone ?? 'Asia/Tehran', time = (s: string,timeZone=zone) => new Intl.DateTimeFormat('fa-IR', { timeZone, hour: '2-digit', minute: '2-digit', hour12: false }).format(new Date(s));
    const requestKey = branchId && date && offeringIds.length ? JSON.stringify({ branchId, offeringIds, staffId, date, optionalDepositChosen: optional, rescheduleBookingId: rescheduling?.id ?? null, cursor }) : '';
    const bindingKey=requestKey+':'+retry;
    const shownSlots=slotsKey===bindingKey?slots:[];
    const slot = shownSlots.find(x => x.id === slotId) ?? null, slotExpired = slot ? Date.parse(slot.expiresAt) <= now : false, quoteExpired = quote ? Date.parse(quote.expiresAt) <= now : false;
    useEffect(() => { const timer = setInterval(() => setNow(Date.now()), 1000); return () => clearInterval(timer); }, []);
    useEffect(() => { const abort = new AbortController(); setLoading(true); setError(null); serverBooking.catalog(abort.signal).then(c => { if (!abort.signal.aborted)
        setCatalog(c); }).catch(e => { if (!abort.signal.aborted)
        setError(bookingError(e)); }).finally(() => { if (!abort.signal.aborted)
        setLoading(false); }); return () => abort.abort(); }, [catalogRetry]);
    useEffect(() => { if (catalog)
        serverBooking.history().then(x => setHistory(x.items)).catch(e => setError(bookingError(e))); }, [catalog]);
    useEffect(() => {
        setSlot(null);
        setQuote(null);
        setAccepted(false);
        setSlots([]);
        setNextCursor(null);
        setAvailabilityLoading(false);
        if (!requestKey)
            return;
        const abort = new AbortController();
        setAvailabilityLoading(true);
        serverBooking.availability(JSON.parse(requestKey), abort.signal).then(x => { if (!abort.signal.aborted) {
            setSlots(x.slots);
            setSlotsKey(bindingKey);
            setNextCursor(x.nextCursor);
        } }).catch(e => { if (!abort.signal.aborted)
            setError(bookingError(e)); }).finally(() => { if (!abort.signal.aborted)
            setAvailabilityLoading(false); });
        return () => abort.abort();
    }, [requestKey, retry]);
    useEffect(() => { headingRef.current?.focus(); }, [step]);
    useEffect(() => { if (error)
        errorRef.current?.focus(); }, [error]);
    useEffect(() => { if (result)
        resultRef.current?.focus(); }, [result]);
    const clear = () => { setQuote(null); setAccepted(false); setError(null); setPreview(null); setCursor('0'); draftRef.current = null; };
    const clearContext = () => { clear(); setOptional(false); };
    const changeBranch = (id: string) => { clear(); setBranch(id); setOfferings([]); setStaff(null); setDate(null); setSlot(null); setOptional(false); };
    async function run(action: () => Promise<void>) { if (busyRef.current)
        return; busyRef.current = true; setBusy(true); setError(null); try {
        await action();
    }
    catch (e) {
        setError(bookingError(e));
    }
    finally {
        busyRef.current = false;
        setBusy(false);
    } }
    async function command(op: string, data: unknown, intent = '') {
        const body = JSON.stringify(data), mapKey = op + ':' + intent + ':' + body;
        let key = keys.current.get(mapKey);
        if (!key) {
            key = crypto.randomUUID();
            keys.current.set(mapKey, key);
        }
        return serverBooking.command(op, data, key);
    }
    async function refreshHistory() { const x = await serverBooking.history(); setHistory(x.items); if (result)
        setResult(await serverBooking.booking(result.id)); }
    async function next() {
        if (step === 1 && !branch?.configured) {
            setError('شعبه‌ای با پیکربندی تأییدشده انتخاب کنید.');
            return;
        }
        if (step === 2 && !offeringIds.length) {
            setError('حداقل یک خدمت انتخاب کنید.');
            return;
        }
        if (step === 3 && (!eligible.length || staffId && !eligible.some(x => x.id === staffId))) {
            setError('یک ارائه‌دهنده واجد شرایط برای همه خدمات لازم است.');
            return;
        }
        if (step === 4) {
            if (!slot || slotExpired || availabilityLoading) {
                setError('یک زمان معتبر از پاسخ فعلی سرور انتخاب کنید.');
                return;
            }
            await run(async () => { const q = await serverBooking.quote(slot.id); setQuote(q); setAccepted(false); setStep(5); });
            return;
        }
        if (step < 5) {
            setError(null);
            setStep(step + 1);
            return;
        }
        if (!quote || quoteExpired || !accepted) {
            setError('شرایط همین پیشنهاد را بخوانید و صریحاً بپذیرید. پیشنهاد منقضی‌شده به دریافت مجدد نیاز دارد.');
            return;
        }
        await run(async () => {
            let b = rescheduling;
            if (!b) {
                if (!draftRef.current)
                    draftRef.current = await command('draft', { branchId }, quote.id);
                b = draftRef.current;
            }
            const held = await command(rescheduling ? 'reschedule' : 'hold', { bookingId: b.id, version: b.version, quoteId: quote.id, contentHash: quote.contentHash, snapshotHash: quote.content.policy.snapshotHash, accepted: true });
            setResult(held);
            if (held.status === 'HELD' && !rescheduling) {
                const confirmed = await command('confirm', { bookingId: held.id, version: held.version });
                setResult(confirmed);
            }
            setHistory((await serverBooking.history()).items);
        });
    }
    function startReschedule(b: ServerBooking) { if (!b.quote)
        return; clearContext(); setResult(null); setRescheduling(b); setBranch(b.branchId); setOfferings(b.quote.content.items.map(x => x.offeringId)); setStaff(b.quote.content.segments[0]?.staffId ?? null); setDate(null); setStep(4); }
    return <div className="booking-page"><a className="skip-link" href="#booking-main">رفتن به مراحل رزرو</a>
  <header className="booking-header"><div className="booking-shell"><a href="/" className="brand" aria-label="محمد استایل؛ صفحه اصلی"><span className="brand-crown"><Icon name="crown" size={26}/></span><span className="brand-name">{business.brand}<span>MOHAMMAD STYLE</span></span></a><a className="booking-home-link" href="/">بازگشت به خانه<Icon name="chevron" size={17}/></a></div></header>
  <main id="booking-main" tabIndex={-1} className="booking-shell booking-main">
   <div className="booking-title-row"><div><span className="section-eyebrow"><span className="gold-dot"/>THE NEXT CHAPTER</span><h1>زمانی برای <em>استایل شما.</em></h1><p>رزرو با ظرفیت و شرایط محاسبه‌شده در سرور.</p></div><span className="booking-edition">BOOKING / SERVER<br /><b>ISOLATED B4</b></span></div>
   <div className="booking-demo-notice"><Icon name="sparkle" size={20}/><p><strong>محیط آزمایشیِ جداگانه</strong> ثبت در پایگاه محلی واقعی است؛ نام‌ها، قیمت‌ها و سیاست‌های این محیط، اطلاعات واقعی سالن نیستند. پرداخت و پیامک فعال نیستند. <a href="/booking">بازگشت به DEMO</a></p></div>
   <BookingStepper step={step as BookingStep} disabled={busy || !!result || !!rescheduling} label="مراحل رزرو سرور" onGo={target => { if (target < step && !busy && !result) {
        clear();
        setStep(target);
    } }}/>
   <div className="booking-workspace"><form className="booking-panel" aria-busy={busy || loading} onSubmit={e => { e.preventDefault(); void next(); }} noValidate>
    <div className="booking-panel-title"><div><span>مرحله {faNumber(step)} از {faNumber(5)}</span><h2 ref={headingRef} tabIndex={-1}>{bookingSteps[step - 1]}</h2></div><Icon name="calendar" size={26}/></div>
    {error && <div id="booking-error" className="booking-error" role="alert" tabIndex={-1} ref={errorRef}><strong>درخواست به بررسی نیاز دارد</strong><p>{error}</p><button type="button" className="booking-text-button" onClick={() => catalog ? void run(refreshHistory) : setCatalogRetry(x => x + 1)}>بررسی وضعیت و تلاش دوباره</button></div>}
    {loading && <p role="status">در حال دریافت اطلاعات سرور…</p>}
    {catalog && !result && <fieldset className="booking-hydration-guard" disabled={busy}><legend className="sr-only">مراحل رزرو در محیط محلی</legend>
     {step === 1 && <fieldset className="booking-fieldset" aria-describedby={error ? 'booking-error' : 'server-branch-hint'}><legend className="sr-only">انتخاب شعبه</legend><p id="server-branch-hint" className="booking-intro">فقط شعبه‌های دارای پیکربندی کامل قابل انتخاب‌اند.</p><div className="booking-branch-grid">{catalog.branches.map(x => <label key={x.id} className={`booking-branch-card ${branchId === x.id ? 'is-selected' : ''} ${!x.configured ? 'is-unconfigured' : ''}`}><div className="booking-branch-placeholder" aria-hidden="true"><Icon name="location" size={36}/><span>محیط محلی B4</span></div><div className="booking-branch-copy"><div className="booking-choice-title"><h3>{x.name}</h3><input type="radio" name="server-branch" checked={branchId === x.id} disabled={!x.configured} onChange={() => changeBranch(x.id)}/></div><span className="booking-badge">{x.configured ? 'پیکربندی فعال' : 'پیکربندی ناقص؛ ثبت بسته است'}</span></div></label>)}</div></fieldset>}
     {step === 2 && <fieldset className="booking-fieldset" aria-describedby={error ? 'booking-error' : 'server-service-hint'}><legend className="sr-only">انتخاب خدمات سرور</legend><p id="server-service-hint" className="booking-intro">قیمت‌ها و مدت‌ها از پیکربندی همین شعبه دریافت شده‌اند. این محیط صرفاً آزمایشی است.</p><div className="booking-service-grid">{offerings.map(x => <label key={x.id} className={`booking-service-card ${offeringIds.includes(x.id) ? 'is-selected' : ''}`}><div className="booking-service-copy"><div className="booking-choice-title"><strong>{x.name}</strong><input type="checkbox" name="server-services" checked={offeringIds.includes(x.id)} onChange={() => { clearContext(); setOfferings(ids => ids.includes(x.id) ? ids.filter(i => i !== x.id) : [...ids, x.id]); setStaff(null); setDate(null); }}/></div><div className="booking-service-values"><span>{faNumber(Number(x.durationMinutes))} دقیقه خدمت، به‌علاوه زمان آماده‌سازی</span><b>{rialLabel(x.priceRial)}</b></div></div></label>)}</div></fieldset>}
     {step === 3 && <fieldset className="booking-fieldset" aria-describedby={error ? 'booking-error' : 'server-staff-hint'}><legend className="sr-only">انتخاب آرایشگر</legend><p id="server-staff-hint" className="booking-intro">در این مرحله، یک ارائه‌دهنده باید صلاحیت انجام تمام خدمات را داشته باشد.</p><div className="booking-barber-list"><label className={`booking-any-barber ${staffId === null ? 'is-selected' : ''}`}><input type="radio" name="server-staff" checked={staffId === null} onChange={() => { clearContext(); setStaff(null); }}/><div><strong>فرقی ندارد</strong><p>سرور یک ارائه‌دهنده واجد شرایط و واقعاً آزاد را انتخاب می‌کند.</p></div></label>{eligible.map(x => <label className={`booking-barber-card ${staffId === x.id ? 'is-selected' : ''}`} key={x.id}><span className="booking-avatar"><Icon name="scissors" size={24}/></span><input name="server-staff" type="radio" checked={staffId === x.id} onChange={() => { clearContext(); setStaff(x.id); }}/><div><h3>{x.name}</h3><p>واجد شرایط خدمات انتخاب‌شده</p></div></label>)}</div>{!eligible.length && <p role="status">ارائه‌دهنده مشترک برای این خدمات وجود ندارد.</p>}</fieldset>}
     {step === 4 && branch && <fieldset className="booking-fieldset" aria-describedby={error ? 'booking-error' : 'server-time-hint'}><legend className="sr-only">تاریخ و ظرفیت سرور</legend><p id="server-time-hint" className="booking-intro">ساعت‌ها از شیفت منتشرشده و ظرفیت کارکنان و تجهیزات محاسبه می‌شوند. تا ثبت نهایی، ظرفیت تضمین نمی‌شود. منطقه زمانی: <bdi>{zone}</bdi>.</p><div className="booking-datetime-grid"><JalaliCalendar min={branch.today} max={addDays(branch.today, branch.horizonDays)} selected={date} onSelect={d => { clearContext(); setDate(d); }}/><section className="booking-times" aria-busy={availabilityLoading}><h3>زمان‌های قابل رزرو</h3><p>{date ? formatJalali(date) : 'ابتدا روز را انتخاب کنید.'}</p><div role="status">{availabilityLoading ? 'در حال بررسی ظرفیت…' : date && !shownSlots.length ? 'زمان واجد شرایطی در این روز وجود ندارد.' : ''}</div><div className="booking-time-slots">{shownSlots.map(x => <button type="button" key={x.id} disabled={Date.parse(x.expiresAt) <= now} aria-pressed={slotId === x.id} onClick={() => { setSlot(x.id); setQuote(null); setAccepted(false); setError(null); }}><bdi>{time(x.startsAt)}</bdi><small>ظرفیت سرور</small></button>)}</div>{slotsKey===bindingKey && nextCursor && <button type="button" className="booking-text-button" disabled={availabilityLoading} onClick={() => setCursor(nextCursor)}>زمان‌های بعدی</button>}{date && <button type="button" className="booking-text-button" onClick={() => { setError(null); setRetry(x => x + 1); }}>بارگذاری مجدد زمان‌ها</button>}</section></div></fieldset>}
     {step === 5 && quote && <section className="booking-summary" aria-labelledby="server-terms-title"><h3 id="server-terms-title">پیشنهاد نهایی و شرایط ثابت‌شده</h3><p>{formatJalali(localToday(quote.content.timeZone,new Date(quote.content.startsAt)))}، ساعت {time(quote.content.startsAt)} تا {time(quote.content.endsAt)} · {catalog.staff.find(x => x.id === quote.content.segments[0]?.staffId)?.name}</p><ul>{quote.content.items.map(x => <li key={x.position}>{x.displayName} · {rialLabel(x.unitPriceRial)} · {faNumber(Number(x.durationMinutes))} دقیقه خدمت؛ {faNumber(Number(x.bufferBeforeMinutes))} دقیقه پیش و {faNumber(Number(x.bufferAfterMinutes))} دقیقه پس برای آماده‌سازی.</li>)}</ul><dl className="server-quote-values"><div><dt>جمع کل</dt><dd>{rialLabel(quote.content.totalRial)}</dd></div><div><dt>بیعانه طبق سیاست</dt><dd>{rialLabel(quote.content.depositRial)}</dd></div><div><dt>مانده پس از بیعانه</dt><dd>{rialLabel(quote.content.remainingRial)}</dd></div></dl>
      <ServerFrozenTerms quote={quote}/>
      {quote.terms.terms.depositRequirement === 'OPTIONAL' && <label className="booking-switch"><input type="checkbox" checked={optional} onChange={e => { setOptional(e.target.checked); clear(); setStep(4); }}/>انتخاب بیعانه اختیاری؛ با تغییر آن پیشنهاد تازه دریافت می‌شود</label>}
      <label className="booking-switch"><input type="checkbox" checked={accepted} aria-describedby="server-consent-help" onChange={e => {setAccepted(e.target.checked);setError(null);}}/>شرایط و مبالغ همین پیشنهاد را خواندم و می‌پذیرم.</label><p id="server-consent-help" className="booking-demo-caption">{quoteExpired ? 'پیشنهاد منقضی شده؛ زمان را دوباره انتخاب کنید.' : `اعتبار پیشنهاد تا ${time(quote.expiresAt)} است.`} ثبت با ظرفیت موقت آغاز می‌شود. بیعانه مثبت تا راه‌اندازی پرداخت واقعی، در انتظار پرداخت می‌ماند.</p>
     </section>}
     <div className="booking-navigation">{step > 1 && <button type="button" className="btn btn-ghost booking-back" onClick={() => { clear(); setStep(step - 1); }}>مرحله قبل</button>}<button type="submit" className="btn btn-gold booking-next" disabled={loading || busy || (step === 5 && quoteExpired)}>{busy ? 'در حال بررسی…' : step === 5 ? (rescheduling ? 'ثبت جابه‌جایی مجاز' : 'پذیرش و ثبت در محیط آزمایشی') : 'ادامه'}</button></div>
    </fieldset>}
    {result && <div className="booking-preview-result" ref={resultRef} tabIndex={-1} role="status"><Icon name="check" size={24}/><div><h3>{statusLabel[result.status]}</h3><p>شناسه: <bdi className="server-hash">{result.id}</bdi></p>{result.holdExpiresAt && ['HELD', 'PENDING_PAYMENT'].includes(result.status) && <p>پایان نگهداری ظرفیت: {time(result.holdExpiresAt)}. پرداختی انجام نشده است.</p>}<button type="button" className="booking-text-button" disabled={busy} onClick={() => void run(refreshHistory)}>بررسی وضعیت رزرو</button></div></div>}
   </form><aside className="booking-aside" aria-label="خلاصه انتخاب‌های فعلی"><details open className="booking-aside-details"><summary>انتخاب‌های شما<span>SERVER · محیط محلی</span></summary><div className="server-aside-copy"><p>{branch?.name ?? 'شعبه انتخاب نشده'}</p>{selected.map(x => <p key={x.id}>{x.name}</p>)}<p>{staffId ? catalog?.staff.find(x => x.id === staffId)?.name : 'ارائه‌دهنده: فرقی ندارد'}</p><p>{date ? formatJalali(date) : 'تاریخ انتخاب نشده'}</p>{slot && <p>{time(slot.startsAt)}</p>}</div></details><p className="booking-aside-note"><Icon name="clock" size={16}/>منابع و شرایط هنگام ثبت دوباره اعتبارسنجی می‌شوند.</p></aside></div>
   {catalog && <section className="booking-panel server-history" aria-labelledby="server-history-title"><div className="booking-choice-title"><h2 id="server-history-title">رزروهای همین حساب آزمایشی</h2><button type="button" className="booking-text-button" disabled={busy} onClick={() => void run(refreshHistory)}>به‌روزرسانی</button></div>{!history.length && <p>هنوز رزروی وجود ندارد.</p>}{history.map(b => <article key={b.id} className="booking-fixture-switch"><strong>{statusLabel[b.status]}</strong><p><bdi className="server-hash">{b.id}</bdi></p>{b.quote && <p>{time(b.quote.content.startsAt,b.quote.content.timeZone)} · {rialLabel(b.quote.content.totalRial)}</p>}{['DRAFT', 'HELD', 'PENDING_PAYMENT', 'CONFIRMED'].includes(b.status) && <div className="server-history-actions"><button type="button" disabled={busy} className="booking-text-button" onClick={() => void run(async () => { setPreview(await serverBooking.cancellation(b.id)); })}>بررسی شرایط لغو</button>{['HELD', 'CONFIRMED'].includes(b.status) && b.quote?.content.depositRial === '0' && b.quote.terms.terms.depositRequirement !== 'REQUIRED' && !b.quote.content.optionalDepositChosen && <button type="button" className="booking-text-button" disabled={busy} onClick={() => startReschedule(b)}>انتخاب زمان تازه</button>}{b.status === 'HELD' && <button type="button" className="booking-text-button" disabled={busy} onClick={() => void run(async () => { setResult(await command('confirm', { bookingId: b.id, version: b.version })); setHistory((await serverBooking.history()).items); })}>تأیید ظرفیت نگه‌داشته‌شده</button>}</div>}{preview?.bookingId === b.id && <div role="status"><p>{preview.cancellationAllowed ? 'لغو طبق شرایط فعلی مجاز است.' : 'لغو به بررسی مسئول نیاز دارد.'} وجه پرداخت‌شده: {rialLabel(preview.paidRial)}؛ بازپرداخت اجرایی انجام نمی‌شود.</p>{preview.cancellationAllowed && <button type="button" className="booking-text-button" disabled={busy} onClick={() => void run(async () => { const cancelled = await command('cancel', { bookingId: b.id, version: preview.version }); if (result?.id === b.id)
        setResult(cancelled); setPreview(null); setHistory((await serverBooking.history()).items); })}>تأیید لغو همین رزرو</button>}</div>}</article>)}</section>}
   <footer className="booking-footer"><span>محمد استایل · سالن ممتاز پونک</span><span>محیط جداگانه B4 · بدون پرداخت و پیامک</span></footer>
  </main>
 </div>;
}
