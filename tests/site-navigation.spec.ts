import {test,expect} from '@playwright/test';

test('company pages remain reachable from the sticky main navigation',async({page})=>{
  await page.goto('/');
  const menu=page.getByRole('button',{name:'باز کردن منو',exact:true});
  if(await menu.isVisible())await menu.click();
  const nav=page.getByRole('navigation',{name:'منوی اصلی',exact:true});
  for(const href of ['/about','/barbers','/contact'])await expect(nav.locator(`a[href="${href}"]`)).toBeVisible();
  if(await page.locator('.menu-button').isVisible())await page.keyboard.press('Escape');
  await page.evaluate(()=>window.scrollTo(0,800));
  const header=await page.locator('.site-header').boundingBox();
  expect(header!.y).toBe(0);
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
});

test('contact shortcuts support keyboard dismissal and stay out of the booking drawer',async({page})=>{
  await page.goto('/contact');
  const numbers=page.locator('.contact-phone');
  await expect(numbers).toHaveCount(2);
  expect(await numbers.first().evaluate(e=>getComputedStyle(e).fontFamily.toLowerCase())).not.toMatch(/georgia|times new roman/);
  await expect(page.locator('.contact-person').first()).toHaveAttribute('href','tel:+989128935598');
  const trigger=page.getByRole('button',{name:'ارتباط با ما',exact:true});
  await trigger.focus();await page.keyboard.press('Enter');
  await expect(page.getByRole('region',{name:'راه‌های ارتباط با محمد استایل'})).toBeVisible();
  await expect(page.getByRole('link',{name:'تماس با امیر',exact:true})).toHaveAttribute('href','tel:+989387556252');
  await page.keyboard.press('Escape');await expect(trigger).toBeFocused();await expect(trigger).toHaveAttribute('aria-expanded','false');
  await page.goto('/');await page.locator('.header-book').click();
  await expect(page.getByRole('dialog')).toBeVisible();await expect(page.locator('.contact-float')).toBeHidden();
  await page.keyboard.press('Escape');await expect(page.locator('.contact-float')).toBeVisible();
});

