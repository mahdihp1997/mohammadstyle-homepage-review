import PortfolioGallery from "@/components/portfolio/PortfolioGallery";
import { mvpEnabled } from "@/lib/mvp/proxy";
import "./portfolio.css";
export const dynamic = "force-dynamic";
export default function PortfolioPage() {
  return <PortfolioGallery enabled={mvpEnabled()} />;
}
