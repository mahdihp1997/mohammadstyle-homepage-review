import CustomerOrdersPanel from '@/components/shop/CustomerOrdersPanel';
import '../../product.css';
import '../../shop/shop.css';
export const dynamic='force-dynamic';
export const metadata={title:'سفارش‌های من | محمد استایل',robots:{index:false,follow:false}};
export default function Page(){return <CustomerOrdersPanel/>;}
