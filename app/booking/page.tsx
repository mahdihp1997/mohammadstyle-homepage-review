import type { Metadata } from "next";
import BookingWizard from "@/components/booking/BookingWizard";
import ServerBookingWizard from "@/components/booking/ServerBookingWizard";
import {bookingEntryServices} from '@/lib/booking/entry';
import { localToday } from "@/lib/booking/date-utils";
import "./booking.css";
import "./server.css";
import '../product.css';
import {productEnabled} from '@/lib/product/config';

export function generateMetadata():Metadata{return{title:productEnabled()?'رزرو نوبت | محمد استایل':'پیش‌نمایش رزرو | محمد استایل',robots:{index:false,follow:false}};}
export const dynamic = "force-dynamic";

export default async function BookingPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const query = await searchParams;
  const initialServiceIds=bookingEntryServices(query.service);
  if (productEnabled() && !(query.mode === 'demo' && process.env.PRODUCT_ENV === 'test' && process.env.NODE_ENV !== 'production')) return <ServerBookingWizard product initialServiceIds={initialServiceIds} rescheduleId={typeof query.reschedule === 'string' && /^[a-f0-9-]{36}$/.test(query.reschedule) ? query.reschedule : null}/>;
  if (query.mode === "server" && process.env.MS_BOOKING_SERVER_ENABLED === "1" && process.env.NODE_ENV !== "production") return <ServerBookingWizard initialServiceIds={initialServiceIds}/>;
  return <BookingWizard today={localToday("Asia/Tehran")} initialService={initialServiceIds[0]??null} initialServiceIds={initialServiceIds} />;
}
