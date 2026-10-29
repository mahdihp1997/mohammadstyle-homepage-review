import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import "./globals.css";
import "./public-review.css";

export const metadata: Metadata = {
  title: "محمد استایل | سالن ممتاز پونک",
  description: "پیش‌نمایش داخلی طراحی وب‌سایت آرایشگاه مردانه محمد استایل: خدمات، نمونه‌کارها و معرفی شعبه پونک.",
  robots: { index: false, follow: false },
};
export const viewport: Viewport = { themeColor: "#0a0b0c", width: "device-width", initialScale: 1 };

export default function RootLayout({ children }: { children: ReactNode }) {
  return <html lang="fa" dir="rtl" data-public-review="true"><body><p className="public-review-notice">نسخه عمومی برای بررسی کد — تصاویر مشتریان با جای‌نگهدار جایگزین شده‌اند و فونت‌ها سیستمی‌اند. این نما برای تأیید بصری نسخه اصلی نیست.</p>{children}</body></html>;
}
