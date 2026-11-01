/** An explicit second local regression server lets the previous review remain
 * running. Both choices are fixed loopback origins; this is not a URL proxy. */
export function mvpReviewOrigin(env:Record<string,string|undefined>=process.env){
 return env.NODE_ENV==='development'&&env.MS_PRODUCT_ENABLED!=='1'&&env.MS_MVP_ENABLED==='1'&&env.MS_BOOKING_SERVER_PROFILE==='mvp-local'&&env.MS_LEGACY_REVIEW_PORTS==='1'
  ?'http://127.0.0.1:3172':'http://127.0.0.1:3112';
}
