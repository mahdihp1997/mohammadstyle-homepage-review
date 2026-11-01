import assert from'node:assert/strict';
import {privateReviewAssets}from'../../../lib/product/assets.ts';
const local={NODE_ENV:'development',MS_PRIVATE_REVIEW_ASSETS:'1',MS_PRODUCT_ENABLED:'1',PRODUCT_ENV:'test',PUBLIC_ORIGIN:'http://127.0.0.1:3006',PRODUCT_API_ORIGIN:'http://127.0.0.1:3116'};
const cases=[
 ['Explicit isolated product review retains private imagery/fonts',local,true],
 ['Legacy internal visual review remains available',{NODE_ENV:'development',MS_PRIVATE_REVIEW_ASSETS:'1'},true],
 ['Default product preview omits private assets',{...local,MS_PRIVATE_REVIEW_ASSETS:undefined},false],
 ['Production Node cannot opt into private assets',{...local,NODE_ENV:'production'},false],
 ['Other Node test tools cannot expose private assets',{...local,NODE_ENV:'test'},false],
 ['Staging product cannot opt into private assets',{...local,PRODUCT_ENV:'staging'},false],
 ['Production product cannot opt into private assets',{...local,PRODUCT_ENV:'production'},false],
 ['A non-loopback public origin cannot use the private review',{...local,PUBLIC_ORIGIN:'https://example.invalid'},false],
 ['A different upstream cannot use the private review',{...local,PRODUCT_API_ORIGIN:'http://api:3116'},false],
 ['The flag must be explicit',{...local,MS_PRIVATE_REVIEW_ASSETS:'0'},false],
];
for(const[name,env,expected]of cases){assert.equal(privateReviewAssets(env),expected,name);console.log('PASS '+name);}
console.log(JSON.stringify({passed:cases.length,failed:0}));
