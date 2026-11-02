"use client";
import Link from 'next/link';
import {usePathname} from 'next/navigation';
import {useRef,useState} from 'react';
import BrandMark from './BrandMark';
import Icon from './Icon';
import ShopLink from './shop/ShopLink';
import {business} from '@/data/site';

export default function SiteHeader({product=false,onBook}:{product?:boolean;onBook?:()=>void}) {
  const pathname=usePathname(),home=pathname==='/',[open,setOpen]=useState(false),button=useRef<HTMLButtonElement>(null);
  const links=[['خانه',home?'#home':'/'],['خدمات',home?'#services':'/#services'],['گالری تصاویر',home?'#portfolio':'/portfolio'],['شعبه‌ها',home?'#branches':'/#branches'],['درباره ما','/about'],['آرایشگران','/barbers'],['تماس با ما','/contact'],['مجله','/blog']];
  return <header className="site-header" onKeyDown={e=>{if(e.key==='Escape'&&open){setOpen(false);button.current?.focus();}}} onBlur={e=>{if(!e.currentTarget.contains(e.relatedTarget))setOpen(false);}}>
    <div className="header-inner shell">
      <a href={home?'#home':'/'} className="brand" aria-label="محمد استایل، صفحهٔ اصلی"><BrandMark/><span className="brand-name">محمد استایل<span>MOHAMMAD STYLE</span></span></a>
      <nav id="primary-nav" className={'main-nav'+(open?' nav-open':'')} aria-label="منوی اصلی">
        {links.map(([label,href])=><Link key={href} href={href} aria-current={pathname===href?'page':undefined} className={pathname===href?'current':undefined} onClick={()=>setOpen(false)}>{label}</Link>)}
        {product&&<ShopLink onClick={()=>setOpen(false)}/>}
      </nav>
      <div className="header-right">
        <a className="header-insta" href={business.instagram} target="_blank" rel="noopener noreferrer" aria-label="اینستاگرام محمد استایل"><Icon name="instagram" size={20}/></a>
        {onBook?<button className="btn btn-gold header-book" type="button" onClick={()=>{setOpen(false);onBook();}}><Icon name="calendar" size={17}/>رزرو نوبت</button>:<Link className="btn btn-gold header-book" href="/booking"><Icon name="calendar" size={17}/>رزرو نوبت</Link>}
        <button ref={button} className="menu-button" type="button" aria-label={open?'بستن منو':'باز کردن منو'} aria-controls="primary-nav" aria-expanded={open} onClick={()=>setOpen(!open)}><Icon name={open?'close':'menu'} size={23}/></button>
      </div>
    </div>
  </header>;
}
