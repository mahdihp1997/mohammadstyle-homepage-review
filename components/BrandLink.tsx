'use client';
import Link,{useLinkStatus} from 'next/link';
import type {ComponentProps} from 'react';
import BrandLoader from './BrandLoader';
function Pending(){const{pending}=useLinkStatus();return pending?<span className="page-navigation-feedback"><BrandLoader compact label="در حال باز کردن صفحه…"/></span>:null;}
export default function BrandLink({children,...props}:ComponentProps<typeof Link>){return <Link {...props}>{children}<Pending/></Link>;}
