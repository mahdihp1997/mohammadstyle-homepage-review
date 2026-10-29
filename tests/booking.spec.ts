import { test as base, expect, type Page } from "@playwright/test";
import { mkdir } from "node:fs/promises";
import { addDays, formatJalali, monthStart, shiftMonth } from "../lib/booking/date-utils";
import type { LocalDate } from "../types/booking";

const test = base.extend<{ browserDiagnostics: void }>({
  browserDiagnostics: [async ({ page }, use) => {
    const errors: string[] = [];
    page.on("pageerror", error => errors.push(error.message));
    page.on("console", message => { if (message.type() === "error") errors.push(message.text()); });
    page.on("response", response => { if (response.status() >= 400) errors.push(`${response.status()}: ${response.url()}`); });
    page.on("requestfailed", request => { if (request.failure()?.errorText !== "net::ERR_ABORTED") errors.push(request.failure()?.errorText ?? request.url()); });
    await use();
    expect(errors, "No browser, hydration, image or HTTP errors").toEqual([]);
  }, { auto: true }],
});
const next = (page: Page) => page.getByRole("button", { name: "مرحله بعد", exact: true });
const step = (page: Page, name: string) => expect(page.locator(".booking-panel-title h2")).toHaveText(name);
async function health(page: Page) {
  expect(await page.evaluate(() => document.documentElement.scrollWidth - innerWidth)).toBe(0);
  for (const image of await page.locator("img").all()) await image.evaluate((node: HTMLImageElement) => node.decode());
  expect(await page.locator("img").evaluateAll(nodes => nodes.map(n => n as HTMLImageElement).filter(n => !n.complete || !n.naturalWidth).length)).toBe(0);
  const clipped = await page.locator('.booking-page button:visible, .booking-page a:visible, .booking-page select:visible').evaluateAll(nodes => nodes.filter(n => { const r = n.getBoundingClientRect(); return r.left < -1 || r.right > innerWidth + 1; }).map(n => n.textContent));
  expect(clipped).toEqual([]);
}
async function capture(page: Page, name: string, project: string) {
  await health(page); await page.evaluate(() => document.fonts.ready);
  await mkdir("artifacts/screenshots/booking", { recursive: true });
  await page.evaluate(() => scrollTo(0, 0));
  await page.screenshot({ path: `artifacts/screenshots/booking/${name}-${project}-full.png`, fullPage: true });
  await page.evaluate(() => scrollTo(0, 0));
  await page.screenshot({ path: `artifacts/screenshots/booking/${name}-${project}-viewport.png` });
  await page.locator(".booking-panel-title").evaluate(node => node.scrollIntoView({ block: "start" }));
  await page.screenshot({ path: `artifacts/screenshots/booking/${name}-${project}-step.png` });
}
async function openServices(page: Page, query = "") {
  const response = await page.goto(`/booking${query}`); expect(response?.status()).toBe(200);
  await page.getByRole("radio", { name: /شعبه پونک/ }).check(); await next(page).click(); await step(page, "انتخاب خدمات");
}
async function openCalendar(page: Page) {
  await openServices(page, "?service=hair"); await next(page).click();
  await page.getByRole("radio", { name: /بدون ترجیح آرایشگر/ }).check(); await next(page).click(); await step(page, "تاریخ و ساعت");
}
async function selectDate(page: Page, date: LocalDate) {
  const calendar = page.locator(".booking-calendar");
  for (let attempt = 0; attempt < 4; attempt++) {
    const visibleMonth = await calendar.getAttribute("data-month-start") as LocalDate;
    if (monthStart(date) === visibleMonth) break;
    await page.getByRole("button", { name: date < visibleMonth ? "ماه قبل" : "ماه بعد", exact: true }).click();
  }
  await calendar.locator(`[data-date="${date}"]`).click();
}
async function pickDateAndTime(page: Page, date?: LocalDate) {
  const min = await page.locator(".booking-calendar").getAttribute("data-min-date") as LocalDate;
  await selectDate(page, date ?? min);
  await expect(page.getByText("در حال آماده‌سازی ساعت‌های نمونه…", { exact: true })).toBeVisible();
  await expect(page.locator('[data-time="10:00"]')).toBeDisabled();
  await page.locator('[data-time="11:30"]').click(); await next(page).click(); await step(page, "مرور نهایی");
}

test("Homepage entry preserves service, validates choices and handles unknown values", async ({ page }, info) => {
  await page.goto("/"); await page.locator(".service-hair").click();
  const entry = page.getByRole("link", { name: /شروع رزرو مرحله‌ای نمایشی/ });
  await expect(entry).toHaveAttribute("href", "/booking?service=hair"); await entry.click();
  await expect(page).toHaveURL(/\/booking\?service=hair$/); await expect(page.locator("html")).toHaveAttribute("dir", "rtl");
  await expect(page.locator(".booking-demo-notice")).toContainText("هیچ نوبتی ثبت نمی‌شود");
  await next(page).click(); await expect(page.locator(".booking-panel").getByRole("alert")).toContainText("شعبه"); await expect(page.locator(".booking-panel").getByRole("alert")).toBeFocused();
  await expect(page.getByRole("radio", { name: /شعبه دوم/ })).toBeDisabled();
  const branch = page.getByRole("radio", { name: /شعبه پونک/ }); await branch.focus(); await page.keyboard.press("Space");
  await next(page).click(); await expect(page.locator(".booking-panel-title h2")).toBeFocused();
  await expect(page.getByRole("checkbox", { name: /هیرکات مو/ })).toBeChecked();
  await expect(page.locator(".booking-service-card")).toHaveCount(6);
  await next(page).click(); await next(page).click(); await expect(page.locator(".booking-panel").getByRole("alert")).toContainText("آرایشگر");
  await page.getByRole("radio", { name: /بدون ترجیح آرایشگر/ }).check(); await next(page).click();
  await pickDateAndTime(page);
  await expect(page.getByTestId("booking-total-price")).toHaveText("تأیید نشده");
  await expect(page.getByTestId("booking-total-duration")).toHaveText("تأیید نشده");
  await expect(page.locator(".booking-policy")).toContainText("شرایط واقعی بیعانه، لغو و استرداد هنوز تأیید نشده‌اند");
  await page.getByLabel("سناریوی سیاست نمایشی").selectOption("demo-percent");
  await expect(page.getByTestId("policy-deposit")).toHaveText("قابل محاسبه نیست");
  await page.getByRole("button", { name: "نمایش پیش‌نمایش نهایی" }).click();
  await expect(page.locator(".booking-preview-result")).toContainText("هیچ نوبت یا پرداختی ثبت نشده");
  await capture(page, "summary-unknown", info.project.name);
  await page.reload(); await step(page, "انتخاب شعبه"); await expect(page.getByRole("radio", { name: /شعبه پونک/ })).not.toBeChecked();
  await page.goto("/booking?service=invalid"); await page.getByRole("radio", { name: /شعبه پونک/ }).check(); await next(page).click();
  await expect(page.locator('input[name="booking-services"]:checked')).toHaveCount(0);
});

test("all booking steps, demo totals and policy scenarios produce a preview without a reservation", async ({ page }, info) => {
  await page.goto("/booking"); await capture(page, "branch", info.project.name);
  await page.getByRole("radio", { name: /شعبه پونک/ }).check(); await next(page).click();
  await next(page).click(); await expect(page.locator(".booking-panel").getByRole("alert")).toContainText("حداقل یک خدمت");
  await page.getByRole("checkbox", { name: "استفاده از اعداد فرضی", exact: true }).check();
  await page.getByRole("checkbox", { name: /هیرکات مو/ }).check(); await page.getByRole("checkbox", { name: /فیشیال صورت/ }).check();
  await capture(page, "services", info.project.name); await next(page).click();
  await expect(page.locator(".booking-barber-card")).toHaveCount(2);
  await page.getByRole("radio", { name: /آرایشگر نمایشی الف/ }).check(); await capture(page, "barber", info.project.name); await next(page).click();
  const min = await page.locator(".booking-calendar").getAttribute("data-min-date") as LocalDate;
  await page.locator(`[data-date="${min}"]`).click(); await page.locator('[data-time="11:30"]').click();
  await expect(page.locator('[data-time="11:30"]')).toHaveAttribute("aria-pressed", "true"); await capture(page, "datetime", info.project.name); await next(page).click();
  await expect(page.getByTestId("booking-total-price")).toContainText("۱٬۰۰۰٬۰۰۰"); await expect(page.getByTestId("booking-total-duration")).toHaveText("۷۵ دقیقه فرضی");
  const policy = page.getByLabel("سناریوی سیاست نمایشی"); await policy.selectOption("demo-percent");
  await expect(page.getByTestId("policy-deposit")).toContainText("۲۰۰٬۰۰۰"); await expect(page.getByTestId("policy-remaining")).toContainText("۸۰۰٬۰۰۰");
  await expect(page.locator(".booking-policy")).toContainText("۲۴ ساعت"); await expect(page.locator(".booking-policy")).toContainText("۵۰٪");
  await page.getByRole("button", { name: "نمایش پیش‌نمایش نهایی" }).click(); await expect(page.locator(".booking-preview-result")).toBeFocused();
  await capture(page, "summary", info.project.name);
  await policy.selectOption("demo-optional"); await expect(page.locator(".booking-preview-result")).toHaveCount(0);
  await expect(page.getByTestId("policy-deposit")).toContainText("۰ تومان"); await page.getByRole("checkbox", { name: /فعال کردن بیعانه اختیاری/ }).check(); await expect(page.getByTestId("policy-deposit")).toContainText("۱۰۰٬۰۰۰");
  await policy.selectOption("demo-fixed"); await expect(page.locator(".booking-policy")).toContainText("غیرقابل‌استرداد");
  await policy.selectOption("demo-full"); await expect(page.locator(".booking-policy")).toContainText("بازگشت کامل");
  await policy.selectOption("demo-none"); await expect(page.getByTestId("policy-deposit")).toHaveText("۰ تومان");
  await page.getByRole("button", { name: "مرحله قبل", exact: true }).click(); await expect(page.locator('[data-time="11:30"]')).toHaveAttribute("aria-pressed", "true"); await next(page).click();
  await expect(page.getByTestId("booking-total-price")).toContainText("۱٬۰۰۰٬۰۰۰"); await health(page);
});

test("eligibility, upstream edits, empty dates and asynchronous invalidation remain consistent", async ({ page }, info) => {
  await openServices(page, "?service=hair"); await next(page).click(); await page.getByRole("radio", { name: /آرایشگر نمایشی الف/ }).check(); await next(page).click();
  const min = await page.locator(".booking-calendar").getAttribute("data-min-date") as LocalDate;
  await pickDateAndTime(page); await page.getByRole("button", { name: "ویرایش خدمات", exact: true }).click();
  await page.getByRole("checkbox", { name: /ماساژ/ }).check(); await next(page).click();
  await expect(page.getByRole("radio", { name: /آرایشگر نمایشی الف/ })).toHaveCount(0); await expect(page.locator('input[name="booking-barber"]:checked')).toHaveCount(0);
  await expect(page.locator(".booking-barber-card")).toHaveCount(1); await expect(page.getByRole("radio", { name: /آرایشگر نمایشی ج/ })).toHaveCount(0);
  await page.getByRole("radio", { name: /بدون ترجیح آرایشگر/ }).check(); await next(page).click(); await expect(page.locator(".booking-time-slots")).toBeVisible();
  await expect(page.locator('.booking-time-slots [aria-pressed="true"]')).toHaveCount(0); await next(page).click(); await expect(page.locator(".booking-panel").getByRole("alert")).toContainText("ساعت");
  await selectDate(page, addDays(min, 1)); await expect(page.getByText("در این روز زمان نمایشی وجود ندارد.", { exact: true })).toBeVisible(); await expect(page.locator(".booking-time-slots button")).toHaveCount(0);
  await capture(page, "no-availability", info.project.name); await next(page).click(); await step(page, "تاریخ و ساعت");
  await selectDate(page, min); await selectDate(page, addDays(min, 2)); await expect(page.locator('[data-time="11:30"]')).toBeVisible();
  await page.locator('[data-time="11:30"]').click(); await next(page).click(); await expect(page.locator(".booking-final-summary")).toContainText(formatJalali(addDays(min, 2), { year: "numeric", month: "long", day: "numeric" }));
  await page.getByRole("button", { name: "ویرایش شعبه", exact: true }).click(); await page.getByRole("button", { name: "پاک کردن انتخاب شعبه", exact: true }).click();
  await expect(page.locator(".booking-aside")).not.toContainText("11:30"); await next(page).click(); await expect(page.locator(".booking-panel").getByRole("alert")).toContainText("شعبه"); await health(page);
});

test("Jalali keyboard/month navigation, disabled dates and mobile target bounds", async ({ page }, info) => {
  await openCalendar(page);
  const calendar = page.locator(".booking-calendar"), min = await calendar.getAttribute("data-min-date") as LocalDate;
  await expect(calendar.locator('button[data-date]:disabled').first()).toBeDisabled();
  const first = calendar.locator(`[data-date="${min}"]`); await first.focus(); await page.keyboard.press("ArrowLeft");
  await expect(calendar.locator(`[data-date="${addDays(min, 1)}"]`)).toBeFocused(); await page.keyboard.press("ArrowRight"); await expect(first).toBeFocused();
  if (info.project.name.startsWith("mobile")) {
    const dayBounds = (await first.boundingBox())!, navBounds = (await page.locator(".booking-navigation").boundingBox())!;
    expect(dayBounds.y + dayBounds.height, "Focused day must clear the mobile action bar").toBeLessThanOrEqual(navBounds.y);
  }
  await page.keyboard.press("Enter"); await expect(first).toHaveAttribute("aria-pressed", "true");
  await page.keyboard.press("PageDown"); await expect(page.locator("#calendar-month")).toHaveText(formatJalali(shiftMonth(monthStart(min), 1), { year: "numeric", month: "long" }));
  await page.getByRole("button", { name: "ماه قبل", exact: true }).click(); await expect(page.locator("#calendar-month")).toHaveText(formatJalali(monthStart(min), { year: "numeric", month: "long" }));
  const smallDays = await calendar.locator('button[data-date]:enabled').evaluateAll(nodes => nodes.filter(n => { const r = n.getBoundingClientRect(); return r.width < 43.5 || r.height < 43.5; }).map(n => ({ text: n.textContent, width: n.getBoundingClientRect().width })));
  expect(smallDays, "Calendar day touch targets are at least 44px").toEqual([]);
  await capture(page, "calendar-keyboard", info.project.name);
  await page.setViewportSize({ width: 844, height: 390 }); await health(page);
});

test("server-rendered form cannot submit before hydration or without JavaScript", async ({ browser, baseURL }) => {
  const context = await browser.newContext({ javaScriptEnabled: false, baseURL });
  try {
    const page = await context.newPage();
    const response = await page.goto("/booking?service=hair");
    expect(response?.status()).toBe(200);
    await expect(next(page)).toBeDisabled();
    await expect(page.getByRole("radio", { name: /شعبه پونک/ })).toBeDisabled();
    // Verify the SSR fallback markup directly; noscript DOM text is parser-mode dependent.
    expect(await response!.text()).toContain("برای استفاده از پیش‌نمایش تعاملی، جاوااسکریپت مرورگر را فعال کنید.");
    await expect(page).toHaveURL(/\/booking\?service=hair$/);
  } finally { await context.close(); }
});
