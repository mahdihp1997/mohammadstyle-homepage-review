export function privateReviewAssets(){return process.env.MS_PRIVATE_REVIEW_ASSETS==='1'&&process.env.NODE_ENV!=='production'&&process.env.MS_PRODUCT_ENABLED!=='1';}
