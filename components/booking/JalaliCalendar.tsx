"use client";

import { useEffect, useRef, useState, type KeyboardEvent } from "react";
import Icon from "@/components/Icon";
import { addDays, calendarWeeks, faNumber, formatJalali, jalaliParts, monthStart, sameMonth, shiftMonth, withinDates } from "@/lib/booking/date-utils";
import type { LocalDate } from "@/types/booking";

const weekdays = ["شنبه", "یکشنبه", "دوشنبه", "سه‌شنبه", "چهارشنبه", "پنجشنبه", "جمعه"];
export default function JalaliCalendar({ min, max, selected, onSelect }: { min: LocalDate; max: LocalDate; selected: LocalDate | null; onSelect: (date: LocalDate) => void }) {
  const [month, setMonth] = useState(() => monthStart(selected ?? min));
  const [focused, setFocused] = useState<LocalDate>(selected ?? min);
  const focusPending = useRef(false);
  const days = useRef(new Map<LocalDate, HTMLButtonElement>());
  useEffect(() => { if (focusPending.current) { days.current.get(focused)?.focus(); focusPending.current = false; } }, [focused, month]);
  const moveTo = (target: LocalDate) => {
    const next = target < min ? min : target > max ? max : target;
    focusPending.current = true; setFocused(next); setMonth(monthStart(next));
  };
  const navigate = (direction: -1 | 1) => { const start = shiftMonth(month, direction); setMonth(start); setFocused(start < min ? min : start > max ? max : start); };
  const onKey = (event: KeyboardEvent<HTMLButtonElement>, date: LocalDate) => {
    let target: LocalDate | null = null;
    if (event.key === "ArrowLeft") target = addDays(date, 1);
    if (event.key === "ArrowRight") target = addDays(date, -1);
    if (event.key === "ArrowDown") target = addDays(date, 7);
    if (event.key === "ArrowUp") target = addDays(date, -7);
    if (event.key === "Home") target = addDays(date, -((new Date(`${date}T12:00:00Z`).getUTCDay() + 1) % 7));
    if (event.key === "End") target = addDays(date, 6 - ((new Date(`${date}T12:00:00Z`).getUTCDay() + 1) % 7));
    if (event.key === "PageDown") target = shiftMonth(month, 1);
    if (event.key === "PageUp") target = shiftMonth(month, -1);
    if (target) { event.preventDefault(); moveTo(target); }
  };
  const prev = shiftMonth(month, -1), next = shiftMonth(month, 1);
  return <div className="booking-calendar" data-min-date={min} data-max-date={max} data-month-start={month}>
    <div className="booking-calendar-head"><button type="button" aria-label="ماه قبل" disabled={addDays(month, -1) < min} onClick={() => navigate(-1)}><Icon name="chevron" size={19} /></button><h3 id="calendar-month" aria-live="polite">{formatJalali(month, { month: "long", year: "numeric" })}</h3><button type="button" aria-label="ماه بعد" disabled={next > max} onClick={() => navigate(1)}><Icon name="chevron" className="booking-reverse" size={19} /></button></div>
    <table role="grid" aria-labelledby="calendar-month" aria-describedby="calendar-help"><thead><tr>{weekdays.map(day => <th key={day} scope="col"><abbr title={day}>{day.slice(0, 1)}</abbr></th>)}</tr></thead><tbody>
      {calendarWeeks(month).map((week, index) => <tr key={index}>{week.map(date => {
        const currentMonth = sameMonth(date, month), enabled = currentMonth && withinDates(date, min, max);
        return <td key={date}><button type="button" ref={el => { if (el) days.current.set(date, el); else days.current.delete(date); }} data-date={date} disabled={!enabled} tabIndex={enabled && date === focused ? 0 : -1} aria-label={formatJalali(date)} aria-pressed={selected === date} className={selected === date ? "is-selected" : ""} onFocus={() => setFocused(date)} onKeyDown={e => onKey(e, date)} onClick={() => onSelect(date)}>{currentMonth ? faNumber(jalaliParts(date).day) : <span aria-hidden="true">·</span>}</button></td>;
      })}</tr>)}
    </tbody></table><p id="calendar-help">تقویم جلالی · جابه‌جایی با کلیدهای جهت و Page Up / Down</p><span className="sr-only">ماه پیشین: {formatJalali(prev, { month: "long" })}</span>
  </div>;
}
