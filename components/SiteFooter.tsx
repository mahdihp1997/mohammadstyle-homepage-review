import Link from 'next/link';
import BrandMark from './BrandMark';
import Icon from './Icon';
import ShopLink from './shop/ShopLink';
import {business} from '@/data/site';
import {team} from '@/data/salon';

export default function SiteFooter({product=false}:{product?:boolean}) {
  return <footer className="footer site-footer">
    <div className="shell footer-main">
      <div className="footer-brand"><a href="/" className="brand brand-small"><BrandMark/><span className="brand-name">محمد استایل<span>MOHAMMAD STYLE</span></span></a><p>آراستگی در جزئیات شکل می‌گیرد؛ از انتخاب مدل مو تا آخرین لحظهٔ آماده‌شدن.</p><a href={business.instagram} className="footer-social" target="_blank" rel="noopener noreferrer"><Icon name="instagram" size={20}/><bdi dir="ltr">@mohammadstyle1</bdi><span className="sr-only">در اینستاگرام، در پنجرهٔ جدید</span></a></div>
      <nav className="footer-links" aria-label="شناخت مجموعه"><span>محمد استایل</span><Link href="/about">درباره ما</Link><Link href="/barbers">آرایشگران مجموعه</Link><Link href="/portfolio">گالری تصاویر</Link><Link href="/blog">مجلهٔ آراستگی</Link><Link href="/contact">تماس با ما</Link></nav>
      <nav className="footer-links" aria-label="خدمات و حساب"><span>همراه شما</span><Link href="/#services">خدمات و تعرفه‌ها</Link><Link href="/#branches">پونک و فرشته</Link><Link href="/booking">رزرو نوبت</Link>{product&&<><Link href="/account">حساب و نوبت‌های من</Link><ShopLink/></>}</nav>
      <div className="footer-contact"><span>راه‌های ارتباط</span><p><Icon name="location" size={18}/>{business.location}</p>{team.filter(person=>person.phoneHref).map(person=><a key={person.id} href={person.phoneHref!}><Icon name="phone" size={17}/><span>{person.name}</span><bdi dir="ltr">{person.phone}</bdi></a>)}<Link href="/contact" className="footer-contact-more">نشانی و اطلاعات تماس</Link></div>
    </div>
    <div className="shell footer-bottom"><span>© محمد استایل — تمامی حقوق محفوظ است.</span><span>هیرکات، استایل و مراقبت تخصصی</span><a href="#page-top" aria-label="بازگشت به بالای صفحه">بازگشت به بالا ↑</a></div>
  </footer>;
}
