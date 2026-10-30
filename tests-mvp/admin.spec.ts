import { createRequire } from "node:module";
import fs from "node:fs";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { test, expect, type Page, type BrowserContext } from "@playwright/test";
const fixture = JSON.parse(
    fs.readFileSync("backend/.local/mvp/review-session.json", "utf8"),
  ),
  folder = path.resolve("backend/.local/mvp/ui");
fs.mkdirSync(folder, { recursive: true });
async function login(context: BrowserContext, role = "owner") {
  const a = fixture.accounts[role];
  await context.addCookies([
    {
      name: "ms_session",
      value: a.token,
      domain: "127.0.0.1",
      path: "/",
      httpOnly: true,
      sameSite: "Strict",
    },
    {
      name: "ms_csrf",
      value: a.csrf,
      domain: "127.0.0.1",
      path: "/",
      sameSite: "Strict",
    },
  ]);
}
async function ready(page: Page) {
  await expect(page.locator(".admin-feedback")).not.toHaveText(
    "در حال دریافت دادهٔ مجاز از سرور…",
    { timeout: 40000 },
  );
  await expect(page.locator(".admin-error")).toHaveCount(0);
}
async function check(page: Page) {
  for (const image of await page.locator("img").all())
    await image.scrollIntoViewIfNeeded();
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth,
    ),
  ).toBe(true);
  await expect
    .poll(async () =>
      page
        .locator("img")
        .evaluateAll((imgs) =>
          imgs.every(
            (i) =>
              i instanceof HTMLImageElement && i.complete && i.naturalWidth > 0,
          ),
        ),
    )
    .toBe(true);
}
async function shot(page: Page, name: string) {
  await check(page);
  await page.screenshot({
    path: path.join(folder, name + "-full.png"),
    fullPage: true,
  });
  await page.evaluate(() => scrollTo(0, 0));
  await page.screenshot({ path: path.join(folder, name + "-fold.png") });
}
async function submit(page: Page, name = "ذخیره تغییرات") {
  const form = page.locator(".admin-editor");
  await form.getByRole("button", { name, exact: true }).click();
  await expect(form).toHaveCount(0);
  await ready(page);
}
async function api(page: Page, route: string, data: unknown, actor = "owner") {
  const a = fixture.accounts[actor];
  const r = await page.request.post(
    "/api/" +
      (route.startsWith("booking")
        ? "booking-server/commands/" + route.slice(8)
        : "mvp/" + route),
    {
      headers: {
        origin: "http://127.0.0.1:3000",
        "x-csrf-token": a.csrf,
        "idempotency-key": randomUUID(),
      },
      data,
    },
  );
  expect(r.ok(), await r.text()).toBe(true);
  return r.json();
}
test("all authorized panes render real API data, RTL, responsive navigation and actual screenshots", async ({
  page,
  context,
}, info) => {
  await login(context);
  const errors: string[] = [];
  page.on("pageerror", (e) => errors.push(e.message));
  for (const view of [
    "overview",
    "branches",
    "services",
    "prices",
    "policies",
    "staff",
    "schedule",
    "reservations",
    "media",
  ]) {
    await page.goto("/admin?view=" + view);
    await ready(page);
    await shot(page, info.project.name + "-admin-" + view);
    expect(await page.locator("html").getAttribute("dir")).toBe("rtl");
  }
  if (info.project.name.startsWith("mobile")) {
    const button = page.getByRole("button", {
      name: "منوی مدیریت",
      exact: true,
    });
    await button.click();
    const dialog = page.getByRole("dialog", { name: "ناوبری مدیریت" });
    await expect(dialog).toBeVisible();
    await expect(
      dialog.getByRole("button", { name: "بستن منوی مدیریت" }),
    ).toBeFocused();
    await page.keyboard.press("Shift+Tab");
    await expect(
      dialog.getByRole("link", { name: "محمد استایل مدیریت سالن" }),
    ).toBeFocused();
    await page.keyboard.press("Shift+Tab");
    await expect(
      dialog.getByRole("button", { name: "پایان نشست" }),
    ).toBeFocused();
    await page.keyboard.press("Escape");
    await expect(button).toBeFocused();
    await button.click();
    await dialog.getByRole("link", { name: "تقویم کاری", exact: true }).click();
    await ready(page);
    await expect(page.locator("#admin-content")).toBeFocused();
  }
  expect(errors).toEqual([]);
});
test("actual admin forms create branch, service, staff, configured price and a policy draft", async ({
  page,
  context,
}, info) => {
  test.skip(
    info.project.name !== "desktop",
    "One mutation scenario; all four sizes independently exercise CMS and reservations.",
  );
  await login(context);
  const tag = randomUUID().slice(0, 8);
  await page.goto("/admin?view=branches");
  await ready(page);
  await page.getByRole("button", { name: "افزودن شعبه", exact: true }).click();
  await page.getByLabel("کد شعبه").fill("UI_" + tag);
  await page.getByLabel("نام شعبه").fill("SYNTHETIC UI " + tag);
  await page.getByLabel("منطقهٔ زمانی IANA").fill("Asia/Tehran");
  await page.getByLabel("شعبه فعال است").check();
  await submit(page);
  await expect(
    page.getByRole("heading", { name: "SYNTHETIC UI " + tag }),
  ).toBeVisible();
  await page.goto("/admin?view=services");
  await ready(page);
  await page.getByRole("button", { name: "افزودن خدمت", exact: true }).click();
  await page.getByLabel("کد خدمت").fill("UI_" + tag);
  await page.getByLabel("نام خدمت").fill("SYNTHETIC service " + tag);
  await page.getByLabel("خدمت فعال است").check();
  await submit(page);
  await expect(
    page.getByRole("heading", { name: "SYNTHETIC service " + tag }),
  ).toBeVisible();
  await page.goto("/admin?view=staff");
  await ready(page);
  await page
    .getByRole("button", { name: "افزودن عضو تیم", exact: true })
    .click();
  await page.getByLabel("نام نمایشی").fill("SYNTHETIC staff " + tag);
  await submit(page);
  await expect(
    page.getByRole("heading", { name: "SYNTHETIC staff " + tag }),
  ).toBeVisible();
  await page.goto("/admin?view=prices");
  await ready(page);
  await page
    .getByRole("button", { name: "ویرایش تعرفه و زمان", exact: true })
    .first()
    .click();
  await page.getByLabel("قیمت به ریال").fill("120000");
  await submit(page);
  await expect(page.getByText("۱۲۰٬۰۰۰ ریال", { exact: true })).toBeVisible();
  await page.goto("/admin?view=policies");
  await ready(page);
  await page.getByRole("button", { name: "افزودن سیاست", exact: true }).click();
  await page.getByLabel("کد سیاست").fill("UI_" + tag);
  await page.getByLabel("نام سیاست").fill("SYNTHETIC policy " + tag);
  await page.getByLabel("محدودهٔ سیاست").selectOption("BRANCH");
  await submit(page);
  await expect(
    page.getByText("SYNTHETIC policy " + tag, { exact: true }),
  ).toBeVisible();
});
test("CMS manual upload, metadata, category, evidence, publish, gallery dialog and immediate revoke", async ({
  page,
  context,
}, info) => {
  await login(context);
  await page.goto("/admin?view=media");
  await ready(page);
  const run = randomUUID().slice(0, 8),
    fileName = "synthetic-" + info.project.name + "-" + run + ".png",
    title = "SYNTHETIC geometric fixture " + info.project.name + " " + run,
    category = "SYNTHETIC category " + info.project.name;
  await page.getByRole("button", { name: "افزودن دسته", exact: true }).click();
  await page.getByLabel("نام دسته").fill(category);
  await page
    .getByLabel("شناسهٔ انگلیسی دسته")
    .fill("ui-" + info.project.name + "-" + randomUUID().slice(0, 8));
  await page.getByLabel("دسته فعال است").check();
  await submit(page);
  const svg = Buffer.from(
    '<svg xmlns="http://www.w3.org/2000/svg" width="900" height="700"><rect width="900" height="700" fill="#151615"/><rect x="80" y="80" width="740" height="540" rx="40" fill="#242622" stroke="#c8a875" stroke-width="6"/><circle cx="450" cy="300" r="110" fill="#c8a875"/><path d="M210 530L450 410 690 530" fill="none" stroke="#c8a875" stroke-width="12"/><text x="450" y="650" text-anchor="middle" fill="#c8a875" font-family="sans-serif" font-size="28">SYNTHETIC TEST MEDIA</text></svg>',
  );
  // Test-only PNG generator. The production upload accepts raster magic, never SVG.
  const sharp = createRequire(path.resolve("backend/package.json"))("sharp");
  const png = await sharp(svg).png().toBuffer();
  await page
    .getByLabel("انتخاب عکس، ویدئو یا ZIP")
    .setInputFiles({ name: fileName, mimeType: "image/png", buffer: png });
  await page
    .getByRole("button", { name: "بارگذاری خصوصی", exact: true })
    .click();
  await expect(page.locator(".admin-feedback")).toContainText(
    "رسانه به‌صورت خصوصی ثبت شد",
    { timeout: 60000 },
  );
  await ready(page);
  let card = page.locator(".admin-media-card").filter({ hasText: fileName });
  await expect(card).toBeVisible();
  await expect(
    card.getByRole("button", { name: "انتشار عمومی", exact: true }),
  ).toBeDisabled();
  await card.getByRole("button", { name: "اطلاعات و دسته‌ها" }).click();
  await page.getByLabel("عنوان عمومی").fill(title);
  await page
    .getByLabel("متن جایگزین برای دسترسی‌پذیری")
    .fill("Synthetic geometry, no people or salon client");
  await page.getByRole("checkbox", { name: category, exact: true }).check();
  await submit(page);
  card = page.locator(".admin-media-card").filter({ hasText: title });
  await card.getByRole("button", { name: "ثبت یا تمدید حق استفاده" }).click();
  await page
    .getByLabel("مرجع مدرک حق استفاده")
    .fill(
      "SYNTHETIC_TEST_ONLY: generated geometric fixture; no recognizable people",
    );
  await page.getByRole("checkbox", { name: /حق استفادهٔ وب‌سایت/ }).check();
  await submit(page, "ثبت تأیید مجوز");
  await card.getByRole("button", { name: "انتشار عمومی", exact: true }).click();
  await page.getByRole("checkbox", { name: /عنوان، متن جایگزین/ }).check();
  await submit(page, "انتشار در گالری عمومی");
  await shot(page, info.project.name + "-cms-approved");
  const gallery = await context.newPage();
  await gallery.goto("/portfolio");
  await expect(
    gallery.getByRole("heading", { name: title, exact: true }),
  ).toBeVisible();
  await shot(gallery, info.project.name + "-portfolio");
  await gallery.getByRole("button", { name: category, exact: true }).click();
  await expect(
    gallery.getByRole("heading", { name: title, exact: true }),
  ).toBeVisible();
  const trigger = gallery.getByRole("button", { name: "نمایش کامل " + title });
  await trigger.click();
  await expect(gallery.getByRole("dialog")).toBeVisible();
  await shot(gallery, info.project.name + "-portfolio-detail");
  await gallery.keyboard.press("Escape");
  await expect(gallery.getByRole("dialog")).toHaveCount(0);
  await expect(trigger).toBeFocused();
  await gallery.getByRole("button", { name: "ویدئو", exact: true }).click();
  await expect(
    gallery.getByRole("heading", { name: title, exact: true }),
  ).toHaveCount(0);
  await card.getByRole("button", { name: "لغو تأیید حق استفاده" }).click();
  await page.getByLabel("مرجع و دلیل لغو").fill("SYNTHETIC UI revoke");
  await page.getByRole("checkbox", { name: /لغو مجوز/ }).check();
  await submit(page, "ثبت لغو مجوز");
  await gallery.reload();
  await expect(
    gallery.getByRole("heading", { name: title, exact: true }),
  ).toHaveCount(0);
  await gallery.close();
});
test("admin cancellation keeps accepted quote and shows immutable cancellation reason", async ({
  page,
  context,
  browser,
}, info) => {
  const customer = await browser.newContext({
    baseURL: "http://127.0.0.1:3000",
  });
  await login(customer, info.project.name);
  const c = await customer.newPage();
  const av = await api(
    c,
    "booking/availability",
    {
      branchId: fixture.branchId,
      offeringIds: fixture.offeringIds,
      staffId: null,
      date: fixture.day,
      optionalDepositChosen: false,
      rescheduleBookingId: null,
      cursor: "0",
    },
    info.project.name,
  );
  expect(av.slots.length).toBeGreaterThan(0);
  const q = await api(
      c,
      "booking/quote",
      { planId: av.slots[0].id },
      info.project.name,
    ),
    d = await api(
      c,
      "booking/draft",
      { branchId: fixture.branchId },
      info.project.name,
    ),
    held = await api(
      c,
      "booking/hold",
      {
        bookingId: d.id,
        version: d.version,
        quoteId: q.id,
        contentHash: q.contentHash,
        snapshotHash: q.content.policy.snapshotHash,
        accepted: true,
      },
      info.project.name,
    ),
    b = await api(
      c,
      "booking/confirm",
      { bookingId: held.id, version: held.version },
      info.project.name,
    );
  expect(b.status).toBe("CONFIRMED");
  await customer.close();
  await login(context);
  await page.goto("/admin?view=reservations");
  await ready(page);
  const row = page.locator('article[data-booking-id="' + b.id + '"]');
  await row.getByRole("button", { name: "جزئیات و سابقه" }).click();
  await page
    .getByRole("button", { name: "بررسی و لغو رزرو", exact: true })
    .click();
  await page
    .getByLabel("دلیل لغو توسط مدیر")
    .fill("SYNTHETIC UI cancellation " + info.project.name);
  await page
    .getByRole("checkbox", { name: /شرایط پذیرفته‌شده و آزاد شدن ظرفیت/ })
    .check();
  await submit(page);
  await row.getByRole("button", { name: "جزئیات و سابقه" }).click();
  await expect(page.locator(".admin-timeline")).toContainText(
    "SYNTHETIC UI cancellation " + info.project.name,
  );
  await shot(page, info.project.name + "-reservation-history");
});
test("missing authentication is focused, no admin mutation is exposed, DEMO remains available", async ({
  page,
}) => {
  await page.goto("/admin");
  await expect(page.locator(".admin-error")).toContainText(
    "نشست معتبر لازم است",
  );
  await expect(page.locator(".admin-error")).toBeFocused();
  await expect(
    page.getByRole("button", { name: "افزودن شعبه", exact: true }),
  ).toHaveCount(0);
  await page.goto("/booking");
  await expect(
    page.getByText("نسخه نمایشی؛ هیچ نوبتی ثبت نمی‌شود.", { exact: true }),
  ).toBeVisible();
});

test("ZIP upload creates private image/video, browser plays optimized approved video", async ({
  page,
  context,
}, info) => {
  test.skip(
    info.project.name !== "desktop",
    "Same ZIP/video path is covered by native integration and responsive final gallery captures.",
  );
  await login(context);
  await page.goto("/admin?view=media");
  await ready(page);
  await page
    .getByLabel("انتخاب عکس، ویدئو یا ZIP")
    .setInputFiles("backend/.local/mvp/ui-fixtures/synthetic-media.zip");
  await page
    .getByRole("button", { name: "بارگذاری خصوصی", exact: true })
    .click();
  await expect(page.locator(".admin-feedback")).toContainText(
    "۲ رسانه به‌صورت خصوصی ثبت شد",
    { timeout: 60000 },
  );
  await ready(page);
  const card = page
    .locator(".admin-media-card")
    .filter({ hasText: "synthetic-zip.mp4" })
    .first();
  await card.getByRole("button", { name: "پیش‌نمایش ویدئو" }).click();
  await expect
    .poll(() =>
      card.locator("video").evaluate((v: HTMLVideoElement) => v.readyState),
    )
    .toBeGreaterThanOrEqual(1);
  await card.getByRole("button", { name: "اطلاعات و دسته‌ها" }).click();
  await page.getByLabel("عنوان عمومی").fill("SYNTHETIC video — no clients");
  await page
    .getByLabel("متن جایگزین برای دسترسی‌پذیری")
    .fill("Synthetic color motion test pattern, no salon footage");
  await submit(page);
  await card.getByRole("button", { name: "ثبت یا تمدید حق استفاده" }).click();
  await page
    .getByLabel("مرجع مدرک حق استفاده")
    .fill("SYNTHETIC_TEST_ONLY — FFmpeg test pattern");
  await page.getByRole("checkbox", { name: /حق استفادهٔ وب‌سایت/ }).check();
  await submit(page, "ثبت تأیید مجوز");
  await card.getByRole("button", { name: "انتشار عمومی", exact: true }).click();
  await page.getByRole("checkbox", { name: /عنوان، متن جایگزین/ }).check();
  await submit(page, "انتشار در گالری عمومی");
  await page.goto("/portfolio");
  await expect(
    page.getByRole("heading", { name: "SYNTHETIC video — no clients" }),
  ).toBeVisible();
  const video = page.locator("video").first();
  await video.evaluate((v: HTMLVideoElement) => v.play());
  await expect
    .poll(() => video.evaluate((v: HTMLVideoElement) => v.currentTime))
    .toBeGreaterThan(0);
  expect(
    await video.evaluate((v: HTMLVideoElement) => v.videoWidth),
  ).toBeGreaterThan(0);
  await video.evaluate((v: HTMLVideoElement) => v.pause());
  await shot(page, "desktop-portfolio-video");
});
test("a media editor has no rights/publication/operational actions", async ({
  page,
  context,
}) => {
  await login(context, "editor");
  await page.goto("/admin?view=media");
  await ready(page);
  await expect(
    page.getByRole("button", { name: "بارگذاری خصوصی", exact: true }),
  ).toBeVisible();
  for (const name of ["افزودن شعبه", "ثبت یا تمدید حق استفاده", "انتشار عمومی"])
    await expect(page.getByRole("button", { name, exact: true })).toHaveCount(
      0,
    );
});

test("schedule UI records and reviews a real time-off request with calendar history", async ({
  page,
  context,
}, info) => {
  test.skip(
    info.project.name !== "desktop",
    "Calendar reads and responsive screenshots run at all four sizes.",
  );
  await login(context);
  await page.goto("/admin?view=schedule");
  await ready(page);
  await page.getByLabel("از تاریخ (میلادی)").fill(fixture.day);
  await ready(page);
  await page.getByRole("button", { name: "ثبت مرخصی", exact: true }).click();
  await page.getByLabel("عضو تیم").selectOption(fixture.staff[0].id);
  await page.getByLabel("شروع به وقت شعبه").fill(fixture.day + "T12:00");
  await page.getByLabel("پایان به وقت شعبه").fill(fixture.day + "T13:00");
  await page.getByLabel("دلیل").fill("SYNTHETIC UI time off");
  await submit(page);
  await page
    .getByRole("button", { name: "بررسی درخواست", exact: true })
    .last()
    .click();
  await page.getByLabel("نتیجهٔ بررسی").selectOption("false");
  await page
    .getByLabel("دلیل تصمیم")
    .fill("SYNTHETIC UI reject; no commercial action");
  await submit(page);
  await page.getByRole("checkbox", { name: "نمایش سابقهٔ تقویم" }).check();
  await ready(page);
  await expect(page.getByText("رد شده", { exact: true })).toBeVisible();
  await shot(page, "desktop-schedule-history");
});
