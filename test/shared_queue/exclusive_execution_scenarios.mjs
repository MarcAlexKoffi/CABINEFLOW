import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {join} from 'node:path';
import {root} from './postgres.mjs';

// Real local PostgreSQL transactions, policies, assignment and finance functions.
// USSD generation is a synthetic sink; no dialer, payments or FCM are contacted.
export async function runExclusiveScenarios({q, seed, identity, a1, a2, a3, m1, m2, note}) {
  const key = 'a'.repeat(64), otherKey = 'b'.repeat(64);
  const syntheticCommand = process.argv.includes('--maxit') ? 'APP:MAXIT' : 'TEST ONLY';
  const headers = async (client, value = key) => client.query("select set_config('request.headers',$1,false)", [JSON.stringify({'x-izytel-execution-key': value})]);
  const session = async (client, uid, time = 100) => client.query("select set_config('request.jwt.claims',$1,false)", [JSON.stringify({sub:uid,auth_time:time,iss:'https://securetoken.google.com/cabineflow-4bca7',aud:'cabineflow-4bca7'})]);
  await session(a1,'test-agent-1'); await session(a2,'test-agent-2');
  await headers(a1); await headers(a2,otherKey);
  await q(`create table public.ussd_execution_logs(id uuid primary key default gen_random_uuid(),
    order_id text,generated_at timestamptz default clock_timestamp(),launch_status text default 'prepared',actor_uid text,request_id text);
    create function private.ussd_resolve(p_order_id text) returns jsonb language sql as $$select jsonb_build_object('status','available','code','${syntheticCommand}')$$;
    create function private.ussd_prepare(p_order_id text,p_rule_id uuid,p_version integer,p_context jsonb,p_request_id text)
    returns jsonb language plpgsql as $$declare i uuid;begin
      insert into public.ussd_execution_logs(order_id,actor_uid,request_id) values(p_order_id,auth.jwt()->>'sub',p_request_id) returning id into i;
      return jsonb_build_object('status','available','attempt_id',i);end$$;
    create function private.ussd_record_result(p_attempt_id uuid,p_status text,p_error_code text) returns void language sql as $$update public.ussd_execution_logs set launch_status=$2 where id=$1$$;
    create function public.izytel_ussd_resolve(p_order_id text) returns jsonb language sql as $$select private.ussd_resolve(p_order_id)$$;
    create function public.izytel_ussd_prepare(p_order_id text,p_rule_id uuid,p_version integer,p_context jsonb,p_request_id text)
    returns jsonb language sql as $$select private.ussd_prepare(p_order_id,p_rule_id,p_version,p_context,p_request_id)$$;
    grant execute on function public.izytel_ussd_resolve(text),public.izytel_ussd_prepare(text,uuid,integer,jsonb,text) to authenticated;`);
  await q(await readFile(join(root,'supabase/migrations/20261119090007_exclusive_order_execution.sql'),'utf8'));
  await q('update private.izytel_shared_queue_settings set enabled=true,activated_at=clock_timestamp()');
  const claim = (client,id,version=0) => client.query('select public.izytel_shared_claim($1,$2) r',[id,version]);
  const begin = (client,id,k=key,version=1) => client.query('select to_jsonb(public.izytel_begin_order_execution($1,$2,$3)) r',[id,version,k]);
  const requeue = (client,id,request='c'.repeat(64)) => client.query('select to_jsonb(public.izytel_return_order_to_queue($1,$2,$3)) r',[id,'Test de remise en file',request]);
  const check = async (sql,args) => (await q(sql,args)).rows[0];
  const verify = id => m1.query('select public.izytel_verify_order_not_executed($1,$2,1)',[id,'Opérateur et Agent vérifiés : aucune exécution']);

  await seed('exclusive-same');
  const race = await Promise.allSettled([claim(a1,'exclusive-same'),claim(a2,'exclusive-same')]);
  assert.equal(race.filter(r=>r.status==='fulfilled').length,1);
  assert.match(race.find(r=>r.status==='rejected').reason.message,/ORDER_ALREADY_TAKEN/);
  const owner = (await check("select assigned_agent_id from phase4_assignment_orders where order_id='exclusive-same'")).assigned_agent_id;
  const winner = owner==='test-agent-1'?a1:a2;
  const winnerKey = winner===a1?key:otherKey;
  const sameSession = await identity(owner);
  await session(sameSession,owner); await headers(sameSession,winnerKey);
  note('two Agents, same order: exactly one acceptance and one history');
  assert.equal((await check("select count(*)::int n from phase4_assignment_history where order_id='exclusive-same'")).n,1);
  await assert.rejects(a3.query("select public.izytel_shared_claim('exclusive-same',0)"),/ORDER_NOT_AVAILABLE/);
  await assert.rejects(m2.query("select public.izytel_return_order_to_queue('exclusive-same','test',$1)",['z'.repeat(64)]),/MANAGER_ZONE_REQUIRED/);
  note('cross-zone claim and Manager action denied');

  const masked = (await winner.query("select public.izytel_read_orders('exclusive-same') r")).rows[0].r;
  assert.equal(masked[0].beneficiary_phone,'••••');
  assert.equal((await winner.query("select * from phase4_assignment_orders where order_id='exclusive-same'")).rowCount,0);
  await assert.rejects(winner.query("select public.izytel_ussd_resolve('exclusive-same')"),/EXECUTION_SESSION_REQUIRED/);
  await assert.rejects(winner.query("select public.phase3_agent_processing_action('exclusive-same','start',null,null)"),/EXECUTION_SESSION_REQUIRED/);
  note('direct navigation, raw order data and old start RPC blocked before authorization');

  const starts = await Promise.all([begin(winner,'exclusive-same',winnerKey),begin(sameSession,'exclusive-same',winnerKey)]);
  assert.equal(starts[0].rows[0].r.order.order_status,'inProgress');
  assert.equal(starts[0].rows[0].r.ready,false);
  assert.equal(starts[0].rows[0].r.order.beneficiary_phone,'••••');
  await assert.rejects(winner.query("select public.izytel_ussd_resolve('exclusive-same')"),/EXECUTION_PREPARING/);
  assert.equal((await winner.query("select * from phase4_assignment_orders where order_id='exclusive-same'")).rowCount,0);
  // Advance only the synthetic server fixture; no wall-clock dependency.
  await q("update private.izytel_order_executions set authorized_at=clock_timestamp()-interval '5 seconds' where order_id='exclusive-same'");
  assert.equal((await begin(winner,'exclusive-same',winnerKey)).rows[0].r.ready,true);
  note('server also enforces five seconds before exposing processing data or USSD');
  if (process.argv.includes('--maxit')) {
    assert.equal((await winner.query("select public.izytel_ussd_resolve('exclusive-same') r")).rows[0].r.code,'APP:MAXIT');
    note('configured Max it command passes the same exclusive execution and five-second gates');
  }
  assert.equal((await check("select count(*)::int n from private.izytel_order_executions where order_id='exclusive-same'")).n,1);
  await begin(winner,'exclusive-same',winnerKey); // same request after a lost response
  assert.equal((await check("select count(*)::int n from private.izytel_order_executions where order_id='exclusive-same'")).n,1);
  note('double start and timeout retry retain one execution grant');
  const secondPhone = await identity(owner);
  await session(secondPhone,owner); await headers(secondPhone,'d'.repeat(64));
  await assert.rejects(begin(secondPhone,'exclusive-same','d'.repeat(64)),/EXECUTION_SESSION_REQUIRED/);
  await assert.rejects(secondPhone.query("select public.izytel_ussd_resolve('exclusive-same')"),/EXECUTION_SESSION_REQUIRED/);
  await headers(secondPhone,winnerKey); await session(secondPhone,owner,101);
  await assert.rejects(begin(secondPhone,'exclusive-same',winnerKey),/EXECUTION_SESSION_REQUIRED/);
  note('second phone and old Firebase session cannot reuse execution');

  const prepare = client => client.query("select public.izytel_ussd_prepare('exclusive-same',null,1,'{}','launch-test') r");
  const attempts = await Promise.all([prepare(winner),prepare(sameSession)]);
  assert.equal(attempts.filter(r=>r.rows[0].r.status==='available').length,1);
  assert.equal((await check("select count(*)::int n from ussd_execution_logs where order_id='exclusive-same'")).n,1);
  await assert.rejects(requeue(m1,'exclusive-same'),/EXECUTION_REQUIRES_MANAGER_VERIFICATION/);
  // Old reassignment API cannot erase an uncertain execution either.
  const boss = await identity('boss');
  await assert.rejects(boss.query("select public.phase4_reset_for_manual_assignment('exclusive-same')"),/EXECUTION_REQUIRES_MANAGER_VERIFICATION/);
  note('one synthetic USSD attempt; uncertain execution blocks both new and old reassignment APIs');
  await winner.query("select public.phase3_agent_processing_action('exclusive-same','fail','technicalError',null)");
  await seed('uncertain-next');
  await assert.rejects(claim(winner,'uncertain-next'),/AGENT_ACTIVE_ORDER_EXISTS/);
  await q('alter table phase4_assignment_orders disable trigger zzz_izytel_acceptance_lifecycle');
  await q("update phase4_assignment_orders set accepted_at=clock_timestamp()-interval '6 minutes' where order_id='exclusive-same'");
  await q('alter table phase4_assignment_orders enable trigger zzz_izytel_acceptance_lifecycle');
  await q('select private.izytel_detect_order_delays(200)');
  assert.equal((await check("select count(*)::int n from izytel_order_delay_alerts where order_id='exclusive-same' and state='active'")).n,1);
  note('failed uncertain execution still blocks new work and alerts its zone Manager');
  await verify('exclusive-same');
  const released = (await requeue(m1,'exclusive-same')).rows[0].r;
  assert.equal(released.zone_id,'z1'); assert.equal(released.assignment_state,'waiting');
  assert.equal(released.assigned_agent_id,null); assert.equal(released.assignment_version,2);
  await requeue(m1,'exclusive-same');
  assert.equal((await check("select count(*)::int n from izytel_order_requeues where order_id='exclusive-same'")).n,1);
  assert.equal((await check("select state from private.izytel_order_executions where order_id='exclusive-same'")).state,'revoked');
  await assert.rejects(begin(winner,'exclusive-same',winnerKey),/EXECUTION_OWNER_REQUIRED/);
  assert((await a1.query('select public.izytel_shared_available() r')).rows[0].r.orders.some(o=>o.order_id==='exclusive-same'));
  note('verified requeue is atomic, idempotent, preserves zone and audit, revokes old grant');
  await claim(winner,'exclusive-same',2);
  await assert.rejects(begin(winner,'exclusive-same',winnerKey,1),/EXECUTION_VERSION_EXPIRED/);
  await assert.rejects(verify('exclusive-same'),/ASSIGNMENT_VERSION_EXPIRED/);
  await requeue(m1,'exclusive-same','e'.repeat(64));
  const historical = (await requeue(m1,'historical','f'.repeat(64))).rows[0].r;
  assert.equal(historical.assignment_route,'shared'); assert.equal(historical.assignment_version,1);
  assert(historical.available_at);
  note('stale assignment version denied; eligible legacy order can return to its zone queue');

  await seed('exclusive-different-1'); await seed('exclusive-different-2');
  const a1Parallel = await identity('test-agent-1');
  await session(a1Parallel,'test-agent-1'); await headers(a1Parallel);
  const different = await Promise.allSettled([claim(a1,'exclusive-different-1'),claim(a1Parallel,'exclusive-different-2')]);
  assert.equal(different.filter(r=>r.status==='fulfilled').length,1);
  assert.match(different.find(r=>r.status==='rejected').reason.message,/AGENT_ACTIVE_ORDER_EXISTS/);
  await seed('exclusive-agent-2'); await claim(a2,'exclusive-agent-2');
  note('one Agent racing different orders: one active; different Agents can each accept one');
  const active = (await check("select order_id from phase4_assignment_orders where assigned_agent_id='test-agent-1' and assignment_state='accepted'")).order_id;
  await q("alter table phase4_assignment_orders disable trigger zzz_izytel_acceptance_lifecycle");
  await q("update phase4_assignment_orders set accepted_at=clock_timestamp()-interval '6 minutes' where order_id=$1",[active]);
  await q("alter table phase4_assignment_orders enable trigger zzz_izytel_acceptance_lifecycle");
  await q('select private.izytel_detect_order_delays(200)');
  await q('select private.izytel_detect_order_delays(200)');
  assert.equal((await check('select count(*)::int n from izytel_order_delay_alerts where order_id=$1',[active])).n,1);
  assert.equal((await check("select count(*)::int n from izytel_notification_outbox where event_type='order_acceptance_delay' and data->>'orderId'=$1",[active])).n,1);
  assert.equal((await m2.query('select * from izytel_order_delay_alerts')).rowCount,0);
  note('server delay detector: one territorial alert and outbox event after five minutes without Manager connection');
  await begin(a1,active);
  await q("update private.izytel_order_executions set authorized_at=clock_timestamp()-interval '5 seconds' where order_id=$1",[active]);
  await a1.query('select public.phase5_finalize_order_success($1,$2,null)',[active,'Agent One']);
  assert.equal((await check('select count(*)::int n from phase5_success_finalizations where order_id=$1',[active])).n,1);
  const available = active==='exclusive-different-1'?'exclusive-different-2':'exclusive-different-1';
  await claim(a1,available);
  note('real financial finalization releases the Agent for another order');
  await q(`insert into phase4_assignment_orders(order_id,order_reference,network,amount,firebase_created_at,
    zone_id,payment_status,assignment_state,assigned_agent_id,assigned_agent_name,assigned_by_uid,assignment_mode,assigned_at)
    values('legacy-credit','CREDIT-TEST','orange',1000,now(),'z2','credit','assigned','test-agent-3','Other Zone','boss','manual',now())`);
  await session(a3,'test-agent-3'); await headers(a3);
  await a3.query("select public.phase4_agent_action('legacy-credit','accept',null)");
  await begin(a3,'legacy-credit');
  await q("update private.izytel_order_executions set authorized_at=clock_timestamp()-interval '5 seconds' where order_id='legacy-credit'");
  await a3.query("select public.phase5_finalize_order_success('legacy-credit','Other Zone',null)");
  assert.equal((await check("select order_status from phase4_assignment_orders where order_id='legacy-credit'")).order_status,'completed');
  note('existing funded legacy credit processing and financial closure remain available');
  const beforeRollback = (await q('select (select count(*) from phase4_assignment_orders) orders,(select count(*) from phase4_assignment_history) history,(select count(*) from izytel_order_requeues) audit')).rows;
  await q(await readFile(join(root,'supabase/operations/exclusive_execution_rollback.sql'),'utf8'));
  assert.deepEqual((await q('select (select count(*) from phase4_assignment_orders) orders,(select count(*) from phase4_assignment_history) history,(select count(*) from izytel_order_requeues) audit')).rows,beforeRollback);
  await assert.rejects(begin(a1,available),/permission denied/);
  note('rollback restores prior functions and ACLs without deleting orders, history or audit');
}
