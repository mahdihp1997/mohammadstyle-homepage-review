import {NextRequest,NextResponse}from'next/server';
export function middleware(req:NextRequest){
 const privateAllowed=process.env.MS_PRIVATE_REVIEW_ASSETS==='1'&&process.env.NODE_ENV!=='production'&&process.env.MS_PRODUCT_ENABLED!=='1';
 const p=req.nextUrl.pathname;let imageUrl=req.nextUrl.searchParams.get('url')??'';
 try{imageUrl=decodeURIComponent(imageUrl);}catch{return new NextResponse(null,{status:400});}
 if(!privateAllowed&&(p.startsWith('/images/')||(p==='/_next/image'&&imageUrl.startsWith('/images/'))))return new NextResponse(null,{status:404,headers:{'Cache-Control':'no-store'}});
 const nonce=Buffer.from(crypto.randomUUID()).toString('base64'),development=process.env.NODE_ENV!=='production';
 // Inline styles support the approved range-control CSS variables; scripts require a per-request nonce.
 const csp=["default-src 'self'",`script-src 'self' 'nonce-${nonce}' 'strict-dynamic'${development?" 'unsafe-eval'":''}`,"style-src 'self' 'unsafe-inline'","img-src 'self' blob: data:","font-src 'self'","media-src 'self' blob:",`connect-src 'self'${development?' ws: wss:':''}`,"object-src 'none'","base-uri 'self'","form-action 'self'","frame-ancestors 'none'"].join('; ');
 const requestHeaders=new Headers(req.headers);requestHeaders.set('x-nonce',nonce);requestHeaders.set('Content-Security-Policy',csp);
 const res=NextResponse.next({request:{headers:requestHeaders}});res.headers.set('Content-Security-Policy',csp);res.headers.set('X-Content-Type-Options','nosniff');res.headers.set('Referrer-Policy','no-referrer');res.headers.set('X-Frame-Options','DENY');res.headers.set('Permissions-Policy','camera=(), microphone=(), geolocation=()');
 return res;
}
// Next middleware clones request bodies. APIs own their security headers and
// must reach the upload authorization gate before buffering a large payload.
export const config={matcher:['/((?!api/|_next/static|favicon.ico).*)']};
