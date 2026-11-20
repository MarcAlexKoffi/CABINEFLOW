// Synthetic, in-memory PostgreSQL only. No remote database connection.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
const root = resolve(import.meta.dirname, '../..');
const { PGlite } = await import(pathToFileURL(process.env.IZYTEL_PGLITE_MODULE ?? resolve(root, 'scratch/ussd_reprise_tools/node_modules/@electric-sql/pglite/dist/index.js')).href);
const db = new PGlite();
let passed = 0;
async function test(name, fn) { await fn(); passed++; console.log(`PASS ${name}`); }
await db.exec(`
create schema private; create schema auth;
create role anon; create role authenticated;
create function auth.jwt() returns jsonb language sql as $$ select '{"sub":"admin-test"}'::jsonb $$;
create function private.is_izytel_finance_admin() returns boolean language sql as $$ select coalesce(current_setting('test.admin',true),'true')='true' $$;
create function private.is_izytel_finance_staff() returns boolean language sql as $$ select true $$;
create function private.izytel_finance_actor_name() returns text language sql as $$ select 'Test Admin'::text $$;
create table public.finance_wave_settings(id int, opening_balance bigint,effective_at timestamptz);
create table public.finance_wave_balance_adjustments(effective_at timestamptz);
create table public.finance_customer_credits(updated_at timestamptz);
create table public.finance_customer_credit_settlements(amount bigint,payment_channel text,paid_at timestamptz);
create table public.finance_expenses(id uuid primary key,category text,amount bigint,description text,payment_channel text,payment_reference text,spent_at timestamptz,created_by_uid text,created_by_name text);
create table public.finance_daily_closings(closed_at timestamptz);
create table public.finance_suppliers(name text,is_deleted boolean);
create table public.phase5_supplier_accounts(supplier_name text);
create table public.phase5_agent_recharges(occurred_at timestamptz);
create table public.phase5_supplier_payments(amount bigint,payment_channel text,paid_at timestamptz);
create table public.phase5_commission_accounts(agent_name text);
create table public.phase5_commissions(earned_at timestamptz);
create table public.phase5_commission_payouts(amount bigint,payment_channel text,paid_at timestamptz);
create table public.compensation_payouts(actor_type text,amount bigint,currency text,payment_channel text,paid_at timestamptz);
create table public.phase5_agent_capacities(agent_name text);
create table public.phase5_network_movements(occurred_at timestamptz);
create table public.phase5_order_payments(confirmed_at timestamptz,paid_at timestamptz,updated_at timestamptz);
create table public.refunds(amount bigint,payment_channel text,refunded_at timestamptz,updated_at timestamptz);
create table public.phase4_assignment_orders(order_id text,order_reference text,network text,amount bigint,source text,client_name text,client_whatsapp_phone text,beneficiary_phone text,operation_type text,offer_label text,payment_status text,payment_reference text,payment_confirmed_at timestamptz,paid_at timestamptz,order_status text,assigned_agent_id text,assigned_agent_name text,processing_started_at timestamptz,completed_at timestamptz,failure_reason text,firebase_created_at timestamptz,created_at timestamptz,updated_at timestamptz);
create table public.phase5_success_finalizations(financial_applied_at timestamptz);
create table public.phase5_ledger_events(occurred_at timestamptz);
create table public.finance_audit_events(event_kind text,entity_type text,entity_id text,actor_uid text,actor_name text,payload jsonb,created_at timestamptz default now());
`);
const original = await readFile(resolve(root,'supabase/migrations/20260915104335_bo5_finance_backoffice_complete.sql'),'utf8');
const expense = original.slice(original.indexOf('create or replace function public.izytel_finance_record_expense('), original.indexOf('create or replace function public.izytel_finance_create_closing('));
await db.exec(expense);
const migration = await readFile(resolve(root,'supabase/migrations/20261101062456_finance_exact_wave_totals_and_expense_idempotency.sql'),'utf8');
await db.exec(migration);
await db.exec(`
insert into finance_wave_settings values(1,10000,'2026-11-01T08:00Z');
insert into phase4_assignment_orders(order_id,amount,payment_status,payment_confirmed_at,updated_at) select i::text,100,'confirmed','2026-11-01T09:00Z','2026-11-01T09:00Z' from generate_series(1,1201) i;
insert into phase4_assignment_orders(amount,payment_status,payment_confirmed_at) values(10000,'confirmed','2026-11-01T07:00Z'),(10000,'credit','2026-11-01T09:00Z');
update phase4_assignment_orders set network='orange',assigned_agent_id='agent-a',order_status='inProgress' where order_id is not null;
insert into finance_expenses(id,amount,payment_channel,spent_at) select gen_random_uuid(),10,'wave','2026-11-01T09:00Z' from generate_series(1,601);
insert into finance_expenses(id,amount,payment_channel,spent_at) values(gen_random_uuid(),10000,'cash','2026-11-01T09:00Z'),(gen_random_uuid(),10000,'wave','2026-11-01T07:00Z');
insert into finance_customer_credit_settlements values(80,'wave','2026-11-01T09:00Z'),(500,'cash','2026-11-01T09:00Z');
insert into phase5_supplier_payments values(90,'wave','2026-11-01T09:00Z');
insert into refunds values(100,'wave','2026-11-01T09:00Z',now()),(900,'wave',null,now());
insert into phase5_commission_payouts values(110,'wave','2026-11-01T09:00Z');
insert into compensation_payouts values('cabiniste',250,'XOF','wave','2026-11-01T09:00Z'),('cabiniste',900,'XOF','cash','2026-11-01T09:00Z'),('cabiniste',900,'XOF','wave','2026-11-01T07:00Z'),('agent',900,'XOF','wave','2026-11-01T09:00Z'),('cabiniste',900,'EUR','wave','2026-11-01T09:00Z');
`);
const snapshot = async () => (await db.query('select public.izytel_finance_snapshot() as value')).rows[0].value;
await test('exact totals exceed bounded detail windows and honor opening/canal',async()=>{
  const s = await snapshot();
  assert.equal(s.orders.length,1000);
  assert.equal(s.expenses.length,500);
  assert.deepEqual(s.committed_capacities,{orange:120100});
  assert.deepEqual(s.wave_totals,{client_payments:120100,credit_settlements:80,supplier_payments:90,expenses:6010,refunds:100,commission_payouts:110,cabiniste_payouts:250});
});
const record = (key, amount=23) => db.query(`select public.izytel_finance_record_expense_once('fees',$1,'Test expense','cash',null,$2) as id`,[amount,key]);
await test('lost response retry returns identical expense and one audit',async()=>{
  const a=await record('intent-retry'); const b=await record('intent-retry');
  assert.equal(a.rows[0].id,b.rows[0].id);
  assert.equal((await db.query("select count(*)::int as n from finance_audit_events where event_kind='expense_recorded'")).rows[0].n,1);
});
await test('same intention rejects changed payload', async()=>{
  await assert.rejects(()=>record('intent-retry',24),/OPERATION_KEY_PAYLOAD_MISMATCH/);
});
await test('distinct intentions allow otherwise identical cash expenses',async()=>{
  const a=await record('intent-second'); const b=await record('intent-third');
  assert.notEqual(a.rows[0].id,b.rows[0].id);
});
await test('validation failure leaves no receipt',async()=>{
  await assert.rejects(()=>record('intent-invalid',-1),/INVALID_AMOUNT/);
  assert.equal((await db.query("select count(*)::int as n from private.finance_operation_receipts where operation_key='intent-invalid'")).rows[0].n,0);
});
await test('client roles cannot bypass receipt endpoint but authorized wrapper works',async()=>{
  for (const role of ['anon','authenticated']) {
    await db.exec(`set role ${role}`);
    await assert.rejects(()=>db.query("select public.izytel_finance_record_expense('fees',1,'Expense','cash',null)"),/permission denied/);
    assert.ok((await record(`intent-role-${role}`)).rows[0].id);
    await db.exec('reset role');
  }
});
await test('unauthorized staff cannot read totals or record expense',async()=>{
  await db.exec("set test.admin='false'");
  await assert.rejects(()=>snapshot(),/ADMIN_REQUIRED/);
  await assert.rejects(()=>db.query("select public.izytel_bo75_finance_period_history('wave','2026-11-01','2026-11-02')"),/ADMIN_REQUIRED/);
  await assert.rejects(()=>record('intent-denied'),/ADMIN_REQUIRED/);
});
await db.exec("set test.admin='true'");
// Expand the minimal fixture only for the new consolidated snapshot contract.
await db.exec(`
alter table finance_customer_credits add id text,add order_id text,add order_reference text,add amount bigint default 0,add paid_amount bigint default 0,add status text default 'open',add created_at timestamptz;
alter table phase5_supplier_accounts add supplier_id text,add total_owed bigint default 0,add total_paid bigint default 0;
alter table phase5_commission_accounts add earned_total bigint default 0,add paid_total bigint default 0;
alter table phase5_commissions add commission_amount bigint default 0;
alter table phase5_agent_recharges add network text,add principal_amount bigint default 0,add bonus_amount bigint default 0,add received_amount bigint default 0;
alter table phase5_network_movements add order_id text,add direction text,add movement_type text,add network text,add amount bigint default 0;
alter table phase5_agent_capacities add agent_id text unique,add orange_capacity bigint default 0,add mtn_capacity bigint default 0,add moov_capacity bigint default 0,add initialized_from text,add legacy_seeded_at timestamptz,add created_at timestamptz,add updated_at timestamptz;
alter table phase5_order_payments add order_id text,add created_at timestamptz;
alter table refunds add order_id text,add status text,add legacy_firestore_id text;
create table partner_accounts(id uuid);
create table finance_change_feed(id int primary key,revision bigint);
insert into finance_change_feed values(1,1);
create function private.izytel_finance_phase5_touch() returns trigger language plpgsql as $$ begin update finance_change_feed set revision=revision+1; return null; end $$;
create function private.izytel_admin_cabiniste_finance_snapshot(uuid) returns jsonb language sql stable as $$ select '{"summary":{"balanceDue":75},"partners":[]}'::jsonb $$;
`);
const { readdir } = await import('node:fs/promises');
const syncName = (await readdir(resolve(root,'supabase/migrations'))).find(n=>n.endsWith('_finance_live_consistent_totals.sql'));
const syncMigration = await readFile(resolve(root,'supabase/migrations',syncName),'utf8');
// Closing body is exercised below with the real table fields used in production.
const numericClosingFields = 'client_receipts successful_orders_count successful_orders_amount supplier_recharge_principal supplier_recharge_bonus supplier_recharge_received supplier_payments credits_created credit_settlements customer_receivables expenses refunds commissions_earned commissions_paid orange_available orange_committed mtn_available mtn_committed moov_available moov_committed supplier_debt commission_debt wave_theoretical_balance wave_actual_balance wave_difference estimated_profit'.split(' ');
await db.exec(`alter table finance_daily_closings add date_key text unique,add wave_difference_note text,add closed_by_uid text,add closed_by_name text,${numericClosingFields.map(k=>`add ${k} bigint`).join(',')}`);
await db.exec(syncMigration);
const closingName=(await readdir(resolve(root,'supabase/migrations'))).find(n=>n.endsWith('_finance_closing_consistent_snapshot.sql'));
await db.exec(await readFile(resolve(root,'supabase/migrations',closingName),'utf8'));
await test('one snapshot includes exact credit balances beyond 500 dossiers and Cabiniste liability',async()=>{
  await db.exec(`insert into finance_customer_credits(id,amount,paid_amount,created_at,updated_at) select i::text,2,1,'2026-11-01',now() from generate_series(1,601) i`);
  const s=await snapshot();
  assert.equal(s.credits.length,500);
  assert.equal(s.global_totals.customer_receivables,601);
  assert.equal(s.global_totals.credits_granted,1202);
  assert.equal(s.global_totals.credits_paid,601);
  assert.equal(s.global_totals.credits_count,601);
  assert.equal(s.cabiniste_finance.summary.balanceDue,75);
});
await test('daily totals use all sources and honor channels and exact day boundaries',async()=>{
  const t=(await db.query("select private.izytel_finance_period_totals('2026-11-01','2026-11-02') as t")).rows[0].t;
  assert.equal(t.client_receipts,130100); // Includes the receipt before the Wave opening.
  assert.equal(t.credit_settlements,580);
  assert.deepEqual(t.credit_settlements_by_channel,{wave:80,cash:500});
  assert.equal(t.expenses,26010);
  assert.equal(t.expenses_wave,16010);
  assert.equal(t.refunds,100); // Pending refund has no execution date.
});
await test('period totals exceed 2000 detail rows without becoming truncated',async()=>{
  await db.exec(`insert into finance_expenses(id,amount,payment_channel,spent_at) select gen_random_uuid(),7,'cash','2026-11-02T12:00Z' from generate_series(1,2101)`);
  const p=(await db.query("select izytel_bo75_finance_period_history('expenses','2026-11-02','2026-11-02T23:59:59.999999Z') as p")).rows[0].p;
  assert.equal(p.expenses.length,2000);
  assert.equal(p.totals.expenses,14707);
  assert.equal(p.totals.expenses_count,2101);
});
await test('reconciliation compares full canonical tables instead of unequal history windows',async()=>{
  await db.exec(`insert into phase5_order_payments(order_id,created_at) select i::text,'2026-11-01' from generate_series(1,1201) i`);
  const s=await snapshot();
  assert.equal(s.orders.length,1000);
  assert.equal(s.order_payments.length,700);
  assert.equal(s.reconciliation_totals.orphan_payments,0);
  // The extra confirmed receipt deliberately has no ID/ledger in this fixture.
  assert.equal(s.reconciliation_totals.confirmed_without_ledger,1);
});
await test('legacy replay cannot overwrite a canonical Agent capacity',async()=>{
  await db.exec(`insert into phase5_agent_capacities(agent_id,orange_capacity,initialized_from) values('canonical-agent',4900,'supabase')`);
  await db.query(`select private.phase5_reconcile_capacity_snapshot($1::jsonb)`,[JSON.stringify({agent_id:'canonical-agent',orange_capacity:10000})]);
  const row=(await db.query("select orange_capacity,initialized_from from phase5_agent_capacities where agent_id='canonical-agent'")).rows[0];
  assert.deepEqual(row,{orange_capacity:4900,initialized_from:'supabase'});
  await db.query(`select private.phase5_reconcile_capacity_snapshot($1::jsonb)`,[JSON.stringify({agent_id:'new-legacy-agent',orange_capacity:300})]);
  assert.equal((await db.query("select orange_capacity from phase5_agent_capacities where agent_id='new-legacy-agent'")).rows[0].orange_capacity,300);
});
await test('partner changes invalidate finance and a rolled-back transaction leaves no signal',async()=>{
  const revision=async()=>(await db.query('select revision from finance_change_feed')).rows[0].revision;
  const before=await revision();
  await db.exec('begin; insert into partner_accounts values(gen_random_uuid()); rollback');
  assert.equal(await revision(),before);
  await db.exec('insert into partner_accounts values(gen_random_uuid())');
  assert.equal(await revision(),before+1);
});
await test('Wave closing deducts Cabiniste Wave payouts once and matches the live balance',async()=>{
  await db.exec(`update finance_wave_settings set opening_balance=10000,effective_at=date_trunc('day',now())-interval '1 hour';
    insert into compensation_payouts values('cabiniste',250,'XOF','wave',now()-interval '1 minute');`);
  const s=await snapshot();
  const wave=10000+s.wave_totals.client_payments+s.wave_totals.credit_settlements-s.wave_totals.supplier_payments-s.wave_totals.expenses-s.wave_totals.refunds-s.wave_totals.commission_payouts-s.wave_totals.cabiniste_payouts;
  const today=(await db.query("select to_char(now() at time zone 'Africa/Abidjan','YYYY-MM-DD') as d")).rows[0].d;
  await db.query('select izytel_finance_create_closing($1::jsonb)',[JSON.stringify({date_key:today,wave_actual_balance:wave})]);
  const c=(await db.query('select * from finance_daily_closings')).rows[0];
  assert.equal(c.wave_theoretical_balance,wave);
  assert.equal(c.wave_difference,0);
  for(const field of ['client_receipts','successful_orders_count','successful_orders_amount','supplier_payments','credit_settlements','expenses','refunds','commissions_earned','commissions_paid']) {
    assert.equal(c[field],s.day_totals[field]);
  }
  assert.equal(c.estimated_profit,s.day_totals.estimated_profit);
});
await test('private totals remain inaccessible to client roles',async()=>{
  for (const role of ['anon','authenticated']) {
    await db.exec(`set role ${role}`);
    await assert.rejects(()=>db.query("select private.izytel_finance_period_totals('2026-11-01','2026-11-02')"),/permission denied/);
    await db.exec('reset role');
  }
});
console.log(`${passed} finance PostgreSQL cases passed`);
await db.close();
