import SiteHeader from "./SiteHeader";
import SiteFooter from "./SiteFooter";
import {productEnabled} from "@/lib/product/config";
import type { ReactNode } from "react";

export default function SalonPage({ title, eyebrow, children }: { title: string; eyebrow: string; children: ReactNode }) {
  return <div className="salon-page"><SiteHeader product={productEnabled()}/>
    <main className="salon-main shell"><div className="salon-page-intro"><span className="section-eyebrow">{eyebrow}</span><h1>{title}</h1></div>{children}</main>
    <SiteFooter product={productEnabled()}/>
  </div>;
}
