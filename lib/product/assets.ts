// Private visual review is independent of Booking/auth mode. Explicit opt-in is
// allowed only in development; product review also requires the isolated origins.
export function privateReviewAssets(env:Record<string,string|undefined>=process.env){
 if(env.MS_PRIVATE_REVIEW_ASSETS!=='1'||env.NODE_ENV!=='development')return false;
 if(env.MS_PRODUCT_ENABLED!=='1')return true;
 return env.PRODUCT_ENV==='test'&&env.PUBLIC_ORIGIN==='http://127.0.0.1:3006'&&env.PRODUCT_API_ORIGIN==='http://127.0.0.1:3116';
}
