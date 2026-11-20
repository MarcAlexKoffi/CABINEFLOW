import assert from 'node:assert/strict';
import {readFile,readdir} from 'node:fs/promises';

// Real USSD resolution/preparation/audit plus the production session guard,
// inside the existing synthetic, in-memory database. No remote connection.
export async function runMaxItReopenCases({db,test,identity,rpc,denied,current,create,prepare}) {
  const read = path => readFile(new URL(path,import.meta.url),'utf8');
  await identity('test-admin','postgres');
  await db.exec("update public.ussd_execution_logs set generated_at=clock_timestamp()-interval '2 minutes'; alter table public.phase4_assignment_orders add column assignment_version bigint default 1; alter table public.phase5_agent_capacities add column zone_ids text[] default array['zone-a']");
  const exclusive = await read('../../supabase/migrations/20261119090007_exclusive_order_execution.sql');
  const shared = await read('../../supabase/migrations/20261106004036_shared_agent_queue_and_sla.sql');
  const section = (source,start,end) => {
    const a=source.indexOf(start),b=source.indexOf(end,a+start.length);
    assert.ok(a>=0 && b>a,`production SQL section exists: ${start}`);
    return source.slice(a,b);
  };
  await db.exec(section(exclusive,'create table private.izytel_order_executions (','create table public.izytel_order_requeues ('));
  await db.exec(section(shared,'create function private.izytel_shared_agent_zone(','create function private.izytel_shared_staff_zone('));
  await db.exec(section(exclusive,'create function private.izytel_assert_execution(','create function private.izytel_execution_visible('));
  await db.exec(section(exclusive,'alter function private.ussd_resolve(text) rename','alter function private.phase5_finalize_order_success('));
  await db.exec('revoke all on function private.ussd_resolve(text),private.ussd_prepare(text,uuid,integer,jsonb,text),private.ussd_record_result(uuid,text,text) from public; grant execute on function private.ussd_resolve(text),private.ussd_prepare(text,uuid,integer,jsonb,text),private.ussd_record_result(uuid,text,text) to anon,authenticated');
  const key='a'.repeat(64);
  const session=async (uid='test-agent',executionKey=key,authTime=100) => {
    await identity(uid);
    await db.query("select set_config('request.jwt.claims',(auth.jwt()||jsonb_build_object('auth_time',$1::int))::text,false),set_config('request.headers',$2,false)",[authTime,JSON.stringify({'x-izytel-execution-key':executionKey})]);
  };
  const admin=()=>identity('test-admin','postgres');
  const primary='reopen-maxit',classic='reopen-ussd';
  await db.exec(`insert into public.phase4_assignment_orders(order_id,network,operation_type,amount,beneficiary_phone,offer_label,order_status,payment_status,assignment_state,assigned_agent_id,zone_id) values
    ('${primary}','orange','callBundle',1000,'0707070707','App test','inProgress','confirmed','accepted','test-agent','zone-a'),
    ('${classic}','orange','callBundle',1000,'0707070707','USSD test','inProgress','confirmed','accepted','test-agent','zone-a')`);
  await identity('test-admin');
  const appRule=await create({network:'orange',service:'callBundle',offer_id:'synthetic-orange',ussd_template:'APP:MAXIT'});
  const classicRule=await create({network:'orange',service:'callBundle',offer_id:'maxit-other-offer',ussd_template:'*123#'});
  await identity('test-manager');
  await rpc('register_order_context',[primary,'synthetic-orange']);
  await rpc('register_order_context',[classic,'maxit-other-offer']);
  await admin();
  await db.query("insert into private.izytel_order_executions(order_id,assignment_version,agent_id,request_id,auth_time,authorized_at) select order_id,1,'test-agent',$1,'100',clock_timestamp()-interval '6 seconds' from public.phase4_assignment_orders where order_id=any($2::text[])",[key,[primary,classic]]);
  await session();
  let resolved=await rpc('resolve',[primary]);
  await test('regression: original exclusive guard refuses a second opening on the same Max it order',async()=>{
    const first=await prepare(primary,resolved,'reopen-first');
    await rpc('record_result',[first.attempt_id,'app_opened',null]);
    assert.equal((await prepare(primary,resolved,'reopen-before-fix')).reason,'execution_uncertain');
  });
  await admin();
  const aclSql="select p.oid::regprocedure::text signature,p.proacl::text acl from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') and p.proname like '%ussd%' order by 1";
  const acl=(await db.query(aclSql)).rows;
  const ordersSql='select to_jsonb(o) row from public.phase4_assignment_orders o order by order_id';
  const executionsSql='select to_jsonb(e) row from private.izytel_order_executions e order by order_id';
  const orders=(await db.query(ordersSql)).rows,executions=(await db.query(executionsSql)).rows;
  const guard=(await db.query("select pg_get_functiondef('private.izytel_assert_execution(text)'::regprocedure) definition")).rows;
  const migration=(await readdir(new URL('../../supabase/migrations/',import.meta.url))).find(name=>name.endsWith('_ussd_maxit_safe_reopen.sql'));
  assert.ok(migration,'Max it reopen migration exists');
  await db.exec(await read(`../../supabase/migrations/${migration}`));
  await test('reopen migration preserves orders, execution grants, RPC ACLs and the exact session guard',async()=>{
    assert.deepEqual((await db.query(aclSql)).rows,acl);
    assert.deepEqual((await db.query(ordersSql)).rows,orders);
    assert.deepEqual((await db.query(executionsSql)).rows,executions);
    assert.deepEqual((await db.query("select pg_get_functiondef('private.izytel_assert_execution(text)'::regprocedure) definition")).rows,guard);
  });
  await session();
  await test('same authorized Max it order reopens repeatedly with fresh short leases and app audit rows',async()=>{
    for(const request of ['reopen-second','reopen-third']) {
      const next=await prepare(primary,resolved,request);
      assert.equal(next.code,'APP:MAXIT');assert.ok(next.valid_for_ms>0);
      await rpc('record_result',[next.attempt_id,'app_opened',null]);
    }
    await admin();
    assert.deepEqual((await db.query(ordersSql)).rows,orders);
    assert.deepEqual((await db.query(executionsSql)).rows,executions);
    assert.equal((await db.query('select count(*)::int n from public.ussd_execution_logs where order_id=$1 and launch_status=$2',[primary,'app_opened'])).rows[0].n,3);
    await session();
  });
  await test('Max it reopening still requires the owner, same phone/session, territory and five-second authorization',async()=>{
    for(const args of [['other-agent',key,100],['test-agent','b'.repeat(64),100],['test-agent',key,101]]) {
      await session(...args);await denied(()=>prepare(primary,resolved,'wrong-session'));
    }
    await admin();await db.exec("update public.phase5_agent_capacities set zone_ids='{}' where agent_id='test-agent'");
    await session();await denied(()=>prepare(primary,resolved,'wrong-zone'));
    await admin();await db.exec("update public.phase5_agent_capacities set zone_ids=array['zone-a'] where agent_id='test-agent'");
    await db.query('update private.izytel_order_executions set authorized_at=clock_timestamp() where order_id=$1',[primary]);
    await session();await assert.rejects(()=>prepare(primary,resolved,'too-early'),/EXECUTION_PREPARING/);
    await admin();await db.query('update private.izytel_order_executions set authorized_at=$2::timestamptz where order_id=$1',[primary,executions.find(x=>x.row.order_id===primary).row.authorized_at]);
    await session();
  });
  await test('reopening preserves stale-context/version rejection and request idempotency',async()=>{
    assert.equal((await prepare(primary,{...resolved,context:{...resolved.context,amount:999}},'stale-reopen')).reason,'rule_changed');
    assert.equal((await prepare(primary,{...resolved,rule:{...resolved.rule,version:999}},'stale-version')).reason,'rule_changed');
    assert.equal((await prepare(primary,resolved,'reopen-second')).reason,'duplicate_attempt');
  });
  await test('classic USSD still cannot be launched twice, even if its configuration is later changed to Max it',async()=>{
    let normal=await rpc('resolve',[classic]);
    const first=await prepare(classic,normal,'classic-first');
    await rpc('record_result',[first.attempt_id,'dialer_opened',null]);
    assert.equal((await prepare(classic,normal,'classic-second')).reason,'execution_uncertain');
    await identity('test-admin');
    const r=await current(classicRule);
    await rpc('save_rule',[classicRule,r.version,JSON.stringify({network:'orange',service:'callBundle',offer_id:'maxit-other-offer',ussd_template:'APP:MAXIT',actor_scope:'both',priority:0,effective_from:'2020-01-01T00:00:00Z'})],['uuid','integer','jsonb']);
    const updated=await current(classicRule);
    await rpc('set_status',[classicRule,updated.version,'active','Appareil de test']);
    await session();normal=await rpc('resolve',[classic]);
    assert.equal(normal.code,'APP:MAXIT');
    assert.equal((await prepare(classic,normal,'classic-cannot-bypass')).reason,'execution_uncertain');
  });
  await test('closed orders and disabled Max it configurations do not reopen',async()=>{
    await admin();await db.query("update public.phase4_assignment_orders set order_status='completed' where order_id=$1",[primary]);
    await session();assert.equal((await prepare(primary,resolved,'closed-order')).status,'unavailable');
    await admin();await db.query("update public.phase4_assignment_orders set order_status='inProgress' where order_id=$1",[primary]);
    await identity('test-admin');let r=await current(appRule);await rpc('set_status',[appRule,r.version,'disabled',null]);
    await session();assert.equal((await prepare(primary,resolved,'disabled-app')).status,'unavailable');
    await identity('test-admin');r=await current(appRule);await rpc('set_status',[appRule,r.version,'active','Appareil de test']);
    await session();resolved=await rpc('resolve',[primary]);
  });
  await test('an older assignment app audit cannot unlock a current uncertain execution',async()=>{
    await admin();
    const timestamps=(await db.query('select id,generated_at from public.ussd_execution_logs where order_id=$1',[primary])).rows;
    await db.query("update public.ussd_execution_logs set generated_at=clock_timestamp()-interval '1 minute' where order_id=$1",[primary]);
    await session();assert.equal((await prepare(primary,resolved,'old-assignment')).reason,'execution_uncertain');
    await admin();for(const row of timestamps) await db.query('update public.ussd_execution_logs set generated_at=$2 where id=$1',[row.id,row.generated_at]);
    await session();
  });
  await test('Max it reopening retains the existing per-agent preparation rate limit',async()=>{
    await admin();
    const n=(await db.query("select count(*)::int n from public.ussd_execution_logs where actor_uid='test-agent' and generated_at>clock_timestamp()-interval '1 minute'")).rows[0].n;
    await db.query("insert into public.ussd_execution_logs(order_id,rule_id,rule_version,actor_uid,actor_type,network,service,zone_id,offer_id,request_id) select order_id,rule_id,rule_version,actor_uid,actor_type,network,service,zone_id,offer_id,'rate-reopen-'||i from public.ussd_execution_logs cross join generate_series($2::int,10) i where request_id='reopen-first' and order_id=$1",[primary,n+1]);
    await session();await assert.rejects(()=>prepare(primary,resolved,'rate-limited-reopen'),/USSD_RATE_LIMIT/);
  });
}
