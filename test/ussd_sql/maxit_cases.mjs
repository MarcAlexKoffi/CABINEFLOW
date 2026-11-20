import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

export async function runMaxItCases({db,test,identity,rpc,denied,current,create,prepare}) {
  await identity('test-admin','postgres');
  const grantsSql="select p.oid::regprocedure::text name,p.proacl::text acl from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('private','public') and p.proname like '%ussd%' order by 1";
  const grants=(await db.query(grantsSql)).rows;
  const orders=(await db.query('select to_jsonb(o) row from public.phase4_assignment_orders o order by order_id')).rows;
  const gatesSql="select pg_get_functiondef('private.ussd_prepare(text,uuid,integer,jsonb,text)'::regprocedure) prepare,pg_get_functiondef('private.ussd_resolve(text)'::regprocedure) resolve";
  const gates=(await db.query(gatesSql)).rows;
  await db.exec(await readFile(new URL('../../supabase/migrations/20261119163850_ussd_maxit_command.sql',import.meta.url),'utf8'));
  await test('Max it migration preserves all RPC ACLs, orders and authorization/preparation functions',async()=>{
    assert.deepEqual((await db.query(grantsSql)).rows,grants);
    assert.deepEqual((await db.query('select to_jsonb(o) row from public.phase4_assignment_orders o order by order_id')).rows,orders);
    assert.deepEqual((await db.query(gatesSql)).rows,gates);
  });
  await test('SQL recognizes exact Max it aliases and rejects arbitrary app commands',async()=>{
    for(const command of ['MAXIT','APP:MAXIT',' app:maxit ','\u200BMAXIT\uFEFF']) {
      const row=(await db.query('select private.ussd_normalize_template($1) normalized,private.ussd_generate($1,null,null,null,null,null) command',[command])).rows[0];
      assert.deepEqual(row,{normalized:'APP:MAXIT',command:'APP:MAXIT'});
    }
    for(const command of ['APP:OTHER','APP:MAXIT;*123#','MAX IT','APP:MAXIT/{{amount}}'])
      await assert.rejects(()=>db.query('select private.ussd_template($1)',[command]),/invalid_template/);
    assert.equal((await db.query("select private.ussd_generate('*123#',null,null,null,null,null) code")).rows[0].code,'*123#');
  });
  await db.exec("update public.ussd_execution_rules set status='disabled' where deleted_at is null");
  await db.exec("insert into public.catalog_offers(id,network,service,operation_type,title) values('maxit-other-offer','orange','calls','callBundle','Autre offre Orange'); insert into public.phase4_assignment_orders values ('maxit-order','orange','callBundle',1000,'0707070707','Max it test','inProgress','confirmed','accepted','test-agent',null,'zone-a'),('maxit-other-order','orange','callBundle',1000,'0707070707','Autre offre','inProgress','confirmed','accepted','test-agent',null,'zone-a')");
  await identity('test-admin');
  const payload={network:'orange',service:'callBundle',offer_id:'synthetic-orange',ussd_template:'MAXIT'};
  let id;
  await test('same save/list API creates an associated, active canonical Max it rule',async()=>{
    id=await create(payload);
    const rule=await current(id);
    assert.equal(rule.ussd_template,'APP:MAXIT');assert.equal(rule.offer_id,'synthetic-orange');assert.equal(rule.status,'active');
    await create({network:'orange',service:'all',ussd_template:'*123#'});
  });
  await test('generic, non-Orange and balance Max it configurations are rejected',async()=>{
    for(const extra of [{offer_id:null},{network:'moov',offer_id:'synthetic-offer',service:'internetSubscription'},{purpose:'balance',service:null,offer_id:null}])
      await assert.rejects(()=>create({...payload,...extra}),e=>e.code==='23514');
    for(const uid of ['test-agent','test-manager','test-cabiniste','test-customer']) {
      await identity(uid);await denied(()=>create(payload));
    }
    await identity('test-admin');
  });
  await identity('test-manager');
  await rpc('register_order_context',['maxit-order','synthetic-orange']);
  await rpc('register_order_context',['maxit-other-order','maxit-other-offer']);
  await identity('test-agent');
  let resolved;
  await test('only associated offers resolve Max it; ordinary Orange offers keep explicit USSD',async()=>{
    resolved=await rpc('resolve',['maxit-order']);
    assert.equal(resolved.code,'APP:MAXIT');assert.equal(resolved.rule.id,id);
    assert.equal((await rpc('resolve',['maxit-other-order'])).code,'*123#');
  });
  await test('ownership, processing state and fresh context gates also protect Max it',async()=>{
    await identity('other-agent');await denied(()=>rpc('resolve',['maxit-order']));
    await identity(null);await denied(()=>rpc('resolve',['maxit-order']));
    await identity('test-admin','postgres');await db.exec("update public.phase4_assignment_orders set order_status='paidReady' where order_id='maxit-order'");
    await identity('test-agent');assert.equal((await rpc('resolve',['maxit-order'])).reason,'order_not_processable');
    await identity('test-admin','postgres');await db.exec("update public.phase4_assignment_orders set order_status='inProgress' where order_id='maxit-order'");
    await identity('test-agent');
    assert.equal((await prepare('maxit-order',{...resolved,context:{...resolved.context,amount:999}},'stale-maxit')).status,'unavailable');
  });
  await test('prepared Max it launch is audited idempotently without completing the order',async()=>{
    const prepared=await prepare('maxit-order',resolved,'maxit-open');
    assert.equal(prepared.code,'APP:MAXIT');assert.ok(prepared.attempt_id);
    assert.equal((await prepare('maxit-order',resolved,'maxit-open')).reason,'duplicate_attempt');
    await assert.rejects(()=>rpc('record_result',[prepared.attempt_id,'dialer_opened',null]),/invalid_status/);
    await rpc('record_result',[prepared.attempt_id,'app_opened',null]);
    await rpc('record_result',[prepared.attempt_id,'app_opened',null]);
    const ussd=await rpc('resolve',['maxit-other-order']);
    const normal=await prepare('maxit-other-order',ussd,'normal-ussd-open');
    await assert.rejects(()=>rpc('record_result',[normal.attempt_id,'app_opened',null]),/invalid_status/);
    await rpc('record_result',[normal.attempt_id,'dialer_opened',null]);
    await identity('other-agent');await assert.rejects(()=>rpc('record_result',[prepared.attempt_id,'app_opened',null]));
    await identity('test-admin','postgres');
    const order=(await db.query("select order_status from public.phase4_assignment_orders where order_id='maxit-order'")).rows[0];
    assert.equal(order.order_status,'inProgress');
    assert.equal((await db.query('select launch_status from public.ussd_execution_logs where id=$1',[prepared.attempt_id])).rows[0].launch_status,'app_opened');
  });
  await test('Max it uses existing versioning, draft editing, activation and deletion',async()=>{
    await identity('test-admin');
    let rule=await current(id);
    await rpc('save_rule',[id,rule.version,JSON.stringify({...payload,ussd_template:'APP:MAXIT',actor_scope:'both',priority:0,effective_from:'2020-01-01T00:00:00Z'})],['uuid','integer','jsonb']);
    rule=await current(id);assert.equal(rule.status,'draft');assert.equal(rule.version,2);
    await rpc('set_status',[id,rule.version,'active','Ouverture Max it vérifiée sur appareil de test']);
    rule=await current(id);assert.equal(rule.status,'active');
    await rpc('delete_rule',[id,rule.version]);
    assert.equal(await current(id),undefined);
  });
}
