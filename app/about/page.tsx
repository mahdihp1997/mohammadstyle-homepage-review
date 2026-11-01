import SalonPage from "@/components/SalonPage";
import CraftTools from "@/components/CraftTools";
import BrandMark from "@/components/BrandMark";
import CinematicMedia from "@/components/CinematicMedia";
import { privateReviewAssets } from "@/lib/product/assets";
import { business, services } from "@/data/site";
export const dynamic = "force-dynamic";
export const metadata = { title: "درباره ما | محمد استایل" };
export default function AboutPage() {
  return <SalonPage title="آراستگی، با امضای شما." eyebrow="THE STUDIO"><section className="salon-editorial"><div className="salon-editorial-photo">{privateReviewAssets()?<img src="/images/salon-light.webp" alt="صندلی‌ها و آینه‌های سالن محمد استایل"/>:<BrandMark/>}</div><div className="salon-editorial-copy"><span className="section-eyebrow">MOHAMMAD STYLE</span><h2>محمد استایل<br/><em>سالن ممتاز پونک</em></h2><p>از اصلاح روزمره تا آماده‌سازی برای مراسم، خدمات مجموعه برای مراقبت و آراستگی شما در کنار هم قرار گرفته‌اند.</p><CraftTools/><p>{business.location}</p><a className="btn btn-gold" href="/booking">انتخاب خدمت و زمان</a></div></section><section className="studio-film" aria-labelledby="studio-film-heading"><CinematicMedia chapter publicAssets={!privateReviewAssets()} videoSrc="/images/owner-media/studio-tour-loop.mp4" posterSrc="/images/owner-media/salon-tour-poster.webp"/><div className="studio-film-shade"/><div className="studio-film-copy"><span className="section-eyebrow">A MOMENT IN THE STUDIO</span><h2 id="studio-film-heading">از نزدیک،<br/>در فضای محمد استایل.</h2><p>قاب‌هایی از سالن و جریان کار مجموعه.</p><a className="btn btn-ghost" href="/portfolio">تماشای فیلم‌های سالن ↗</a></div></section><section className="salon-services"><h2>خدمات مجموعه</h2><div>{services.map(s=><a key={s.id} href="/booking">{s.name}<span aria-hidden="true">↗</span></a>)}</div></section></SalonPage>;
}
