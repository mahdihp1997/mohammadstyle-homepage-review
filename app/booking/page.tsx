import type { Metadata } from "next";
import BookingWizard from "@/components/booking/BookingWizard";
import ServerBookingWizard from "@/components/booking/ServerBookingWizard";
import { services } from "@/data/site";
import { localToday } from "@/lib/booking/date-utils";
import "./booking.css";
import "./server.css";

export const metadata: Metadata = { title: "پیش‌نمایش رزرو | محمد استایل", robots: { index: false, follow: false } };
export const dynamic = "force-dynamic";

export default async function BookingPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const query = await searchParams;
  if (query.mode === "server" && process.env.MS_BOOKING_SERVER_ENABLED === "1" && process.env.NODE_ENV !== "production") return <ServerBookingWizard />;
  const initialService = services.find(service => service.id === query.service)?.id ?? null;
  return <BookingWizard today={localToday("Asia/Tehran")} initialService={initialService} />;
}
