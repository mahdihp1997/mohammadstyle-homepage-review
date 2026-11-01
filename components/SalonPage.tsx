import Link from "next/link";
import ShopLink from "@/components/shop/ShopLink";
import {productEnabled} from "@/lib/product/config";
import type { ReactNode } from "react";
import BrandMark from "@/components/BrandMark";
import Icon from "@/components/Icon";
import { business } from "@/data/site";

export default function SalonPage({ title, eyebrow, children }: { title: string; eyebrow: string; children: ReactNode }) {
  return <div className="salon-page"><header className="salon-header shell"><a href="/" className="brand"><BrandMark/><span className="brand-name">محمد استایل<span>MOHAMMAD STYLE</span></span></a><a className="btn btn-ghost" href="/booking"><Icon name="calendar" size={18}/>رزرو نوبت</a></header>
    <nav className="salon-nav shell" aria-label="صفحات مجموعه"><a href="/">خانه</a><Link href="/about">درباره ما</Link><Link href="/barbers">آرایشگران</Link><Link href="/portfolio">نمونه‌کارها</Link><Link href="/contact">تماس با ما</Link><Link href="/blog">مجله</Link>{productEnabled()&&<ShopLink/>}</nav>
    <main className="salon-main shell"><div className="salon-page-intro"><span className="section-eyebrow">{eyebrow}</span><h1>{title}</h1></div>{children}</main>
    <footer className="salon-footer shell"><a className="brand brand-small" href="/"><BrandMark/><span>محمد استایل</span></a><p>{business.location}</p><a href={business.instagram} target="_blank" rel="noopener noreferrer"><Icon name="instagram" size={20}/> @mohammadstyle1</a></footer>
  </div>;
}
