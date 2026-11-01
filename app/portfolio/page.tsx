import PortfolioGallery from "@/components/portfolio/PortfolioGallery";
import { mvpEnabled } from "@/lib/mvp/proxy";
import "./portfolio.css";
import {publishedOrigin}from'@/lib/product/seo';
export const dynamic = "force-dynamic";
export function generateMetadata(){return{title:'گالری نمونه‌کارها | محمد استایل',...(publishedOrigin()?{alternates:{canonical:'/portfolio'}}:{})};}
export default function PortfolioPage() {
  return <PortfolioGallery enabled={mvpEnabled()} />;
}
