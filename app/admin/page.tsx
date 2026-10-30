import AdminDashboard from "@/components/admin/AdminDashboard";
import { mvpEnabled } from "@/lib/mvp/proxy";
import "./admin.css";
export const dynamic = "force-dynamic";
export default async function AdminPage({
  searchParams,
}: {
  searchParams: Promise<{ view?: string }>;
}) {
  const view = (await searchParams).view;
  return mvpEnabled() ? (
    <AdminDashboard initialView={view} />
  ) : (
    <main className="admin-unavailable">
      <h1>پنل مدیریت</h1>
      <p>
        محیط یکپارچه‌سازی فعال نیست. این پنل در محیط تولید راه‌اندازی نشده است.
      </p>
      <a href="/">بازگشت به خانه</a>
    </main>
  );
}
