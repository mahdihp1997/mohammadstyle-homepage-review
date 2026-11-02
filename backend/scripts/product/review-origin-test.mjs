import assert from 'node:assert/strict';
import {mvpReviewOrigin} from '../../../lib/mvp/review-origin.ts';
const isolated={NODE_ENV:'development',MS_PRODUCT_ENABLED:'0',MS_MVP_ENABLED:'1',MS_BOOKING_SERVER_PROFILE:'mvp-local',MS_LEGACY_REVIEW_PORTS:'1'};
assert.equal(mvpReviewOrigin(isolated),'http://127.0.0.1:3172');
for(const override of [{NODE_ENV:'production'},{NODE_ENV:'test'},{MS_PRODUCT_ENABLED:'1'},{MS_MVP_ENABLED:'0'},{MS_BOOKING_SERVER_PROFILE:undefined},{MS_LEGACY_REVIEW_PORTS:undefined},{MS_LEGACY_REVIEW_PORTS:'https://example.invalid'}])assert.equal(mvpReviewOrigin({...isolated,...override}),'http://127.0.0.1:3112');
console.log(JSON.stringify({fixedOriginsOnly:true,productionCannotSelectAlternate:true,passed:8,failed:0}));
