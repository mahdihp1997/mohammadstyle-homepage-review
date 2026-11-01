"use client";
import Link from "next/link";

import { createContext, useContext, useCallback, useEffect, useRef, useState } from "react";
import ShopLink from '@/components/shop/ShopLink';
import BeforeAfterComparison from "@/components/BeforeAfter";
import ServiceMenu from '@/components/ServiceMenu';
import {listedServicePrice} from '@/data/salon';
import CinematicMedia from "@/components/CinematicMedia";
import CraftTools from "@/components/CraftTools";
import HomeGallery from '@/components/product/HomeGallery';
import Icon from "@/components/Icon";
import BrandMark from "@/components/BrandMark";
import { business, gallery, services, type GalleryCategory, type ServiceId } from "@/data/site";
const ProductContext=createContext({publicAssets:false,product:false});
function PublicArt(){return <div className="public-brand-art" aria-hidden="true"><BrandMark/><span>MOHAMMAD STYLE</span></div>;}

function Brand({ compact = false }: { compact?: boolean }) {
  return <a href="#home" className={`brand ${compact ? "brand-small" : ""}`} aria-label="محمد استایل، بازگشت به بالای صفحه">
    <BrandMark />
    <span className="brand-name">محمد استایل<span>MOHAMMAD STYLE</span></span>
  </a>;
}

function Header({ openBooking }: { openBooking: (id?: ServiceId) => void }) {
  const {product}=useContext(ProductContext);
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef<HTMLButtonElement>(null);
  const links = [ ["خانه","#home"], ["خدمات","#services"], ["نمونه‌کارها","#portfolio"], ["شعبه‌ها","#branches"], ["درباره ما","#about"] ];
  return <header className="site-header" onKeyDown={e=>{
    if(e.key==="Escape"&&menuOpen){e.preventDefault();setMenuOpen(false);menuRef.current?.focus();}
  }} onBlur={e=>{if(!e.currentTarget.contains(e.relatedTarget))setMenuOpen(false);}}>
    <div className="header-inner shell">
      <Brand />
      <nav id="primary-nav" className={`main-nav ${menuOpen ? "nav-open" : ""}`} aria-label="منوی اصلی">
        {links.map(([label,href],i)=><a key={href} className={i===0?"current":undefined} href={href} onClick={()=>setMenuOpen(false)}>{label}</a>)}
        <Link href="/blog" onClick={()=>setMenuOpen(false)}>مجله</Link>{product&&<ShopLink onClick={()=>setMenuOpen(false)}/>}
      </nav>
      <div className="header-right">
        <a className="header-insta" href={business.instagram} target="_blank" rel="noopener noreferrer" aria-label="اینستاگرام محمد استایل"><Icon name="instagram" size={20}/></a>
        <button className="btn btn-gold header-book" type="button" onClick={()=>{setMenuOpen(false);openBooking();}}><Icon name="calendar" size={17}/>رزرو نوبت</button>
        <button ref={menuRef} className="menu-button" type="button" aria-label={menuOpen?"بستن منو":"باز کردن منو"} aria-controls="primary-nav" aria-expanded={menuOpen} onClick={()=>setMenuOpen(!menuOpen)}><Icon name={menuOpen?"close":"menu"} size={23}/></button>
      </div>
    </div>
  </header>;
}

function Hero({ openBooking }: { openBooking: (id?: ServiceId) => void }) {
  const {publicAssets}=useContext(ProductContext);
  return <section className="hero" id="home" aria-labelledby="hero-heading">
    <div className="hero-grain" aria-hidden="true" />
    <div className="hero-grid shell">
      <div className="hero-photo" aria-label={publicAssets?'نشان محمد استایل':'نمونه واقعی از آماده‌سازی استایل دامادی'}>
        <CinematicMedia publicAssets={publicAssets} videoSrc="/images/owner-media/hero-at-work.mp4" posterSrc="/images/owner-media/salon-at-work-poster.webp"/>
        <div className="hero-photo-overlay" />
        <div className="hero-photo-corner" aria-hidden="true">THE ART OF GROOMING <span>MOHAMMAD STYLE</span></div>
      </div>
      <div className="hero-copy">
        <div className="eyebrow"><span className="eyebrow-line"/> MOHAMMAD STYLE — PREMIUM MEN'S GROOMING</div>
        <div className="hero-subline">سالن ممتاز پونک</div>
        <h1 id="hero-heading"><span className="hero-heading-line">فراتر از یک آرایشگاه،</span><br/>یک <span>سبک زندگی.</span></h1>
        <p className="hero-lead">از هیرکات دقیق تا استایل اختصاصی داماد؛ تجربه‌ای حرفه‌ای که در جزئیات آن تفاوت را احساس می‌کنید.</p>
        <div className="hero-ctas">
          <button className="btn btn-gold btn-large" type="button" onClick={()=>openBooking()}><Icon name="calendar" size={19}/> رزرو نوبت <Icon name="arrow" size={17}/></button>
          <a className="btn btn-ghost btn-large" href="#portfolio">مشاهده نمونه‌کارها <Icon name="arrow" size={18}/></a>
        </div>
        <div className="hero-stats" aria-label="ویژگی‌های مجموعه">
          <span><Icon name="location" size={17}/> دو شعبه فعال</span>
          <span><Icon name="crown" size={17}/> خدمات ویژه داماد</span>
        </div>
      </div>
    </div>
    <div className="hero-scroll shell"><span>SCROLL TO EXPLORE</span><a href="#services" aria-label="مشاهده خدمات"><Icon name="arrow" size={18}/></a></div>
  </section>;
}

function SectionIntro({ small, title, description, suffix, headingId }: { small: string; title: string; description?: string; suffix?: string; headingId?: string }) {
  return <div className="section-heading">
    <div><span className="section-eyebrow"><span className="gold-dot"/>{small}</span><h2 id={headingId}>{title}</h2></div>
    {description && <p>{description}</p>}
    {suffix && <span className="section-suffix">{suffix}</span>}
  </div>;
}

function Services({ openBooking }: { openBooking: (id?: ServiceId) => void }) {
  const {publicAssets}=useContext(ProductContext);
  return <section className="services-section section-space" id="services" aria-labelledby="services-heading">
    <div className="shell">
      <SectionIntro small="OUR SERVICES / 01" title="خدمات ما" headingId="services-heading" description="خدماتی برای آراستگی و استایل شخصی؛ از اصلاح روزمره تا آماده‌سازی برای لحظه‌های خاص." />
      <div className="service-grid">
        {services.map((s,i)=><button type="button" key={s.id} className={`service-card ${s.image && !publicAssets ? "photographic" : "illustrative"} service-${s.id}`} onClick={()=>openBooking(s.id)} aria-label={`اطلاعات و رزرو ${s.name}`}>
          {s.image&&!publicAssets?<img src={s.image} loading="lazy" alt={s.evidence || s.name}/>:<div className="service-art" aria-hidden="true"><span className="art-circle"/><Icon name={s.icon} size={76}/></div>}
          <span className="service-number">0{i+1}</span>
          <span className="service-card-content"><span className="service-icon"><Icon name={s.icon} size={25}/></span><strong>{s.name}</strong><small>{s.subtitle}</small><span className="service-menu-price">{listedServicePrice(s.id)}</span><span className="service-arrow"><Icon name="arrow" size={17}/></span></span>
        </button>)}
      </div>
      <ServiceMenu/>
    </div>
  </section>;
}

function BeforeAfter() {
  const {publicAssets}=useContext(ProductContext);
  if(publicAssets)return <section className="signature-section section-space" aria-labelledby="transformation-heading"><div className="shell signature-layout"><div className="signature-copy"><span className="section-eyebrow">THE TRANSFORMATION / 02</span><h2 id="transformation-heading">تغییر را<br/><em>احساس کنید.</em></h2><p>تصاویر قبل و بعد، پس از تأیید اجازهٔ انتشار در گالری مجموعه قرار می‌گیرند.</p><Link className="btn btn-ghost" href="/portfolio">مشاهدهٔ گالری</Link></div><div className="compare-frame public-media-empty"><PublicArt/><p>در انتظار تصاویر تأییدشدهٔ قبل و بعد</p></div></div></section>;
  return <section className="signature-section section-space" aria-labelledby="transformation-heading">
    <div className="shell signature-layout">
      <div className="signature-copy">
        <span className="section-eyebrow"><span className="gold-dot"/> THE TRANSFORMATION / 02</span>
        <span className="big-outline">01</span>
        <h2 id="transformation-heading">تغییر را<br/><em>احساس کنید.</em></h2>
        <p>نمونه‌ای از تغییر استایل در مجموعه؛ تصویر را جابه‌جا کنید و نتیجه قبل و بعد را ببینید.</p>
        <div className="signature-line" />
      </div>
      <BeforeAfterComparison/>
    </div>
  </section>;
}

function Portfolio() {
  const [filter,setFilter] = useState<GalleryCategory>("all");
  const filters: { id: GalleryCategory; name:string }[] = [{id:"all",name:"همه"},{id:"beforeafter",name:"قبل و بعد"},{id:"groom",name:"استایل دامادی"},{id:"behind",name:"پشت صحنه"}];
  const displayed=filter==="all"?gallery:gallery.filter(g=>g.category===filter);
  return <section className="portfolio-section section-space" id="portfolio" aria-labelledby="portfolio-heading">
    <div className="shell">
      <SectionIntro small="SELECTED WORK / 03" title="نمونه‌کارها" headingId="portfolio-heading" description="از ظرافت هیرکات تا استایل روز مراسم؛ کار ما را از نزدیک ببینید." />
      <div className="gallery-toolbar" role="group" aria-label="فیلتر نمونه‌کارها">
        {filters.map(f=><button key={f.id} type="button" className={f.id===filter?"active":""} aria-controls="portfolio-gallery" aria-pressed={f.id===filter} onClick={()=>setFilter(f.id)}>{f.name}</button>)}
      </div>
      <div id="portfolio-gallery" className={`gallery-grid gallery-filter-${filter} ${filter!=="all"?"gallery-grid-filtered":""}`}>
        {displayed.map(g=><figure className={`gallery-item gallery-item-${g.id} gallery-category-${g.category}`} key={g.id}>
          <img src={g.image} alt={g.alt} loading="lazy" />
          <figcaption><span>{g.type}</span><strong>{g.title}</strong></figcaption>
        </figure>)}
      </div>
      <p className="sr-only" role="status">{displayed.length} نمونه‌کار؛ {filters.find(f=>f.id===filter)?.name}</p>
      <div className="gallery-footer"><Link className="btn btn-ghost" href="/portfolio">همهٔ عکس‌ها و ویدئوها <Icon name="arrow" size={18}/></Link><a className="instagram-cta" href={business.instagram} target="_blank" rel="noopener noreferrer"><Icon name="instagram" size={26}/><span>نمونه‌های بیشتر در اینستاگرام<small dir="ltr">@mohammadstyle1</small></span><Icon name="arrowUp" size={20}/></a></div>
    </div>
  </section>;
}

function Story() {
  const {publicAssets}=useContext(ProductContext);
  return <section className="story-section" id="about" aria-labelledby="story-heading">
    <div className={`story-photo ${publicAssets?'':'story-photo-pair'}`}>{publicAssets?<PublicArt/>:<><img src="/images/barber-process.webp" alt="دقت آرایشگر در آماده‌سازی مو" loading="lazy"/><img src="/images/salon-light.webp" alt="آینه‌ها و فضای سالن محمد استایل" loading="lazy"/></>}</div>
    <div className="story-copy">
      <span className="section-eyebrow"><span className="gold-dot"/> INSIDE THE STUDIO</span>
      <h2 id="story-heading">هنر ما در<br/><em>جزئیات است.</em></h2>
      <p>از انتخاب مدل مو تا آخرین جزئیات آراستگی؛ هر استایل با توجه به چهره و سلیقهٔ شما شکل می‌گیرد.</p>
      <CraftTools/>
      <Link className="subtle-link" href="/about">دربارهٔ محمد استایل <Icon name="arrow" size={20}/></Link>
      <span className="story-accent" aria-hidden="true"><BrandMark/></span>
    </div>
  </section>;
}

function Branches({ openBooking }: { openBooking: (id?:ServiceId)=>void }) {
  const {publicAssets}=useContext(ProductContext);
  return <section className="branches-section section-space" id="branches" aria-labelledby="branches-heading">
    <div className="shell">
      <SectionIntro small="OUR LOCATIONS / 04" title="شعبه‌های محمد استایل" headingId="branches-heading" description="مجموعه دارای دو شعبه فعال است. اطلاعات شعبه دوم پس از تأیید به سایت اضافه می‌شود." />
      <div className="branches-grid">
        <article className="branch-tile branch-known">
          {publicAssets?<PublicArt/>:<img src="/images/salon-light.webp" alt="فضای سالن محمد استایل" loading="lazy" />}
          <div className="branch-overlay"/>
          <div className="branch-detail"><span className="branch-marker">01 / POUNAK</span><h3>شعبه پونک</h3><p><Icon name="location" size={18}/>{business.location}</p><button type="button" className="btn btn-gold" onClick={()=>openBooking()}>رزرو نوبت این شعبه <Icon name="arrow" size={17}/></button></div>
        </article>
        <article className="branch-tile branch-pending"><div className="branch-pattern" aria-hidden="true"/><div className="branch-detail"><span className="branch-marker">02 / در انتظار اطلاعات</span><h3>شعبه دوم</h3><p>نشانی، تصویر و خدمات شعبه دوم هنوز تأیید نشده‌اند.</p><span className="branch-disabled"><Icon name="clock" size={16}/> اطلاعات به‌زودی تکمیل می‌شود</span></div></article>
      </div>
    </div>
  </section>;
}

function Closing({ openBooking }: { openBooking: (id?:ServiceId)=>void }) {
  return <section className="closing-section"><div className="shell closing-inner"><div><span>MOHAMMAD STYLE</span><h2>استایل بعدی تو،<br/><em>از همین‌جا شروع می‌شود.</em></h2></div><button className="btn btn-gold btn-large" type="button" onClick={()=>openBooking()}><Icon name="calendar" size={18}/> رزرو نوبت <Icon name="arrow" size={18}/></button></div></section>;
}

function Footer() {
  const {product}=useContext(ProductContext);
  return <footer className="footer"><div className="shell footer-main"><div><Brand compact/><p>سالن ممتاز پونک؛ معرفی خدمات و نمونه‌کارهای آرایش و استایل مردانه.</p></div><div className="footer-links"><span>دسترسی سریع</span><a href="#services">خدمات</a><a href="#portfolio">نمونه‌کارها</a><a href="#branches">شعبه‌ها</a><Link href="/about">درباره ما</Link><Link href="/barbers">آرایشگران مجموعه</Link><Link href="/contact">تماس با ما</Link><Link href="/blog">مجلهٔ آراستگی</Link>{product&&<ShopLink/>}</div><div className="footer-contact"><span>نشانی سالن</span><p><Icon name="location" size={18}/>{business.location}</p><a href={business.instagram} target="_blank" rel="noopener noreferrer"><Icon name="instagram" size={19}/> @mohammadstyle1</a></div></div><div className="shell footer-bottom"><span>© محمد استایل</span><span>{product ? <a href="/account">حساب و نوبت‌های من</a> : 'پیش‌نمایش داخلی — رزرو و پرداخت هنوز فعال نیستند'}</span><a href="#home">بازگشت به بالا ↑</a></div></footer>;
}

function BookingDrawer({ open, selectedService, setSelectedService, close, returnFocusRef }: { open:boolean; selectedService:ServiceId|null; setSelectedService:(s:ServiceId)=>void; close:()=>void; returnFocusRef:{current:HTMLElement|null} }) {
  const {product}=useContext(ProductContext);
  const closeRef=useRef<HTMLButtonElement>(null);
  const drawerRef=useRef<HTMLElement>(null);
  useEffect(()=>{
    if(!open)return;
    const previous=returnFocusRef.current;
    const oldOverflow=document.body.style.overflow;
    document.body.style.overflow="hidden";
    const onKey=(e:KeyboardEvent)=>{
      if(e.key==="Escape")close();
      if(e.key==="Tab"){
        const items=Array.from(drawerRef.current?.querySelectorAll<HTMLElement>("button:not(:disabled), a[href], input:not(:disabled), [tabindex='0']")??[]);
        const first=items[0],last=items[items.length-1];
        if(!first||!last)return;
        if(e.shiftKey&&document.activeElement===first){e.preventDefault();last.focus();}
        else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first.focus();}
      }
    };
    closeRef.current?.focus(); window.addEventListener("keydown",onKey);
    return ()=>{document.body.style.overflow=oldOverflow;window.removeEventListener("keydown",onKey);previous?.focus();};
  },[open,close,returnFocusRef]);
  if(!open)return null;
  return <div className="drawer-layer" role="presentation"><div className="drawer-scrim" aria-hidden="true" onClick={close}/><section ref={drawerRef} className="drawer" role="dialog" aria-modal="true" aria-labelledby="booking-title" aria-describedby="booking-preview-note"><div className="drawer-head"><div><span>BOOKING PREVIEW</span><h2 id="booking-title">رزرو نوبت</h2></div><button ref={closeRef} className="drawer-close" type="button" aria-label="بستن" onClick={close}><Icon name="close" size={23}/></button></div>
    <div id="booking-preview-note" className="drawer-info">{product ? 'شعبه و خدمات را در مسیر رزرو انتخاب کنید. زمان، مبلغ و شرایط از سرور دریافت می‌شوند و پس از تأیید حساب بررسی می‌شوند.' : 'این بخش فقط پیش‌نمایش رزرو است. هیچ نوبتی ثبت نمی‌شود. مسیر مرحله‌ای نیز نمایشی است و پرداخت ندارد.'}</div>
    <a className="btn btn-gold drawer-booking-entry" href={selectedService ? `/booking?service=${selectedService}` : "/booking"}>{product ? 'شروع رزرو نوبت' : 'شروع رزرو مرحله‌ای نمایشی'} <Icon name="arrow" size={18}/></a>
    <div className="drawer-step"><span>01</span><strong>انتخاب شعبه</strong></div>
    <div className="drawer-branch selected"><Icon name="check" size={17}/><div><strong>شعبه پونک</strong><small>{business.location}</small></div></div>
    <div className="drawer-branch disabled"><Icon name="clock" size={17}/><div><strong>شعبه دوم</strong><small>اطلاعات و زمان‌بندی در انتظار تأیید</small></div></div>
    <div className="drawer-step"><span>02</span><strong>انتخاب خدمت</strong></div>
    <div className="drawer-services">{services.map(s=><button key={s.id} className={selectedService===s.id?"active":undefined} aria-pressed={selectedService===s.id} onClick={()=>setSelectedService(s.id)} type="button"><Icon name={s.icon} size={20}/>{s.name}</button>)}</div>
    <div className="drawer-next"><div><span>ثبت واقعی نوبت</span><p>{product ? 'برای مشاهدهٔ زمان‌های موجود و شرایط تأییدشده، مسیر رزرو را ادامه دهید.' : 'برای آزمایش انتخاب آرایشگر و زمان از مسیر نمایشی بالا استفاده کنید. ثبت واقعی و پرداخت همچنان فعال نیستند.'}</p></div>{product ? <a className="btn btn-gold" href="/booking">ادامهٔ رزرو</a> : <button className="btn btn-gold" type="button" disabled>ادامه رزرو (غیرفعال)</button>}</div>
  </section></div>;
}

export default function Homepage({publicAssets=false,product=false}:{publicAssets?:boolean;product?:boolean}) {
  const [drawerOpen,setDrawerOpen]=useState(false);
  const [selectedService,setSelectedService]=useState<ServiceId|null>(null);
  const returnFocusRef=useRef<HTMLElement|null>(null);
  const openBooking=useCallback((s?: ServiceId)=>{returnFocusRef.current=document.activeElement as HTMLElement|null;setSelectedService(s??null);setDrawerOpen(true);},[]);
  const closeBooking=useCallback(()=>setDrawerOpen(false),[]);
  return <ProductContext.Provider value={{publicAssets,product}}><div className="page-content" inert={drawerOpen}><a className="skip-link" href="#main-content">رفتن به محتوای اصلی</a><Header openBooking={openBooking}/><main id="main-content" tabIndex={-1}><Hero openBooking={openBooking}/><Services openBooking={openBooking}/><BeforeAfter/>{publicAssets?<HomeGallery/>:<Portfolio/>}<Story/><Branches openBooking={openBooking}/><Closing openBooking={openBooking}/></main><Footer/></div><BookingDrawer open={drawerOpen} selectedService={selectedService} setSelectedService={setSelectedService} close={closeBooking} returnFocusRef={returnFocusRef}/></ProductContext.Provider>;
}
