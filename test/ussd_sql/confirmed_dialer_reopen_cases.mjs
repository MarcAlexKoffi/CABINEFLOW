import assert from 'node:assert/strict';
import {readFile,readdir} from 'node:fs/promises';

export async function runConfirmedDialerReopenCases({db,test,identity,rpc,denied,current,create,prepare}) {
  const admin=()=>identity('test-admin','postgres');
  const key='a'.repeat(64),order='confirmed-dialer',appOrder='confirmed-app';
  const session=async (uid='test-agent',device=key,time=100)=>{
    await identity(uid);
    await db.query("select set_config('request.jwt.claims',(auth.jwt()||jsonb_build_object('auth_time',$1::int))::text,false),set_config('request.headers',$2,false)",[time,JSON.stringify({'x-izytel-execution-key':device})]);
  };
  const acknowledge=r=>({...r,context:{...r.context,_ussd_not_executed_confirmed:true}});
  await admin();
  await db.exec("update public.ussd_execution_rules set status='disabled' where deleted_at is null; update public.ussd_execution_logs set generated_at=clock_timestamp()-interval '2 minutes'");
  await db.query("insert into public.phase4_assignment_orders(order_id,network,operation_type,amount,beneficiary_phone,offer_label,order_status,payment_status,assignment_state,assigned_agent_id,zone_id) values($1,'moov','internetSubscription',1000,'0101010101','USSD retry test','inProgress','confirmed','accepted','test-agent','zone-a'),($2,'orange','callBundle',1000,'0707070707','App retry test','inProgress','confirmed','accepted','test-agent','zone-a')",[order,appOrder]);
  await db.query("insert into private.izytel_order_executions(order_id,assignment_version,agent_id,request_id,auth_time,authorized_at) select order_id,1,'test-agent',$1,'100',clock_timestamp()-interval '6 seconds' from public.phase4_assignment_orders where order_id=any($2::text[])",[key,[order,appOrder]]);
  await identity('test-admin');
  const rule=await create({network:'moov',service:'internetSubscription',offer_id:'synthetic-offer',ussd_template:'*999#'});
  const appRule=await create({network:'orange',service:'callBundle',offer_id:'synthetic-orange',ussd_template:'APP:MAXIT'});
  await identity('test-manager');
  await rpc('register_order_context',[order,'synthetic-offer']);
  await rpc('register_order_context',[appOrder,'synthetic-orange']);
  await session();
  let resolved=await rpc('resolve',[order]);
  await test('regression: previous guard blocks USSD even after merely opening and leaving the dialer',async()=>{
    const first=await prepare(order,resolved,'dialer-first');
    await rpc('record_result',[first.attempt_id,'dialer_opened',null]);
    assert.equal((await prepare(order,acknowledge(resolved),'dialer-before-fix')).reason,'execution_uncertain');
  });
  await admin();
  const rowsSql='select to_jsonb(o) row from public.phase4_assignment_orders o order by order_id';
  const grantsSql='select to_jsonb(e) row from private.izytel_order_executions e order by order_id';
  const aclSql="select p.oid::regprocedure::text signature,p.proacl::text acl from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') and p.proname like '%ussd%' order by 1";
  const rows=(await db.query(rowsSql)).rows,grants=(await db.query(grantsSql)).rows,acl=(await db.query(aclSql)).rows;
  const file=(await readdir(new URL('../../supabase/migrations/',import.meta.url))).find(n=>n.endsWith('_ussd_confirmed_dialer_reopen.sql'));
  assert.ok(file);
  await db.exec(await readFile(new URL(`../../supabase/migrations/${file}`,import.meta.url),'utf8'));
  await test('confirmed dialer migration preserves orders, uncertain grants and RPC permissions',async()=>{
    assert.deepEqual((await db.query(rowsSql)).rows,rows);
    assert.deepEqual((await db.query(grantsSql)).rows,grants);
    assert.deepEqual((await db.query(aclSql)).rows,acl);
  });
  await session();
  await test('USSD reopening rejects absent, false and malformed no-execution acknowledgments',async()=>{
    for(const value of [undefined,false,'true',1]) {
      const request={...resolved,context:{...resolved.context,...(value===undefined?{}:{_ussd_not_executed_confirmed:value})}};
      assert.equal((await prepare(order,request,'unconfirmed-'+value)).reason,'ussd_retry_confirmation_required');
    }
  });
  await test('explicitly confirmed USSD can reopen repeatedly without completing an order or resetting its grant',async()=>{
    for(const id of ['dialer-second','dialer-third']) {
      const result=await prepare(order,acknowledge(resolved),id);
      assert.equal(result.code,'*999#');assert.ok(result.valid_for_ms>0);
      assert.deepEqual(result.context,resolved.context);
      await rpc('record_result',[result.attempt_id,'dialer_opened',null]);
    }
    await admin();
    assert.deepEqual((await db.query(rowsSql)).rows,rows);
    assert.deepEqual((await db.query(grantsSql)).rows,grants);
    await session();
  });
  await test('USSD reopening retains idempotency, fresh-context checks and session/device ownership',async()=>{
    assert.equal((await prepare(order,acknowledge(resolved),'dialer-second')).reason,'duplicate_attempt');
    assert.equal((await prepare(order,acknowledge({...resolved,context:{...resolved.context,amount:9}}),'stale-dialer')).reason,'rule_changed');
    for(const args of [['other-agent',key,100],['test-agent','b'.repeat(64),100],['test-agent',key,101]]) {
      await session(...args);await denied(()=>prepare(order,acknowledge(resolved),'wrong-session'));
    }
    await session();
  });
  await test('Max it remains reopenable without a USSD acknowledgment after the shared guard update',async()=>{
    const r=await rpc('resolve',[appOrder]);
    for(const id of ['app-compatible-first','app-compatible-second']) {
      const result=await prepare(appOrder,r,id);assert.equal(result.code,'APP:MAXIT');
      await rpc('record_result',[result.attempt_id,'app_opened',null]);
    }
  });
  await test('completed orders cannot reopen USSD even with an acknowledgment',async()=>{
    await admin();await db.query("update public.phase4_assignment_orders set order_status='completed' where order_id=$1",[order]);
    await session();assert.equal((await prepare(order,acknowledge(resolved),'completed-dialer')).status,'unavailable');
    await admin();await db.query("update public.phase4_assignment_orders set order_status='inProgress' where order_id=$1",[order]);await session();
  });
  await test('confirmed dialer retries still obey the preparation rate limit',async()=>{
    await admin();
    const n=(await db.query("select count(*)::int n from public.ussd_execution_logs where actor_uid='test-agent' and generated_at>clock_timestamp()-interval '1 minute'")).rows[0].n;
    await db.query("insert into public.ussd_execution_logs(order_id,rule_id,rule_version,actor_uid,actor_type,network,service,zone_id,offer_id,binding_version,request_id) select order_id,rule_id,rule_version,actor_uid,actor_type,network,service,zone_id,offer_id,binding_version,'dialer-rate-'||i from public.ussd_execution_logs cross join generate_series($2::int,10) i where order_id=$1 and request_id='dialer-first'",[order,n+1]);
    await session();await assert.rejects(()=>prepare(order,acknowledge(resolved),'dialer-rate-limit'),/USSD_RATE_LIMIT/);
  });
  await test('an acknowledgment cannot switch an uncertain USSD or Max it execution to a changed syntax',async()=>{
    await identity('test-admin');
    for(const [id,network,service,offer] of [[rule,'moov','internetSubscription','synthetic-offer'],[appRule,'orange','callBundle','synthetic-orange']]) {
      const currentRule=await current(id);
      await rpc('save_rule',[id,currentRule.version,JSON.stringify({network,service,offer_id:offer,ussd_template:'*998#',actor_scope:'both',priority:0,effective_from:'2020-01-01T00:00:00Z'})],['uuid','integer','jsonb']);
      const changed=await current(id);await rpc('set_status',[id,changed.version,'active','SIM de test']);
    }
    await session();
    for(const target of [order,appOrder]) {
      const fresh=await rpc('resolve',[target]);
      assert.equal((await prepare(target,acknowledge(fresh),'changed-'+target)).reason,'execution_uncertain');
    }
  });
}
