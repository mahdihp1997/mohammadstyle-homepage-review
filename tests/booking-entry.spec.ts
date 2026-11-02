import {test,expect} from '@playwright/test';
import {bookingEntryServices,bookingEntryHref,bookingEntryOfferings} from '../lib/booking/entry';
import {initialBookingState} from '../lib/booking/state';
import type {ServerOffering} from '../types/booking-server';

test('entry accepts multiple known services and retains the existing single-service URL',()=>{
 expect(bookingEntryHref(['hair'])).toBe('/booking?service=hair');
 expect(bookingEntryHref(['facial','hair','hair'])).toBe('/booking?service=hair&service=facial');
 expect(bookingEntryServices(['facial','forged','hair','hair'])).toEqual(['hair','facial']);
 expect(bookingEntryServices('hair,facial')).toEqual(['hair','facial']);
 expect(bookingEntryServices(['unknown',undefined,{}])).toEqual([]);
 expect(initialBookingState(['hair','facial']).draft.serviceIds).toEqual(['hair','facial']);
});
test('server preselection uses only unambiguous offerings from the selected branch',()=>{
 const offering=(id:string,branchId:string,name:string):ServerOffering=>({id,branchId,name,serviceId:'server-'+id,priceRial:'1000000',durationMinutes:'30',version:'1'});
 const catalog=[offering('hair-a','a','هیرکات مو'),offering('facial-a','a','فیشیال صورت'),offering('hair-b','b','هیرکات مو')];
 expect(bookingEntryOfferings(catalog,'a',['hair','facial'])).toEqual(['hair-a','facial-a']);
 expect(bookingEntryOfferings(catalog,'b',['hair','facial'])).toEqual(['hair-b']);
 expect(bookingEntryOfferings([...catalog,offering('duplicate','a','هیرکات مو')],'a',['hair','facial'])).toEqual(['facial-a']);
 expect(bookingEntryOfferings(catalog,'forged',['hair'])).toEqual([]);
});
test('drawer toggles two services and both survive the real DEMO handoff',async({page})=>{
 await page.goto('/');await page.locator('.header-book').click();const dialog=page.getByRole('dialog');
 const hair=dialog.getByRole('button',{name:'هیرکات مو',exact:true}),facial=dialog.getByRole('button',{name:'فیشیال صورت',exact:true});
 await hair.click();await facial.click();await expect(hair).toHaveAttribute('aria-pressed','true');await expect(facial).toHaveAttribute('aria-pressed','true');
 await facial.click();await expect(facial).toHaveAttribute('aria-pressed','false');await facial.click();
 const entry=dialog.locator('.drawer-booking-entry');await expect(entry).toHaveAttribute('href','/booking?service=hair&service=facial');await entry.click();
  await page.getByRole('radio',{name:/شعبه پونک/}).check();await page.getByRole('button',{name:'مرحله بعد',exact:true}).click();
 await expect(page.getByRole('checkbox',{name:/هیرکات مو/})).toBeChecked();await expect(page.getByRole('checkbox',{name:/فیشیال صورت/})).toBeChecked();
});
