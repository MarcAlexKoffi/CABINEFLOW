// Synthetic checkout snapshots only. No real order, dialer or payment call.
import assert from 'node:assert/strict';
import {readFile,readdir} from 'node:fs/promises';
import {join} from 'node:path';

export async function runWebShortcutCases({q,json,identity,note,root,offers,routes}) {
  await q(`alter table phase4_assignment_orders add source text default 'operatorApp',add order_reference text,add customer_auth_uid text,add catalog_snapshot jsonb;`);
  const migration=(await readdir(join(root,'supabase/migrations'))).find(n=>n.endsWith('_ussd_web_catalog_context.sql'));
  await q(await readFile(join(root,'supabase/migrations',migration),'utf8'));
  await identity('test-agent');
  let serial=0;
  async function checkout(offer,{order={},fields={},snapshot={}}={}) {
    const id=`web-shortcut-${++serial}`;
    const base={order_id:id,order_reference:`CF-SYNTHETIC-${serial}`,customer_auth_uid:'synthetic-customer',network:offer.network,
      operation_type:offer.operation_type,amount:offer.selling_price,beneficiary_phone:'+2250700000000',...order};
    const frozen={offer_id:offer.id,order_fields:{order_id:base.order_id,order_reference:base.order_reference,
      owner_firebase_uid:base.customer_auth_uid,network:base.network,operation_type:base.operation_type,
      amount:base.amount,beneficiary_phone:base.beneficiary_phone,is_custom_offer:false,offer_id:offer.id,
      service:base.operation_type==='callBundle'||base.operation_type==='mixedBundle'?'calls':'internetSubscription',...fields},...snapshot};
    await q(`insert into phase4_assignment_orders(order_id,order_reference,customer_auth_uid,source,network,operation_type,amount,beneficiary_phone,
      offer_label,order_status,payment_status,assignment_state,assigned_agent_id,zone_id,catalog_snapshot)
      values($1,$2,$3,$4,$5,$6,$7,$8,'Synthetic checkout','inProgress','confirmed','accepted','test-agent','zone-a',$9::jsonb)`,
      [base.order_id,base.order_reference,base.customer_auth_uid,order.source??'customerWeb',base.network,base.operation_type,base.amount,base.beneficiary_phone,JSON.stringify(frozen)]);
    return id;
  }
  const resolve=id=>json('select private.ussd_resolve_before_execution($1) v',[id]);
  const contextCount=()=>json('select count(*)::int v from ussd_order_contexts');
  const beforeContexts=await contextCount();
  let maxit=0;
  for(const offer of offers.filter(o=>o.is_active&&!o.deleted_at)) {
    const id=await checkout(offer);
    const row=await json('select to_jsonb(o) v from phase4_assignment_orders o where order_id=$1',[id]);
    const result=await resolve(id);
    assert.equal(result.status,'available',`${offer.offer_code}: ${result.reason}`);
    assert.equal(result.context.offer_id,offer.id);
    assert.equal(result.code,routes[offer.network][offer.category].replace('{{msisdn_local}}','0700000000'));
    if(result.code==='APP:MAXIT')maxit++;
    assert.deepEqual(await json('select to_jsonb(o) v from phase4_assignment_orders o where order_id=$1',[id]),row);
  }
  assert.equal(maxit,9);
  assert.equal(await contextCount(),beforeContexts);
  note('109 web checkouts resolve their exact configured route, including 9 Max it actions, without the optional context RPC or any order write');

  const historicalOffer=offers.find(o=>o.is_active&&!o.deleted_at&&o.selling_price>1);
  const historicalPrice=await checkout({...historicalOffer,selling_price:historicalOffer.selling_price-1});
  assert.equal((await resolve(historicalPrice)).status,'available');
  const cabiniste=await checkout(historicalOffer);
  const partner='00000000-0000-4000-8000-000000009951';
  await q("insert into partner_accounts(id,firebase_uid,status) values($1,'web-test-cabiniste','active')",[partner]);
  await q('update phase4_assignment_orders set assigned_agent_id=null,assigned_cabiniste_id=$1 where order_id=$2',[partner,cabiniste]);
  await identity('web-test-cabiniste');
  assert.equal((await resolve(cabiniste)).status,'available');
  await assert.rejects(()=>resolve(historicalPrice),e=>e.code==='42501');
  await identity('test-agent');
  note('frozen purchase prices survive later catalogue prices, and the Cabiniste owner can resolve only their own web checkout');

  for(const offer of offers.filter(o=>o.is_active&&!o.deleted_at&&o.category==='mixed'&&o.operation_type==='mixedBundle')) {
    const id=await checkout(offer,{order:{operation_type:'callBundle'}});
    const result=await resolve(id);
    assert.equal(result.status,'available',result.reason);
    assert.equal(result.context.commercial_category,'mixed');
    assert.equal(result.context.service,'callBundle');
    assert.equal((await json('select to_jsonb(o) v from phase4_assignment_orders o where order_id=$1',[id])).operation_type,'callBundle');
  }
  note('legacy web mixed bundles use the exact frozen offer identity without rewriting the historical order type or its finances');

  const offer=offers.find(o=>o.is_active&&!o.deleted_at&&o.network==='orange'&&o.category==='internet');
  const rejected=[
    {order:{source:'operatorApp'}},
    {fields:{order_id:'other-order'}},{fields:{order_reference:'other-reference'}},
    {fields:{owner_firebase_uid:'other-customer'}},{fields:{network:'mtn'}},
    {fields:{operation_type:'callBundle'}},{fields:{amount:offer.selling_price+1}},
    {fields:{beneficiary_phone:'0700000001'}},{fields:{beneficiary_phone:'invalid'}},
    {fields:{is_custom_offer:true}},{fields:{offer_id:'another-offer'}},
    {snapshot:{offer_id:null}},{snapshot:{order_fields:null}},
  ];
  for(const draft of rejected) {
    const id=await checkout(offer,draft);
    assert.equal((await resolve(id)).reason,'catalog_offer_required',JSON.stringify(draft));
  }
  const formatted=await checkout(offer,{fields:{beneficiary_phone:'07 00 00 00 00'}});
  assert.equal((await resolve(formatted)).status,'available');
  note('13 mismatched, custom or missing web snapshots stay blocked; valid local/international formatting is accepted');

  const first=await checkout(offer);
  const alternate=offers.find(o=>o.id!==offer.id&&o.is_active&&!o.deleted_at&&o.network===offer.network&&o.operation_type===offer.operation_type);
  await q("insert into ussd_order_contexts(order_id,offer_id,created_by) values($1,$2,'test-admin')",[first,alternate.id]);
  assert.equal((await resolve(first)).context.offer_id,alternate.id);
  const foreign=offers.find(o=>o.is_active&&!o.deleted_at&&o.network!=='orange');
  const wrongNetwork=await checkout(foreign,{order:{network:'orange'}});
  assert.equal((await resolve(wrongNetwork)).reason,'catalog_offer_mismatch');
  const wrongType=await checkout(offer,{order:{operation_type:'callBundle'}});
  assert.equal((await resolve(wrongType)).reason,'catalog_offer_mismatch');
  note('explicit staff associations retain priority and unrelated networks or operation types remain rejected');

  const gated=await checkout(offer);
  for(const change of ["order_status='paidReady'","order_status='onHold'","assignment_state='assigned'","payment_status='pending'"]) {
    await q(`update phase4_assignment_orders set order_status='inProgress',assignment_state='accepted',payment_status='confirmed' where order_id=$1`,[gated]);
    await q(`update phase4_assignment_orders set ${change} where order_id=$1`,[gated]);
    assert.equal((await resolve(gated)).reason,'order_not_processable');
  }
  await q("update phase4_assignment_orders set payment_status='confirmed' where order_id=$1",[gated]);
  await identity(null);
  await assert.rejects(()=>resolve(gated),e=>e.code==='42501');
  await identity('other-agent');
  await assert.rejects(()=>resolve(gated),e=>e.code==='42501');
  await identity('test-agent');
  assert.equal((await resolve(gated)).status,'available');
  assert.equal(await contextCount(),beforeContexts+1);
  note('ownership, authentication, accepted assignment, funded payment and processing status remain mandatory for web shortcuts');
  await q('reset role');
}
