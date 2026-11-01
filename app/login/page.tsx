import {privateReviewAssets} from '@/lib/product/assets';
import type{Metadata}from'next';import AuthForm from '@/components/product/AuthForm';import '../admin/login/login.css';import '../product.css';
export const dynamic='force-dynamic';export const metadata:Metadata={title:'ورود به حساب | محمد استایل',robots:{index:false,follow:false}};
export default async function Page({searchParams}:{searchParams:Promise<{next?:string}>}){return <AuthForm privateAssets={privateReviewAssets()} next={(await searchParams).next}/>;}
