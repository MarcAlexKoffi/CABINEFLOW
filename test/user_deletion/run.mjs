import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
const root=resolve(import.meta.dirname,'../..');
const {PGlite}=await import(pathToFileURL(resolve(root,'scratch/ussd_reprise_tools/node_modules/@electric-sql/pglite/dist/index.js')).href);
const db=new PGlite();let passed=0;
const test=async(name,fn)=>{await fn();passed++;console.log('PASS '+name);};
const query=(sql,params=[])=>db.query(sql,params);
async function identity(role='service_role'){await db.exec('reset role');await query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({role,sub:'admin'})]);await db.exec('set role '+role);}
const begin=(uid,request,extra={})=>query('select public.izytel_user_admin_begin($1,$2,$3,$4::jsonb,$5::jsonb) as result',['admin',uid,request,JSON.stringify({action:'delete',uid,confirmUid:uid,requestId:request,...extra}),JSON.stringify({email:'synthetic@example.invalid'})]);
try {
await db.exec(`create schema auth;create schema private;create role anon;create role authenticated;create role service_role bypassrls;
  grant usage on schema public,private,auth to anon,authenticated,service_role;
  create function auth.jwt() returns jsonb language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
  create table izytel_staff_access(firebase_uid text primary key,role text,is_active boolean,display_name text,updated_at timestamptz);
  create table phase5_agent_capacities(agent_id text primary key,agent_name text,is_active boolean,availability text,active_networks text[],zone_ids text[],authorized_networks text[],orange_capacity integer default 1000,updated_at timestamptz);
  create table partner_accounts(id uuid primary key default gen_random_uuid(),firebase_uid text unique,display_name text,phone_number text,status text,availability text,active_networks text[],zone_ids text[],authorized_networks text[],created_by_uid text,updated_at timestamptz);
  create table manager_profiles(firebase_uid text primary key,display_name text,email text,phone_number text,is_active boolean,is_available boolean,updated_at timestamptz);
  create table staff_profiles(firebase_uid text primary key,role text,first_name text,email text,phone_number text,updated_at timestamptz);
  create table territory_zones(id text primary key,manager_id text,is_active boolean,updated_at timestamptz);
  create table phase4_assignment_orders(order_id text primary key,assigned_agent_id text,assigned_cabiniste_id uuid references partner_accounts(id),assignment_state text,order_status text,amount integer);
  create table izytel_notification_devices(firebase_uid text,is_active boolean,updated_at timestamptz);
  create table territory_audit_events(id bigint,actor_uid text,action text,before_state jsonb,after_state jsonb,entity_type text,entity_id text,created_at timestamptz);
  create table preserved_ledger(id text,agent_id text,partner_id uuid references partner_accounts(id),amount integer);
  insert into izytel_staff_access values('admin','admin',true,'Admin',now()),('agent','agent',true,'Agent',now()),('manager','manager',true,'Manager',now());
  insert into phase5_agent_capacities(agent_id,agent_name,is_active,availability,active_networks) values('agent','Agent',true,'available',array['moov']);
  insert into partner_accounts(firebase_uid,display_name,status,availability) values('partner','Partner','active','available'),(null,'Legacy Partner','active','available');
  insert into manager_profiles(firebase_uid,is_active,is_available) values('manager',true,true);
  insert into territory_zones values('zone','manager',true,now());
  insert into phase4_assignment_orders values('historical','agent',null,'closed','completed',500),('partner-history',null,(select id from partner_accounts where firebase_uid='partner'),'closed','completed',200);
  insert into preserved_ledger values('ledger-agent','agent',null,750),('ledger-partner',null,(select id from partner_accounts where firebase_uid='partner'),500);
  insert into izytel_notification_devices values('agent',true,now());
  grant all on all tables in schema public to service_role;
`);
await db.exec(await readFile(resolve(root,'supabase/migrations/20261101062508_admin_accounts_lifecycle.sql'),'utf8'));
await db.exec(await readFile(resolve(root,'supabase/migrations/20261118050926_user_account_deletion_preserve_history.sql'),'utf8'));
const historyBefore=(await query('select to_jsonb(o) row from phase4_assignment_orders o order by order_id')).rows;
const ledgerBefore=(await query('select to_jsonb(l) row from preserved_ledger l order by id')).rows;
await identity();
await test('confirmation and self-deletion are checked before any mutation',async()=>{
  await assert.rejects(()=>begin('agent','bad-confirmation-0001',{confirmUid:'other'}),/INVALID_CONFIRMATION/);
  await assert.rejects(()=>begin('admin','self-delete-000001'),/SELF_ADMIN_OPERATION_FORBIDDEN/);
  assert.equal((await query('select count(*)::int n from izytel_user_admin_operations')).rows[0].n,0);
});
await test('assigned work and manager zones block deletion with precise reasons',async()=>{
  await db.exec("insert into phase4_assignment_orders values('ongoing','agent',null,'assigned','paidReady',100)");
  await assert.rejects(()=>begin('agent','ongoing-delete-0001'),/ACTIVE_ORDERS/);
  assert.equal((await query("select is_active from phase5_agent_capacities where agent_id='agent'")).rows[0].is_active,true);
  await db.exec("delete from phase4_assignment_orders where order_id='ongoing'");
  await assert.rejects(()=>begin('manager','manager-delete-0001'),/DELETE_ZONE_ASSIGNED/);
});
await test('deletion with historical activity reserves audit and denies all access atomically',async()=>{
  const op=(await begin('agent','agent-delete-000001')).rows[0].result;assert.equal(op.fresh,true);
  const a=(await query("select is_active,orange_capacity from phase5_agent_capacities where agent_id='agent'")).rows[0];
  assert.equal(a.is_active,false);assert.equal(a.orange_capacity,1000);
  assert.equal((await query("select is_active from izytel_notification_devices where firebase_uid='agent'")).rows[0].is_active,false);
  assert.equal((await query("select before_state->'business'->'agent'->>'orange_capacity' value from izytel_user_admin_operations where request_id='agent-delete-000001'")).rows[0].value,'1000');
  await query('select public.izytel_user_admin_delete_access($1)',['agent-delete-000001']);
  await query('select public.izytel_user_admin_finish($1,null)',['agent-delete-000001']);
});
await test('completed deletion replays without a second mutation and cannot be reactivated',async()=>{
  const before=(await query('select count(*)::int n from izytel_user_admin_audit_events')).rows[0].n;
  assert.equal((await begin('agent','agent-delete-000001')).rows[0].result.status,'completed');
  assert.equal((await query('select count(*)::int n from izytel_user_admin_audit_events')).rows[0].n,before);
  await assert.rejects(()=>begin('agent','agent-update-00001',{action:'update'}),/ACCOUNT_DELETED/);
});
await test('partner login deletion keeps partner identity and financial foreign keys intact',async()=>{
  await begin('partner','partner-delete-0001');
  await query('select public.izytel_user_admin_delete_access($1)',['partner-delete-0001']);
  await query('select public.izytel_user_admin_finish($1,null)',['partner-delete-0001']);
  const p=(await query("select status,availability,account_deleted_at from partner_accounts where firebase_uid='partner'")).rows[0];
  assert.equal(p.status,'suspended');assert.equal(p.availability,'unavailable');assert.ok(p.account_deleted_at);
});
await test('legacy partner without Auth identity is also removed from the registry',async()=>{
  const uid='partner:'+(await query('select id from partner_accounts where firebase_uid is null')).rows[0].id;
  await begin(uid,'legacy-delete-00001');
  await query('select public.izytel_user_admin_delete_access($1)',['legacy-delete-00001']);
  await query('select public.izytel_user_admin_finish($1,null)',['legacy-delete-00001']);
  assert.ok((await query('select account_deleted_at from partner_accounts where firebase_uid is null')).rows[0].account_deleted_at);
});
await test('no order, financial history or preserved balances are erased',async()=>{
  assert.deepEqual((await query('select to_jsonb(o) row from phase4_assignment_orders o order by order_id')).rows,historyBefore);
  assert.deepEqual((await query('select to_jsonb(l) row from preserved_ledger l order by id')).rows,ledgerBefore);
});
await test('public clients cannot call deletion RPC or restore deleted access',async()=>{
  await db.exec('reset role');await db.exec('grant select,update on phase5_agent_capacities to authenticated');
  await identity('authenticated');
  await assert.rejects(()=>query("select public.izytel_user_admin_delete_access('agent-delete-000001')"),e=>e.code==='42501');
  await assert.rejects(()=>query("update phase5_agent_capacities set is_active=true where agent_id='agent'"),/ACCOUNT_DELETED/);
  await identity('anon');await assert.rejects(()=>begin('agent','anonymous-delete-001'),e=>e.code==='42501');
});
console.log(`SQL SUMMARY: ${passed} passed, 0 failed; synthetic in-memory database only.`);
} finally {await db.close();}
