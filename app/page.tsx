import Homepage from "@/components/Homepage";
import {privateReviewAssets}from'@/lib/product/assets';
import {productEnabled}from'@/lib/product/config';
import {businessJsonLd,publishedOrigin}from'@/lib/product/seo';
export const dynamic='force-dynamic';
export function generateMetadata(){return publishedOrigin()?{alternates:{canonical:'/'}}:{};}
// JSON-LD is a non-executable data block. Framework scripts still require the CSP nonce.
export default function Page() { return <><script type="application/ld+json" dangerouslySetInnerHTML={{__html:JSON.stringify(businessJsonLd()).replace(/</g,'\\u003c')}}/><Homepage publicAssets={!privateReviewAssets()} product={productEnabled()}/></>; }
