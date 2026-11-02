// Local transport simulation: no Google/Supabase request is sent.
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {stripTypeScriptTypes} from 'node:module';
const path=new URL('../functions/izytel-notification-dispatch/index.ts',import.meta.url);
let source=await readFile(path,'utf8');
source=source.replace(/import .*\n/g,'').replace('Deno.serve(async','globalThis.__handler = (async');
source+='\nexport { sendFcm };';
const module=await import('data:text/javascript;base64,'+Buffer.from(stripTypeScriptTypes(source)).toString('base64'));
const row={id:'n1',recipient_uid:'u1',event_type:'order_assigned',title:'Title',body:'Body',data:{orderId:'o1'},attempt_count:1,claimed_at:'lease1'};
let posted;
globalThis.fetch=async(_url,options)=>{posted=JSON.parse(options.body);return new Response('{}',{status:200});};
assert.equal((await module.sendFcm({project_id:'p'},'oauth','token',row)).ok,true);
assert.equal(posted.message.data.notificationId,'n1');
assert.equal(posted.message.android.notification.tag,'n1');
globalThis.fetch=async()=>new Response('{"error":{"status":"NOT_FOUND"}}',{status:404});
assert.equal((await module.sendFcm({project_id:'p'},'oauth','token',row)).invalidToken,false);
globalThis.fetch=async()=>new Response('{"error":{"details":[{"errorCode":"UNREGISTERED"}]}}',{status:404});
assert.equal((await module.sendFcm({project_id:'p'},'oauth','token',row)).invalidToken,true);

const keys=await crypto.subtle.generateKey({name:'RSASSA-PKCS1-v1_5',modulusLength:2048,publicExponent:new Uint8Array([1,0,1]),hash:'SHA-256'},true,['sign','verify']);
const pem='-----BEGIN PRIVATE KEY-----\n'+Buffer.from(await crypto.subtle.exportKey('pkcs8',keys.privateKey)).toString('base64')+'\n-----END PRIVATE KEY-----';
globalThis.Deno={env:{get:name=>({SUPABASE_URL:'https://local.invalid',SUPABASE_SERVICE_ROLE_KEY:'local',FIREBASE_SERVICE_ACCOUNT_JSON:JSON.stringify({project_id:'p',client_email:'test@example.invalid',private_key:pem})})[name]}};
const deliveries=[], devices=[{id:'d1',fcm_token:'token1'},{id:'d2',fcm_token:'token2'}];
let statusUpdate;
function query(table) {
 const q={action:'select',value:null,filters:[],select(){return q;},eq(k,v){q.filters.push([k,v]);return q;},maybeSingle(){return Promise.resolve({data:{id:'n1',dispatch_nonce:'nonce',status:'pending'}});},update(v){q.action='update';q.value=v;return q;},upsert(v){q.action='upsert';q.value=v;return q;},then(resolve){
  if(table==='izytel_notification_devices') resolve({data:devices});
  else if(table==='izytel_notification_deliveries' && q.action==='select') resolve({data:deliveries});
  else if(table==='izytel_notification_deliveries') {const i=deliveries.findIndex(x=>x.device_id===q.value.device_id);if(i<0)deliveries.push(q.value);else deliveries[i]=q.value;resolve({data:null});}
  else {statusUpdate=q.value;assert(q.filters.some(([k,v])=>k==='claimed_at'&&v==='lease1'));resolve({data:null});}
 }};return q;
}
globalThis.createClient=()=>({from:query,rpc:async()=>({data:[row]})});
const calls=[];
globalThis.fetch=async(url,options)=>{
 if(String(url).includes('oauth2')) return new Response('{"access_token":"oauth"}',{status:200});
 const body=JSON.parse(options.body);calls.push(body.message.token);
 return body.message.token==='token2'&&row.attempt_count===1?new Response('{"error":{"status":"UNAVAILABLE"}}',{status:503}):new Response('{}',{status:200});
};
const req=()=>new Request('https://local.invalid',{method:'POST',body:JSON.stringify({outboxId:'n1',nonce:'nonce'})});
await globalThis.__handler(req());
assert.equal(statusUpdate.status,'pending');assert.equal(deliveries[0].status,'sent');assert.equal(deliveries[1].status,'failed');
row.attempt_count=2;calls.length=0;
await globalThis.__handler(req());
assert.deepEqual(calls,['token2']);assert.equal(statusUpdate.status,'sent');
console.log('PASS FCM ID/tag, precise invalid-token classification, multi-device partial retry without replay of accepted device, lease guard');
