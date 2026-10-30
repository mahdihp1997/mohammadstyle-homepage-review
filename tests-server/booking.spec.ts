import fs from 'node:fs';
import path from 'node:path';
import { test, expect, type Page } from '@playwright/test';
const fixture = JSON.parse(fs.readFileSync('backend/.local/b4/ui-session.json', 'utf8')) as {
    day: string;
    optionalStaffName:string;nonPaymentStaffName:string;accounts: Record<string, {
        token: string;
        csrf: string;
    }>;
};
const folder = path.resolve('backend/.local/b4/ui');
fs.mkdirSync(folder, { recursive: true });
async function noOverflow(page: Page) { expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true); }
test('actual authenticated SERVER flow, exact consent, controlled reschedule and cancellation', async ({ page, context }, info) => {
    const identity = fixture.accounts[info.project.name], errors: string[] = [];
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', m => { if (m.type() === 'error')
        errors.push(m.text()); });
    await context.addCookies([{ name: 'ms_session', value: identity.token, domain: '127.0.0.1', path: '/', httpOnly: true, sameSite: 'Strict' }, { name: 'ms_csrf', value: identity.csrf, domain: '127.0.0.1', path: '/', sameSite: 'Strict' }]);
    await page.goto('/booking?mode=server');
    await page.locator('input[name="server-branch"]:enabled').first().check();
    await noOverflow(page);
    await page.screenshot({ path: path.join(folder, info.project.name + '-branch.png'), fullPage: true });
    await page.getByRole('button', { name: 'ادامه', exact: true }).click();
    for (const x of await page.locator('input[name="server-services"]').all())
        await x.check();
    await page.getByRole('button', { name: 'ادامه', exact: true }).click();
    if (info.project.name.startsWith('mobile'))
        await page.locator('input[name="server-staff"]').nth(1).check();
    await page.getByRole('button', { name: 'ادامه', exact: true }).click();
    await page.locator('button[data-date="' + fixture.day + '"]').click();
    await expect(page.locator('.booking-time-slots button').first()).toBeVisible({ timeout: 60000 });
    await page.locator('.booking-time-slots button').first().click();
    await noOverflow(page);
    await page.screenshot({ path: path.join(folder, info.project.name + '-availability-full.png'), fullPage: true });
    await page.evaluate(() => window.scrollTo(0, 0));
    await page.screenshot({ path: path.join(folder, info.project.name + '-availability-fold.png') });
    await page.getByRole('button', { name: 'ادامه', exact: true }).click();
    const accept = page.getByRole('checkbox', { name: 'شرایط و مبالغ همین پیشنهاد را خواندم و می‌پذیرم.' });
    await expect(accept).toBeVisible({ timeout: 60000 });
    await page.getByRole('button', { name: 'پذیرش و ثبت در محیط آزمایشی', exact: true }).click();
    await expect(page.locator('#booking-error')).toBeFocused();
    await expect(accept).not.toBeChecked();
    await accept.check();
    await noOverflow(page);
    await page.screenshot({ path: path.join(folder, info.project.name + '-terms.png'), fullPage: true });
    await page.getByRole('button', { name: 'پذیرش و ثبت در محیط آزمایشی', exact: true }).click();
    await expect(page.locator('.booking-preview-result h3')).toHaveText('رزرو تأییدشده در محیط آزمایشی', { timeout: 60000 });
    await page.screenshot({ path: path.join(folder, info.project.name + '-confirmed.png'), fullPage: true });
    await page.getByRole('button', { name: 'انتخاب زمان تازه', exact: true }).click();
    await page.locator('button[data-date="' + fixture.day + '"]').click();
    await expect(page.locator('.booking-time-slots button').nth(2)).toBeVisible({ timeout: 60000 });
    await page.locator('.booking-time-slots button').nth(2).click();
    await page.getByRole('button', { name: 'ادامه', exact: true }).click();
    await expect(accept).toBeVisible({ timeout: 60000 });
    await accept.check();
    await page.getByRole('button', { name: 'ثبت جابه‌جایی مجاز', exact: true }).click();
    await expect(page.locator('.booking-preview-result h3')).toHaveText('رزرو تأییدشده در محیط آزمایشی', { timeout: 60000 });
    await page.getByRole('button', { name: 'بررسی شرایط لغو', exact: true }).click();
    await expect(page.getByRole('button', { name: 'تأیید لغو همین رزرو', exact: true })).toBeVisible();
    await page.getByRole('button', { name: 'تأیید لغو همین رزرو', exact: true }).click();
    await expect(page.locator('.booking-preview-result h3')).toHaveText('لغوشده');
    await noOverflow(page);
    await page.screenshot({ path: path.join(folder, info.project.name + '-cancelled.png'), fullPage: true });
    expect(errors).toEqual([]);
    expect(await page.locator('img').evaluateAll(images => images.every(i => i instanceof HTMLImageElement && i.complete && i.naturalWidth > 0))).toBe(true);
});
test('missing authentication produces a focused recoverable message and leaves DEMO available', async ({ page }) => {
    await page.goto('/booking?mode=server');
    await expect(page.locator('#booking-error')).toContainText('نشست آزمایشی تأییدشده');
    await expect(page.locator('#booking-error')).toBeFocused();
    await page.getByRole('link', { name: 'بازگشت به DEMO' }).click();
    await expect(page.getByText('نسخه نمایشی؛ هیچ نوبتی ثبت نمی‌شود.', { exact: true })).toBeVisible();
});
test('changing provider clears an optional deposit choice and requires fresh consent under the new policy',async({page,context},info)=>{
 const identity=fixture.accounts[info.project.name];
 await context.addCookies([{name:'ms_session',value:identity.token,domain:'127.0.0.1',path:'/',httpOnly:true,sameSite:'Strict'},{name:'ms_csrf',value:identity.csrf,domain:'127.0.0.1',path:'/',sameSite:'Strict'}]);
 await page.goto('/booking?mode=server');await page.locator('input[name="server-branch"]:enabled').first().check();await page.getByRole('button',{name:'ادامه',exact:true}).click();for(const input of await page.locator('input[name="server-services"]').all())await input.check();await page.getByRole('button',{name:'ادامه',exact:true}).click();await page.getByRole('heading',{name:fixture.optionalStaffName,exact:true}).click();await page.getByRole('button',{name:'ادامه',exact:true}).click();await page.locator('button[data-date="'+fixture.day+'"]').click();await expect(page.locator('.booking-time-slots button').first()).toBeVisible({timeout:60000});await page.locator('.booking-time-slots button').first().click();await page.getByRole('button',{name:'ادامه',exact:true}).click();
 const optional=page.getByRole('checkbox',{name:/انتخاب بیعانه اختیاری/});await expect(optional).toBeVisible({timeout:60000});await optional.click();await expect(page.locator('.booking-time-slots button').first()).toBeVisible({timeout:60000});await page.locator('.booking-time-slots button').first().click();await page.getByRole('button',{name:'ادامه',exact:true}).click();await expect(optional).toBeChecked({timeout:60000});
 await page.getByRole('button',{name:/مرحله ۳: انتخاب آرایشگر/}).click();await page.getByRole('heading',{name:fixture.nonPaymentStaffName,exact:true}).click();await page.getByRole('button',{name:'ادامه',exact:true}).click();await expect(page.locator('.booking-time-slots button').first()).toBeVisible({timeout:60000});await page.locator('.booking-time-slots button').first().click();await page.getByRole('button',{name:'ادامه',exact:true}).click();await expect(page.getByText('بدون بیعانه',{exact:true})).toBeVisible({timeout:60000});await expect(optional).toHaveCount(0);await expect(page.getByRole('checkbox',{name:'شرایط و مبالغ همین پیشنهاد را خواندم و می‌پذیرم.'})).not.toBeChecked();await expect(page.locator('#booking-error')).toHaveCount(0);
});
