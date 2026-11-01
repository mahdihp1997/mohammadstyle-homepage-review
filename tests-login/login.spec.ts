import { test, expect, type Page } from "@playwright/test";
import fs from "node:fs";
import path from "node:path";

// Local secrets are read only by the runner. No trace, credential screenshots or storage-state export.
const source=fs.readFileSync("backend/.local/mvp/owner-login.txt","utf8");
const username=source.match(/^Username: (.+)$/m)![1], password=source.match(/^Password: (.+)$/m)![1];
const out=path.resolve("../../outputs/local-login-review");
async function form(page:Page){await page.goto('/admin/login');await expect(page.getByLabel('نام کاربری',{exact:true})).toBeEnabled();}
async function enter(page:Page){
  await page.getByLabel('نام کاربری',{exact:true}).fill(username);
  // Exercise a browser paste/input event without putting a real password in Playwright action logs.
  await page.evaluate(value=>{const field=document.querySelector<HTMLInputElement>('#login-password')!;
    Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value')!.set!.call(field,value);
    field.dispatchEvent(new Event('input',{bubbles:true}));},password);
  await page.getByRole('button',{name:'ورود به پنل',exact:true}).click();
  await expect(page).toHaveURL(/\/admin$/);await expect(page.locator('.admin-session')).toHaveText('نشست معتبر');
}
async function logout(page:Page){
  const menu=page.getByRole('button',{name:'منوی مدیریت',exact:true});if(await menu.isVisible())await menu.click();
  await page.getByRole('button',{name:'پایان نشست',exact:true}).click();
  await expect(page.locator('.admin-error')).toContainText('نشست این مرورگر پایان یافت');
}
test('RTL manual login form, keyboard, accessible labels and actual screenshots',async({page},info)=>{
  const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));
  await form(page);await page.evaluate(()=>document.fonts.ready);
  await expect(page.locator('html')).toHaveAttribute('dir','rtl');
  await expect(page.locator('form')).toHaveAttribute('method','post');
  await expect(page.getByLabel('نام کاربری',{exact:true})).toHaveAttribute('autocomplete','username');
  await expect(page.getByLabel('رمز عبور',{exact:true})).toHaveAttribute('autocomplete','current-password');
  await page.getByLabel('رمز عبور',{exact:true}).focus();await page.keyboard.press('Tab');
  await expect(page.getByRole('button',{name:'نمایش رمز',exact:true})).toBeFocused();
  await page.keyboard.press('Enter');await expect(page.getByLabel('رمز عبور',{exact:true})).toHaveAttribute('type','text');
  await page.getByRole('button',{name:'پنهان کردن',exact:true}).click();
  expect(await page.evaluate(()=>document.documentElement.scrollWidth-innerWidth)).toBe(0);
  await page.locator('.brand-mark').evaluate((n:HTMLImageElement)=>n.decode());
  fs.mkdirSync(out,{recursive:true});await page.screenshot({path:path.join(out,`login-${info.project.name}-fold.png`)});
  await page.screenshot({path:path.join(out,`login-${info.project.name}-full.png`),fullPage:true});expect(errors).toEqual([]);
});
test('manual login reaches authorized admin and logout clears only its cookie/session',async({page,context})=>{
  await form(page);await enter(page);
  const cookies=await context.cookies();const session=cookies.find(c=>c.name==='ms_session')!;
  expect(session.httpOnly).toBe(true);expect(session.sameSite).toBe('Strict');
  expect((await page.evaluate(()=>document.cookie)).includes('ms_session=')).toBe(false);
  await logout(page);await expect(page.getByRole('link',{name:'ورود به مدیریت',exact:true})).toBeVisible();
  expect((await context.cookies()).some(c=>c.name==='ms_session')).toBe(false);
  expect((await context.request.get('/api/mvp/session')).status()).toBe(401);
});
test('wrong credentials, cross-origin/CSRF, oversized body and forged context fail closed',async({page,context},info)=>{
  test.skip(info.project.name!=='desktop','Transport/security path is viewport independent');
  await form(page);await page.getByLabel('نام کاربری',{exact:true}).fill(username);
  await page.getByLabel('رمز عبور',{exact:true}).fill('incorrect-local-password');
  await page.getByRole('button',{name:'ورود به پنل',exact:true}).click();
  const alert=page.locator('.admin-login-card').getByRole('alert');
  await expect(alert).toHaveText('نام کاربری یا رمز عبور درست نیست.');await expect(alert).toBeFocused();
  expect((await context.cookies()).some(c=>c.name==='ms_session')).toBe(false);
  const endpoint='/api/local-review/login',origin='http://127.0.0.1:3000';
  expect((await context.request.post(endpoint,{headers:{origin},data:{username,password:'wrong'}})).status()).toBe(403);
  expect((await context.request.post(endpoint,{headers:{origin:'https://evil.example'},data:{username,password:'wrong'}})).status()).toBe(403);
  const csrfToken=(await (await context.request.get(endpoint)).json()).csrfToken;
  const headers={origin,'x-login-csrf':csrfToken};
  expect((await context.request.post(endpoint,{headers,data:{username,password:'wrong',userId:'forged'}})).status()).toBe(422);
  expect((await context.request.post(endpoint,{headers,data:{username,password:'x'.repeat(2100)}})).status()).toBe(413);
  expect((await context.cookies()).some(c=>c.name==='ms_session')).toBe(false);
});
test('two independent browser contexts keep separate sessions when one logs out',async({browser},info)=>{
  test.skip(info.project.name!=='desktop','Independent browser context proof needs one run');
  const a=await browser.newContext(),b=await browser.newContext();
  try{const pa=await a.newPage(),pb=await b.newPage();await form(pa);await enter(pa);await form(pb);await enter(pb);
    expect((await a.cookies()).find(c=>c.name==='ms_session')!.value === (await b.cookies()).find(c=>c.name==='ms_session')!.value).toBe(false);
    await logout(pa);const r=await b.request.get('http://127.0.0.1:3000/api/mvp/session');expect(r.status()).toBe(200);
    await pb.reload();await expect(pb.locator('.admin-session')).toHaveText('نشست معتبر');await logout(pb);
  }finally{await a.close();await b.close();}
});
test('without JavaScript no credential can be submitted through a GET URL',async({browser},info)=>{
  test.skip(info.project.name!=='desktop','SSR safety check');const c=await browser.newContext({javaScriptEnabled:false});
  try{const p=await c.newPage();await p.goto('http://127.0.0.1:3000/admin/login');await expect(p.getByLabel('نام کاربری',{exact:true})).toBeDisabled();await expect(p.getByRole('button',{name:'ورود به پنل',exact:true})).toBeDisabled();await expect(p.locator('form')).toHaveAttribute('method','post');}finally{await c.close();}
});
