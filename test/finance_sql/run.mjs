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
console.log(`${passed} finance PostgreSQL cases passed`);
await db.close();
