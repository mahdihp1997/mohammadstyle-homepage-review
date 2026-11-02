"use client";

import {useEffect, useRef, useState} from 'react';
import {usePathname} from 'next/navigation';
import Icon from './Icon';
import {team} from '@/data/salon';
import {business} from '@/data/site';

/** Contact shortcuts on public pages; never overlay checkout or account work. */
export default function FloatingContact() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const root = useRef<HTMLDivElement>(null), trigger = useRef<HTMLButtonElement>(null);
  const visible = ['/', '/about', '/barbers', '/portfolio', '/contact', '/blog', '/shop'].includes(pathname) || pathname.startsWith('/blog/');
  useEffect(() => {setOpen(false);}, [pathname]);
  useEffect(() => {
    if (!open) return;
    const outside = (e: globalThis.PointerEvent) => {if (!root.current?.contains(e.target as Node)) setOpen(false);};
    const escape = (e: KeyboardEvent) => {if (e.key === 'Escape') {setOpen(false); trigger.current?.focus();}};
    document.addEventListener('pointerdown', outside);
    document.addEventListener('keydown', escape);
    return () => {document.removeEventListener('pointerdown', outside); document.removeEventListener('keydown', escape);};
  }, [open]);
  if (!visible) return null;
  return <div ref={root} className="contact-float" onBlur={e => {if (!e.currentTarget.contains(e.relatedTarget as Node | null)) setOpen(false);}}>
    <button ref={trigger} className="contact-float-trigger" type="button" aria-expanded={open} aria-controls="quick-contact" onClick={() => setOpen(value => !value)}>
      <Icon name={open ? 'close' : 'phone'} size={22}/><span>{open ? 'بستن' : 'ارتباط با ما'}</span>
    </button>
    {open && <section id="quick-contact" className="contact-float-panel" aria-label="راه‌های ارتباط با محمد استایل">
      <div className="contact-float-heading"><strong>چطور همراهتان باشیم؟</strong><span>محمد استایل</span></div>
      {team.filter(person => person.phoneHref).map(person => <a key={person.id} href={person.phoneHref!}><Icon name="phone" size={19}/><span>تماس با {person.name}</span></a>)}
      <a href={business.instagram} target="_blank" rel="noopener noreferrer"><Icon name="instagram" size={19}/><span>اینستاگرام مجموعه<span className="sr-only">، در پنجرهٔ جدید</span></span></a>
      <a href="/contact"><Icon name="location" size={19}/><span>نشانی و راه‌های تماس</span></a>
      <a href="/booking" className="contact-float-book"><Icon name="calendar" size={19}/><span>رزرو نوبت</span></a>
    </section>}
  </div>;
}
