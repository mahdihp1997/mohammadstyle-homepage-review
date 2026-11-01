import type { Metadata } from "next";
import AdminLogin from "@/components/admin/AdminLogin";
import { localLoginBridge } from "@/lib/mvp/local-login";
import {productEnabled} from '@/lib/product/config';
import AuthForm from '@/components/product/AuthForm';
import '../../product.css';
import "./login.css";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "ورود مدیریت | محمد استایل", robots: { index: false, follow: false } };
export default async function LoginPage({searchParams}:{searchParams:Promise<{enroll?:string;next?:string}>}) { const query=await searchParams;return productEnabled()?<AuthForm mode="admin" next={query.next??"/admin"} enrollMfa={query.enroll==="1"}/>:<AdminLogin enabled={!!localLoginBridge()} />; }
