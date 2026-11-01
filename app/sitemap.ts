import type{MetadataRoute}from'next';import{publishedOrigin}from'@/lib/product/seo';
export const dynamic='force-dynamic';
export default function sitemap():MetadataRoute.Sitemap{const origin=publishedOrigin();return origin?[{url:origin+'/'},{url:origin+'/portfolio'}]:[];}
