import type{MetadataRoute}from'next';import{publishedOrigin}from'@/lib/product/seo';
export const dynamic='force-dynamic';
export default function robots():MetadataRoute.Robots{const origin=publishedOrigin();return origin?{rules:{userAgent:'*',allow:'/',disallow:['/admin','/account','/login','/booking','/api/']},sitemap:origin+'/sitemap.xml'}:{rules:{userAgent:'*',disallow:'/'}};}
