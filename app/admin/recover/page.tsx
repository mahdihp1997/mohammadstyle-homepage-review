import {privateReviewAssets} from '@/lib/product/assets';
import AuthForm from '@/components/product/AuthForm';import '../login/login.css';import '../../product.css';
export const dynamic='force-dynamic';export const metadata={title:'بازیابی مدیریت | محمد استایل',robots:{index:false,follow:false}};
export default function Page(){return <AuthForm privateAssets={privateReviewAssets()} mode="recover" next="/admin"/>;}
