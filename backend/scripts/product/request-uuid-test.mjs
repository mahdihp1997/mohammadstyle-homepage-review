import assert from'node:assert/strict';import{webcrypto}from'node:crypto';import{requestUuid}from'../../../lib/request-uuid.ts';
const format=/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/;let passed=0;
function test(name,fn){fn();passed++;console.log('PASS '+name);}
test('Native UUID path remains unchanged',()=>{const expected=webcrypto.randomUUID();assert.equal(requestUuid({randomUUID:()=>expected,getRandomValues:()=>{throw Error('Unexpected fallback');}}),expected);});
test('HTTP-compatible source receives exactly sixteen bytes and preserves UUID version/variant',()=>{let calls=0;const id=requestUuid({getRandomValues:bytes=>{calls++;assert.ok(bytes instanceof Uint8Array);assert.equal(bytes.length,16);bytes.fill(255);return bytes;}});assert.equal(id,'ffffffff-ffff-4fff-bfff-ffffffffffff');assert.equal(calls,1);assert.match(id,format);});
test('Cryptographic fallback produces distinct well-formed v4 identifiers',()=>{const source={getRandomValues:webcrypto.getRandomValues.bind(webcrypto)},values=Array.from({length:512},()=>requestUuid(source));assert.equal(new Set(values).size,512);values.forEach(id=>assert.match(id,format));});
test('No insecure fallback exists when cryptographic randomness is unavailable',()=>{assert.throws(()=>requestUuid({}),/Secure random generator is unavailable/);});
test('A failed cryptographic source is not replaced by weaker randomness',()=>{assert.throws(()=>requestUuid({getRandomValues:()=>{throw Error('CSPRNG failure');}}),/CSPRNG failure/);});
console.log(JSON.stringify({passed,failed:0}));
