import type { ReactNode } from 'react';
import AdminTheme from '@/components/admin/AdminTheme';
import './theme.css';
export const metadata={robots:{index:false,follow:false}};
export default function Layout({children}:{children:ReactNode}){return <AdminTheme>{children}</AdminTheme>;}
