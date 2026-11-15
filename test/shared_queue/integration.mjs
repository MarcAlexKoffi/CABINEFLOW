// Catalog definitions and synthetic rows only. All mutations are in a fresh local cluster.
import assert from 'node:assert/strict';
import {readFile, writeFile} from 'node:fs/promises';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {withPostgres, root} from './postgres.mjs';

const json = async name => JSON.parse(await readFile(new URL(name, import.meta.url), 'utf8'));
const baseline = await json('integration_metadata.json');
const extra = await json('integration_extra_metadata.json');
const old = await json('existing_metadata.json');
const functions = [
  ...old.functions,
  ...(await json('integration_functions.json')).functions,
  ...(await json('integration_extra_functions.json')).functions,
  ...(await json('integration_actions.json')).functions,
];
const functionGrants = await json('integration_function_grants.json');
const migration = await readFile(join(root, 'supabase/migrations/20261106004036_shared_agent_queue_and_sla.sql'), 'utf8');
const notificationMigration = await readFile(join(root, 'supabase/migrations/20261101011937_notifications_territory_delivery_recovery.sql'), 'utf8');
const checks = [];
const fastProcessing = process.argv.includes('--fast-processing');
const fastMigration = fastProcessing ? await readFile(join(root, 'supabase/migrations/20261106224728_fast_processing_without_proof.sql'), 'utf8') : null;
const note = name => { checks.push(name); console.log('PASS ' + name); };
const quote = identifier => '"' + identifier.replaceAll('"', '""') + '"';
const claims = uid => JSON.stringify({sub: uid, iss: 'https://securetoken.google.com/cabineflow-4bca7', aud: 'cabineflow-4bca7'});

await withPostgres(async ({admin, connect}) => {
  const q = (sql, args) => admin.query(sql, args);
  await q(`create schema private; create schema auth; create role anon; create role authenticated; create role service_role bypassrls;
    create function auth.jwt() returns jsonb language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
    create function public.is_izytel_firebase_jwt() returns boolean language sql stable as $$select (auth.jwt()->>'iss')='https://securetoken.google.com/cabineflow-4bca7' and (auth.jwt()->>'aud')='cabineflow-4bca7' and nullif(auth.jwt()->>'sub','') is not null$$;
    grant usage on schema public,private,auth to anon,authenticated,service_role;
    set check_function_bodies=false;`);

  const columns = [...baseline.columns, ...extra.columns];
  for (const table of new Set(columns.map(column => column.table))) {
    const definition = columns.filter(column => column.table === table).map(column =>
      `${quote(column.name)} ${column.type}${column.default ? ' default ' + column.default : ''}${column.not_null ? ' not null' : ''}`);
    await q(`create table public.${quote(table)} (${definition.join(',')})`);
    await q(`alter table public.${quote(table)} enable row level security`);
  }
  for (const constraint of [...baseline.constraints, ...extra.constraints]) {
    await q(`alter table public.${quote(constraint.table)} add constraint ${quote(constraint.name)} ${constraint.definition}`);
  }
  for (const fn of functions) await q(fn.definition);

  // Only external delivery and unrelated customer-inbox storage are substituted.
  // Enqueue, deduplication, outbox RLS, business hooks and financial writes stay real.
  await q(`create table test_customer_messages(order_id text,reference text,body text);
    create function private.izytel_wc5_emit_customer_system_message(text,text,text) returns void language sql as $$insert into public.test_customer_messages values($1,$2,$3)$$;
    create table test_dispatch_tickets(outbox_id uuid,nonce uuid);
    create function private.izytel_notification_dispatch_wakeup() returns trigger language plpgsql as $$begin insert into public.test_dispatch_tickets values(new.id,new.dispatch_nonce);return new;end;$$;`);
  for (const grant of baseline.grants) {
    await q(`grant ${grant.privilege_type} on public.${quote(grant.table_name)} to ${quote(grant.grantee)}`);
  }
  const policyTables = new Set(['phase4_assignment_orders', 'phase4_assignment_history', 'partner_accounts', 'phase5_order_proofs']);
  for (const policy of baseline.policies.filter(policy => policyTables.has(policy.tablename))) {
    await q(`create policy ${quote(policy.policyname)} on public.${quote(policy.tablename)} as ${policy.permissive} for ${policy.cmd} to ${policy.roles.map(quote).join(',')}${policy.qual ? ' using (' + policy.qual + ')' : ''}${policy.with_check ? ' with check (' + policy.with_check + ')' : ''}`);
  }
  await q('revoke all on all functions in schema public,private from public,anon,authenticated');
  await q('grant execute on function public.is_izytel_firebase_jwt() to anon,authenticated');
  for (const grant of functionGrants) {
    await q(`grant execute on function ${quote(grant.schema)}.${quote(grant.name)}(${grant.args}) to ${grant.grantee === 'PUBLIC' ? 'public' : quote(grant.grantee)}`);
  }
  const triggerTables = new Set(['phase4_assignment_orders', 'phase4_assignment_history', 'phase5_agent_capacities', 'phase5_order_proofs', 'phase5_network_movements', 'phase5_commissions', 'phase5_commission_accounts', 'phase5_success_finalizations', 'phase5_ledger_events', 'partner_success_finalizations', 'izytel_notification_outbox']);
  for (const trigger of baseline.triggers.filter(trigger => triggerTables.has(trigger.table) && !/managed_guard|access_audit/.test(trigger.name))) {
    await q(trigger.definition);
  }
  await q(`insert into territory_zones(id,name,manager_id) values('z1','Zone One','m1'),('z2','Zone Two','m2');
    insert into izytel_staff_access(firebase_uid,role) values('m1','manager'),('m2','manager'),('boss','admin');
    insert into phase5_agent_capacities(agent_id,agent_name,zone_ids,orange_capacity) values('test-agent-1','Agent One',array['z1'],100000),('test-agent-2','Agent Two',array['z1'],100000),('test-agent-3','Other Zone',array['z2'],100000);
    insert into compensation_plans(plan_code,actor_type,plan_scope,version,status,partner_margin_share_bps,izytel_margin_share_bps) values('test-agent','agent','direct',1,'active',0,10000),('test-partner','cabiniste','standard',1,'active',8000,2000);`);
  await q("select set_config('request.jwt.claims',$1,false)", [claims('boss')]);
  const seed = async (id, zone = 'z1', extraSql = '') => q(`insert into phase4_assignment_orders(order_id,order_reference,network,amount,firebase_created_at,zone_id,payment_status,payment_confirmed_at,customer_auth_uid,beneficiary_phone${extraSql ? ',assigned_cabiniste_id,assigned_cabiniste_name,assignment_state,assigned_by_uid,assignment_mode,assigned_at' : ''}) values($1,$1,'orange',1000,now(),$2,'confirmed',now(),'test-customer','0700000018'${extraSql ? ',' + extraSql + ",'assigned','boss','manual',now()" : ''})`, [id, zone]);
  const identity = async (uid, role = 'authenticated') => {
    const client = await connect();
    await client.query('set role ' + quote(role));
    await client.query("select set_config('request.jwt.claims',$1,false)", [claims(uid)]);
    return client;
  };
  const a1 = await identity('test-agent-1'), a2 = await identity('test-agent-2'), a3 = await identity('test-agent-3'), m1 = await identity('m1'), m2 = await identity('m2');

  await seed('historical');
  const historical = (await q("select to_jsonb(o) r from phase4_assignment_orders o where order_id='historical'")).rows[0].r;
  await q(migration);
  if (fastProcessing) {
    await q('create publication supabase_realtime');
    await q(fastMigration);
    assert.equal((await q("select count(*)::int n from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='izytel_order_delay_alerts'")).rows[0].n,1);
    await q(fastMigration);
  }
  if (process.argv.includes('--publication-only')) {
    const recovery = await readFile(join(root, 'supabase/operations/shared_queue_publish_three_20261106.sql'), 'utf8');
    const refs = ['CF-20261106-UCTYKO','CF-20261106-MEEBSO','CF-20261106-J4WWAB'];
    for (let i=0;i<refs.length;i++) {
      await seed('recovery-'+i);
      await q('update phase4_assignment_orders set order_reference=$1 where order_id=$2', [refs[i], 'recovery-'+i]);
    }
    const before = (await q("select jsonb_agg(to_jsonb(o)-array['assignment_route','available_at','updated_at'] order by order_id) r from phase4_assignment_orders o where order_id like 'recovery-%'")).rows[0].r;
    await assert.rejects(q(recovery), /SHARED_QUEUE_MUST_BE_ENABLED/);
    await q('rollback');
    await q('update private.izytel_shared_queue_settings set enabled=true,activated_at=clock_timestamp()');
    await q(recovery);
    const after = (await q("select jsonb_agg(to_jsonb(o)-array['assignment_route','available_at','updated_at'] order by order_id) r from phase4_assignment_orders o where order_id like 'recovery-%'")).rows[0].r;
    assert.deepEqual(after,before);
    assert.equal((await q("select count(*)::int n from phase4_assignment_orders where assignment_route='shared' and available_at is not null")).rows[0].n,3);
    assert.equal((await q("select assignment_route from phase4_assignment_orders where order_id='historical'")).rows[0].assignment_route,'legacy');
    assert.equal((await q("select count(*)::int n from pg_trigger where tgrelid='phase4_assignment_orders'::regclass and tgname in ('aaa_izytel_shared_order_guard','zzz_izytel_acceptance_lifecycle') and tgenabled='O'")).rows[0].n,2);
    const events = (await q("select count(*)::int n from izytel_notification_outbox where event_type='order_available'")).rows[0].n;
    assert.equal(events,6);
    await q(recovery);
    assert.equal((await q("select count(*)::int n from izytel_notification_outbox where event_type='order_available'")).rows[0].n,events);
    const visible = (await a1.query('select public.izytel_shared_available() r')).rows[0].r;
    assert.equal(visible.orders.length,3);
    assert.equal((await a3.query('select public.izytel_shared_available() r')).rows[0].r.orders.length,0);
    const unauthorizedChange = await a1.query("update phase4_assignment_orders set assignment_route='legacy' where order_id='recovery-0' returning order_id").catch(() => ({rowCount:0}));
    assert.equal(unauthorizedChange.rowCount,0);
    assert.equal((await q("select assignment_route from phase4_assignment_orders where order_id='recovery-0'")).rows[0].assignment_route,'shared');
    await a1.query("select public.izytel_shared_claim('recovery-0',0)");
    const accepted = (await q("select to_jsonb(o) r from phase4_assignment_orders o where order_id='recovery-0'")).rows[0].r;
    await q(recovery);
    assert.deepEqual((await q("select to_jsonb(o) r from phase4_assignment_orders o where order_id='recovery-0'")).rows[0].r,accepted);
    assert.equal((await q('select count(*)::int n from phase5_success_finalizations')).rows[0].n,0);
    assert.equal((await q("select orange_capacity from phase5_agent_capacities where agent_id='test-agent-1'")).rows[0].orange_capacity,'100000');
    console.log('PASS targeted recovery: payment and history preserved, guards restored, 3 territorial rows, 6 unique events, safe retry after acceptance, no financial finalization');
    return;
  }
  const preserved = (await q("select to_jsonb(o)-array['assignment_route','assignment_version','accepted_at','available_at'] r from phase4_assignment_orders o where order_id='historical'")).rows[0].r;
  assert.deepEqual(preserved, historical);
  await q('update private.izytel_shared_queue_settings set enabled=true,activated_at=clock_timestamp()');
  await seed('shared'); await seed('other-zone', 'z2');
  assert.equal((await m2.query("select * from phase4_assignment_orders where order_id='shared'")).rowCount, 0);
  assert.equal((await m1.query("select * from phase4_assignment_orders where order_id='other-zone'")).rowCount, 0);
  assert.equal((await a3.query("select * from phase4_assignment_orders where order_id='shared'")).rowCount, 0);
  assert.equal((await a1.query("select * from phase4_assignment_orders where order_id='shared'")).rowCount, 0);
  assert.equal((await q("select count(*)::int n from pg_policies where tablename='phase4_assignment_orders' and cmd='SELECT'")).rows[0].n, 1);
  assert.equal((await m2.query("update phase4_assignment_orders set assigned_agent_id='test-agent-3' where order_id='shared' returning *")).rowCount, 0);
  note('catalog grants and single territorial SELECT policy: direct cross-zone reads and writes cannot expose shared orders');

  await seed('stale-worker');
  await q("insert into phase4_assignment_plans(order_id) values('stale-worker')");
  const claimForWorker = (await a1.query("select public.izytel_shared_claim('stale-worker',0) r")).rows[0].r.order;
  await m1.query("select public.phase4_reconcile_acceptance('stale-worker',false)");
  await m1.query("select public.phase4_close_order('stale-worker')");
  const afterWorker = (await q("select * from phase4_assignment_orders where order_id='stale-worker'")).rows[0];
  assert.equal(afterWorker.assignment_state, 'accepted', 'An obsolete Firebase worker must not undo a shared acceptance');
  assert.equal(afterWorker.assigned_agent_id, 'test-agent-1');
  assert.equal(afterWorker.accepted_at.toISOString(), new Date(claimForWorker.accepted_at).toISOString());
  await seed('stale-refusals');
  await q("insert into phase4_assignment_plans(order_id) values('stale-refusals')");
  await m1.query("select public.phase4_import_legacy_refusals('stale-refusals',array['test-agent-1'],true)");
  assert.equal((await q("select assignment_state from phase4_assignment_orders where order_id='stale-refusals'")).rows[0].assignment_state, 'waiting');
  note('obsolete Firebase reconciliation, closure and refusal import cannot undo or remove a shared order');

  await q("insert into customer_order_contexts(order_id,order_reference,owner_firebase_uid,zone_id) values('sync-canonical','CF-20261106-SYNCTEST','test-customer','z1')");
  const syncParams = ['sync-canonical','CF-20261106-SYNCTEST','orange',1000,new Date(),new Date(0),'operatorApp','Test Customer','','0700000018','internetSubscription','Test offer',null,null,'confirmed',null,null,new Date(),'test-customer'];
  const syncSql = 'select to_jsonb(public.phase3_sync_order(' + syncParams.map((_, index) => '$' + (index + 1)).join(',') + ')) r';
  const synced = (await m1.query(syncSql, syncParams)).rows[0].r;
  assert.equal(synced.assignment_route, 'shared'); assert.equal(synced.assigned_agent_id, null);
  await a1.query("select public.izytel_shared_claim('sync-canonical',0)");
  await assert.rejects(m2.query(syncSql, syncParams), /MANAGER_ZONE_REQUIRED/);
  const staleParams = [...syncParams]; staleParams[3] = 9000; staleParams[9] = '0799999999';
  const replayed = (await m1.query(syncSql, staleParams)).rows[0].r;
  assert.equal(replayed.amount, 1000, 'A stale Firestore sync cannot rewrite a published shared order');
  assert.equal(replayed.beneficiary_phone, '0700000018');
  assert.equal(replayed.assigned_agent_id, 'test-agent-1');
  assert.equal(replayed.assignment_state, 'accepted');
  note('real payment synchronization publishes once and preserves canonical amount, beneficiary and acceptance on replay');

  await q("insert into customer_order_contexts(order_id,order_reference,owner_firebase_uid,zone_id) values('sync-concurrent','CF-20261106-SYNCRACE','test-customer','z1')");
  const concurrentParams = [...syncParams]; concurrentParams[0] = 'sync-concurrent'; concurrentParams[1] = 'CF-20261106-SYNCRACE';
  const changedConcurrentParams = [...concurrentParams]; changedConcurrentParams[3] = 9000;
  const synchronizer1 = await identity('m1'), synchronizer2 = await identity('m1');
  await synchronizer1.query('begin');
  try {
    const firstPublication = (await synchronizer1.query(syncSql, concurrentParams)).rows[0].r;
    const concurrentPublication = synchronizer2.query(syncSql, changedConcurrentParams);
    let blockedOnPublication = false;
    for (let attempt = 0; attempt < 50; attempt++) {
      const wait = (await q('select wait_event_type from pg_stat_activity where pid=$1', [synchronizer2.processID])).rows[0];
      if (wait?.wait_event_type === 'Lock') { blockedOnPublication = true; break; }
      await new Promise(resolve => setTimeout(resolve, 20));
    }
    assert.equal(blockedOnPublication, true, 'Second sync must reach the uncommitted publication');
    await synchronizer1.query('commit');
    const secondPublication = (await concurrentPublication).rows[0].r;
    assert.equal(firstPublication.amount, 1000);
    assert.equal(secondPublication.amount, 1000);
    assert.equal(secondPublication.assignment_route, 'shared');
  } finally { await synchronizer1.query('rollback'); }
  note('two real synchronization transactions preserve the first published amount even when the second upsert was already waiting');

  const outbox = async type => (await q('select * from izytel_notification_outbox where event_type=$1 order by recipient_uid', [type])).rows;
  const available = (await outbox('order_available')).filter(row => row.data.orderId === 'shared');
  assert.deepEqual(available.map(row => row.recipient_uid), ['test-agent-1', 'test-agent-2']);
  assert(available.every(row => row.data.route === 'shared_queue' && row.data.zoneId === 'z1'));
  const authorize = async id => (await q('select public.izytel_notification_recipient_authorized($1) ok', [id])).rows[0].ok;
  assert.equal(await authorize(available[0].id), true);
  await q("update phase5_agent_capacities set zone_ids=array['z2'] where agent_id='test-agent-1'");
  assert.equal(await authorize(available[0].id), false);
  await q("update phase5_agent_capacities set zone_ids=array['z1'] where agent_id='test-agent-1'");
  await assert.rejects(a1.query('select public.izytel_notification_recipient_authorized($1)', [available[0].id]), error => error.code === '42501');
  const countBefore = (await q('select count(*)::int n from izytel_notification_outbox')).rows[0].n;
  await a1.query('select public.izytel_shared_available()'); await a1.query('select public.izytel_shared_available()');
  assert.equal((await q('select count(*)::int n from izytel_notification_outbox')).rows[0].n, countBefore);
  await assert.rejects(a1.query('select * from izytel_notification_outbox'), error => error.code === '42501');
  note('real outbox emits one available event per eligible territorial recipient, never on refetch; outbox RLS stays private');

  const financialTables = ['phase5_network_movements', 'phase5_commissions', 'phase5_success_finalizations', 'phase5_ledger_events', 'compensation_entries'];
  const financialCounts = async () => Promise.all(financialTables.map(async table => (await q(`select count(*)::int n from ${table}`)).rows[0].n));
  const financialBefore = await financialCounts();
  const claim = (client, id, version = 0) => client.query('select public.izytel_shared_claim($1,$2) r', [id, version]);
  await assert.rejects(claim(a1, 'shared', null), /INVALID_CLAIM_VERSION/);
  await assert.rejects(claim(a1, 'shared', -1), /INVALID_CLAIM_VERSION/);
  await claim(a1, 'shared');
  assert.equal(await authorize(available[0].id), false);
  assert.deepEqual(await financialCounts(), financialBefore);
  assert.equal((await m2.query("select * from phase4_assignment_history where order_id='shared'")).rowCount, 0);
  await a1.query("select public.phase3_agent_processing_action('shared','start',null,null)");
  await a1.query("select public.phase3_agent_processing_action('shared','hold','Network test',null)");
  await a1.query("select public.phase3_agent_processing_action('shared','resume',null,null)");
  await assert.rejects(a2.query("select public.phase3_agent_processing_action('shared','fail','other',null)"), /NOT_ASSIGNED|OWNER/);
  if (!fastProcessing) await assert.rejects(a1.query("select public.phase5_finalize_order_success('shared','Agent One',null)"), /PROOF_REQUIRED/);
  else await assert.rejects(a2.query("select public.phase5_finalize_order_success('shared','Agent Two',null)"), /ASSIGNED|OWNER/);
  note(fastProcessing ? 'claim leaves money untouched; processing and proof-free finalization preserve ownership' : 'claim leaves money untouched; existing processing RPCs preserve ownership and require proof before financial success');

  if (!fastProcessing) await a1.query("insert into phase5_order_proofs(order_id,order_reference,agent_id,storage_path,file_name,size_bytes) values('shared','shared','test-agent-1','test-agent-1/shared/proof.jpg','proof.jpg',100)");
  const finalized = (await a1.query("select public.phase5_finalize_order_success('shared','Agent One',null) r")).rows[0].r;
  assert.equal(finalized.idempotent, false);
  const finalAgain = (await a1.query("select public.phase5_finalize_order_success('shared','Agent One',null) r")).rows[0].r;
  assert.equal(finalAgain.idempotent, true);
  assert.equal((await q("select orange_capacity from phase5_agent_capacities where agent_id='test-agent-1'")).rows[0].orange_capacity, '99000');
  assert.equal((await q("select earned_total from phase5_commission_accounts where agent_id='test-agent-1'")).rows[0].earned_total, '10');
  assert.equal((await q("select count(*)::int n from phase5_network_movements where order_id='shared'")).rows[0].n, 1);
  assert.equal((await q("select count(*)::int n from phase5_commissions where order_id='shared'")).rows[0].n, 1);
  assert.equal((await outbox('order_completed')).filter(row => row.data.orderId === 'shared').length, 1);
  assert.equal((await q("select count(*)::int n from test_customer_messages where order_id='shared'")).rows[0].n, 1);
  assert.equal((await q("select count(*)::int n from order_economics where order_id='shared'")).rows[0].n, 1);
  note('real Agent finalization: one capacity debit, commission, economics row, ledger cycle and customer completion notification; retry is idempotent');

  await seed('late'); await claim(a1, 'late');
  await q('alter table phase4_assignment_orders disable trigger zzz_izytel_acceptance_lifecycle');
  await q("update phase4_assignment_orders set accepted_at=now()-interval '6 minutes' where order_id='late'");
  await q('alter table phase4_assignment_orders enable trigger zzz_izytel_acceptance_lifecycle');
  await q('select private.izytel_detect_order_delays()'); await q('select private.izytel_detect_order_delays()');
  const delays = (await outbox('order_acceptance_delay')).filter(row => row.data.orderId === 'late');
  assert.equal(delays.length, 1); assert.equal(delays[0].recipient_uid, 'm1');
  assert.equal(await authorize(delays[0].id), true);
  await q("update territory_zones set manager_id='m2' where id='z1'");
  assert.equal(await authorize(delays[0].id), false);
  await q("update territory_zones set manager_id='m1' where id='z1'");
  const supervision = (await m1.query('select public.izytel_order_supervision() r')).rows[0].r;
  assert.equal(supervision.alerts[0].order_reference, 'late');
  assert.equal(supervision.alerts[0].order_status, 'paidReady');
  assert.equal((await m2.query('select public.izytel_order_supervision() r')).rows[0].r.alerts.length, 0);
  await m1.query("select public.phase4_reset_for_manual_assignment('late')");
  assert.equal((await q("select state from izytel_order_delay_alerts where order_id='late'")).rows[0].state, 'obsolete');
  assert.equal(await authorize(delays[0].id), false);
  await assert.rejects(claim(a1, 'late'), /ORDER_ALREADY_TAKEN/);
  note('actual delay enqueue is unique and territorial; reassignment obsoletes the alert and rejects a stale cycle');

  await seed('failed'); await claim(a1, 'failed');
  await a1.query("select public.phase3_agent_processing_action('failed','start',null,null)");
  await a1.query("select public.phase3_agent_processing_action('failed','fail','networkUnavailable','Synthetic failure')");
  assert.equal((await outbox('order_failed_review')).filter(row => row.data.orderId === 'failed' && row.recipient_uid === 'm1').length, 1);
  await q('select private.izytel_detect_order_delays()');
  assert.equal((await q("select count(*)::int n from izytel_order_delay_alerts where order_id='failed'")).rows[0].n, 0);
  note('existing failure review notification survives independently of the five-minute delay cycle');

  const partnerId = '11111111-1111-4111-8111-111111111111';
  await q("insert into partner_accounts(id,display_name,firebase_uid,status,zone_ids) values($1,'Test Cabiniste','partner','active',array['z1'])", [partnerId]);
  await q('insert into partner_capacities(partner_id,orange_capacity) values($1,10000)', [partnerId]);
  await seed('partner', 'z1', "'11111111-1111-4111-8111-111111111111','Test Cabiniste'");
  await q("update phase4_assignment_orders set assignment_state='accepted',assigned_at=now() where order_id='partner'");
  const partner = await identity('partner');
  assert.equal((await q("select assignment_route from phase4_assignment_orders where order_id='partner'")).rows[0].assignment_route, 'legacy');
  await partner.query("select public.phase4_partner_processing_action('partner','start',null,null)");
  if (!fastProcessing) {
    await assert.rejects(partner.query("select public.phase5_finalize_partner_order_success('partner',null)"), /PROOF_REQUIRED/);
    await q("insert into partner_order_proofs(order_id,order_reference,partner_id,storage_path,file_name,size_bytes) values('partner','partner',$1,'local/partner.png','partner.png',100)", [partnerId]);
  }
  await partner.query("select public.phase5_finalize_partner_order_success('partner',null)");
  await partner.query("select public.phase5_finalize_partner_order_success('partner',null)");
  assert.equal((await q("select orange_capacity from partner_capacities where partner_id=$1", [partnerId])).rows[0].orange_capacity, '9000');
  assert.equal((await q("select count(*)::int n from partner_success_finalizations where order_id='partner'")).rows[0].n, 1);
  assert.equal((await q("select count(*)::int n from compensation_entries where order_id='partner'")).rows[0].n, 1);
  if (fastProcessing) {
    assert.equal((await q('select count(*)::int n from phase5_order_proofs')).rows[0].n,0);
    assert.equal((await q('select count(*)::int n from partner_order_proofs')).rows[0].n,0);
  }
  note(fastProcessing ? 'Cabiniste proof-free finalization preserves one capacity debit and one idempotent settlement' : 'Cabiniste stays on legacy routing; actual proof, finalization, capacity debit and settlement remain idempotent');

  const tickets = (await q('select count(*)::int n from test_dispatch_tickets')).rows[0].n;
  assert.equal(tickets, (await q('select count(*)::int n from izytel_notification_outbox')).rows[0].n);
  await q(notificationMigration.slice(notificationMigration.indexOf('create or replace function public.izytel_claim_notification_batch('), notificationMigration.indexOf('create or replace function private.izytel_phase4_notification_trigger()')));
  const batch = (await q('select * from public.izytel_claim_notification_batch(50)')).rows;
  assert(batch.some(row => row.event_type === 'order_available'));
  assert(batch.some(row => row.event_type === 'order_acceptance_delay'));
  assert.equal((await q('select * from public.izytel_claim_notification_batch(50)')).rowCount, 0);
  note('real outbox creates one dispatch ticket per event and claims both new event types without immediate replay');

  await q("insert into phase4_assignment_orders(order_id,order_reference,network,amount,firebase_created_at,zone_id,payment_status,payment_confirmed_at) select 'volume-'||i,'VOLUME-'||i,'orange',1000,now(),'z1','confirmed',now() from generate_series(1,1000) i");
  const readDurations = [];
  for (let attempt = 0; attempt < 3; attempt++) {
    const started = performance.now();
    const page = (await a1.query('select public.izytel_shared_available() r')).rows[0].r;
    readDurations.push(Math.round(performance.now() - started));
    assert.equal(page.orders.length, 100);
    assert(page.orders.every(order => order.zone_id === 'z1' && !JSON.stringify(order).includes('0700000018')));
  }
  note('a 1,000-order territorial backlog returns a bounded, masked 100-order page');
  await writeFile(join(root, fastProcessing ? 'docs/shared_queue/FAST_PROCESSING_INTEGRATION_RESULTS.json' : 'docs/shared_queue/INTEGRATION_TEST_RESULTS.json'), JSON.stringify({executed_at: new Date().toISOString(), fast_processing: fastProcessing, supplemental_migration_sha256: fastMigration ? createHash('sha256').update(fastMigration).digest('hex') : null, migration_sha256: createHash('sha256').update(migration).digest('hex'), passed: checks.length, checks, performance: {synthetic_backlog: 1000, page_size: 100, read_durations_ms: readDurations, scope: 'local fixture only; not a production capacity guarantee'}, fixture: {tables: new Set(columns.map(column => column.table)).size, functions: functions.length, source: 'catalog-only snapshot; synthetic rows'}, limits: ['Foreign keys to unrelated account tables and account lifecycle audit hooks are outside this fixture.', 'External HTTP/FCM transport and customer-inbox storage are local sinks; no remote mutation or real FCM send.']}, null, 2));
});
if (!process.argv.includes('--publication-only')) console.log(`ALL ${checks.length} integration checks passed`);
