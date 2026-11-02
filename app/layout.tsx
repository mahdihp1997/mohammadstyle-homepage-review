import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import "./globals.css";
import './public-review.css';
import {siteMetadata}from'@/lib/product/seo';
import FloatingContact from '@/components/FloatingContact';
import NavigationFeedback from '@/components/NavigationFeedback';

export function generateMetadata():Metadata{return {...siteMetadata(),robots:{index:false,follow:false}};}
export const viewport: Viewport = { themeColor: "#0a0b0c", width: "device-width", initialScale: 1 };

export default function RootLayout({ children }: { children: ReactNode }) {
  return <html lang="fa" dir="rtl" data-public-review="true"><body id="page-top"><p className="public-review-notice">نسخه عمومی برای بررسی کد — رسانه‌های خصوصی حذف و تصاویر با جای‌نگهدار جایگزین شده‌اند؛ فونت‌ها سیستمی‌اند. این نما برای تأیید بصری نسخه اصلی نیست.</p>{children}<FloatingContact/><NavigationFeedback/></body></html>;
}
