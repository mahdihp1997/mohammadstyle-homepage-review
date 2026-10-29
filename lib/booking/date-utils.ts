import type { LocalDate } from "@/types/booking";

const dayMs = 86_400_000;
export const faNumber = (n: number) => new Intl.NumberFormat("fa-IR").format(n);
export function isLocalDate(value: string): value is LocalDate {
  return /^\d{4}-\d{2}-\d{2}$/.test(value) && Number.isFinite(Date.parse(`${value}T12:00:00Z`)) && new Date(`${value}T12:00:00Z`).toISOString().slice(0, 10) === value;
}
export function addDays(date: LocalDate, amount: number): LocalDate {
  return new Date(Date.parse(`${date}T12:00:00Z`) + amount * dayMs).toISOString().slice(0, 10) as LocalDate;
}
export function localToday(timeZone: string, now = new Date()): LocalDate {
  const parts = new Intl.DateTimeFormat("en-US", { timeZone, calendar: "gregory", year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(now);
  const get = (type: string) => parts.find(p => p.type === type)!.value;
  return `${get("year")}-${get("month")}-${get("day")}` as LocalDate;
}
/** Noon UTC is only a carrier for date-only display, never an appointment instant. */
export function jalaliParts(date: LocalDate) {
  const parts = new Intl.DateTimeFormat("en-US-u-ca-persian", { timeZone: "UTC", year: "numeric", month: "numeric", day: "numeric" }).formatToParts(new Date(`${date}T12:00:00Z`));
  const get = (type: string) => Number(parts.find(p => p.type === type)!.value);
  return { year: get("year"), month: get("month"), day: get("day") };
}
export function formatJalali(date: LocalDate, options: Intl.DateTimeFormatOptions = { year: "numeric", month: "long", day: "numeric", weekday: "long" }) {
  return new Intl.DateTimeFormat("fa-IR-u-ca-persian", { ...options, timeZone: "UTC" }).format(new Date(`${date}T12:00:00Z`));
}
export function monthStart(date: LocalDate) { return addDays(date, 1 - jalaliParts(date).day); }
export function shiftMonth(start: LocalDate, direction: -1 | 1): LocalDate {
  return monthStart(addDays(start, direction === 1 ? 32 : -1));
}
export function calendarWeeks(start: LocalDate): LocalDate[][] {
  const weekday = (new Date(`${start}T12:00:00Z`).getUTCDay() + 1) % 7;
  const first = addDays(start, -weekday);
  return Array.from({ length: 6 }, (_, week) => Array.from({ length: 7 }, (_, day) => addDays(first, week * 7 + day)));
}
export function sameMonth(a: LocalDate, b: LocalDate) {
  const x = jalaliParts(a), y = jalaliParts(b);
  return x.year === y.year && x.month === y.month;
}
export const withinDates = (date: LocalDate, min: LocalDate, max: LocalDate) => isLocalDate(date) && date >= min && date <= max;
