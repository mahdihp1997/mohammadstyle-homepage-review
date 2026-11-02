import SalonPage from "@/components/SalonPage";
import BrandMark from "@/components/BrandMark";
import CraftTools from "@/components/CraftTools";
import BarberPortrait from "@/components/BarberPortrait";
import { team, privateStaffPhotos, tomanLabel } from "@/data/salon";
import { privateReviewAssets } from "@/lib/product/assets";
export const dynamic = "force-dynamic";
export const metadata = { title: "آرایشگران مجموعه | محمد استایل" };
export default function BarbersPage() {
  const privateAssets = privateReviewAssets();
  return <SalonPage title="پشت هر استایل، یک نگاه دقیق." eyebrow="BEHIND THE CRAFT"><div className="barber-intro"><p>آرایشگران محمد استایل را بشناسید و برای انتخاب استایل خود در ارتباط باشید.</p><CraftTools/></div><section className="barber-team" aria-label="آرایشگران مجموعه">{team.map((person,i) => <article className="barber-card" key={person.id}>
    {privateAssets && privateStaffPhotos[person.id] ? <BarberPortrait name={person.name} {...privateStaffPhotos[person.id]}/> : <div className="barber-brand-portrait"><BrandMark/><span>MOHAMMAD STYLE</span></div>}
    <div className="barber-card-copy"><span className="section-eyebrow">0{i+1} / THE TEAM</span><h2>{person.name}</h2><p className="barber-price"><span>هیرکات مو</span><strong>{tomanLabel(person.haircut_price_toman)}</strong></p>{person.phoneHref ? <a className="btn btn-ghost" href={person.phoneHref}>تماس با {person.name}<span dir="ltr">{person.phone}</span></a> : <a className="btn btn-ghost" href="/booking">مشاهدهٔ خدمات و زمان‌ها</a>}</div>
  </article>)}</section><div className="barber-outro"><a className="btn btn-gold" href="/booking">انتخاب خدمت و زمان</a><a className="subtle-link" href="/portfolio">دیدن نمونه‌کارها</a></div></SalonPage>;
}
