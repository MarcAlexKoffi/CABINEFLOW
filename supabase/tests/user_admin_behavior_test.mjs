import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {PGlite} from '../../scratch/ussd_reprise_tools/node_modules/@electric-sql/pglite/dist/index.js';
const db=new PGlite();
let passed=0;
const test=async(name,fn)=>{await fn();passed++;console.log('PASS '+name);};
const query=async(sql,params=[])=>(await db.query(sql,params)).rows;
try {
await db.exec(`
create schema private; create schema auth;
create role anon; create role authenticated; create role service_role;
grant usage on schema auth to public;
create function auth.jwt() returns jsonb language sql as $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
create table izytel_staff_access(firebase_uid text primary key,role text,is_active boolean,display_name text,created_at timestamptz default now(),updated_at timestamptz default now(),check(role in ('admin','manager','supervisor')));
create table manager_profiles(firebase_uid text primary key,display_name text,email text,phone_number text,is_active boolean,is_available boolean,updated_at timestamptz default now());
create table territory_zones(id text primary key,manager_id text,is_active boolean,updated_at timestamptz default now());
create table territory_audit_events(id uuid default gen_random_uuid(),entity_type text,entity_id text,action text,before_state jsonb,after_state jsonb,actor_uid text,created_at timestamptz default now());
create table phase5_agent_capacities(agent_id text primary key,agent_name text,is_active boolean,availability text,zone_ids text[],authorized_networks text[],active_networks text[],initialized_from text,orange_capacity bigint default 0,updated_at timestamptz default now());
create table partner_accounts(firebase_uid text unique,display_name text,phone_number text,status text,availability text,zone_ids text[],authorized_networks text[],active_networks text[] default '{}',created_by_uid text,updated_at timestamptz default now());
create table staff_profiles(firebase_uid text primary key,role text,first_name text,email text,phone_number text,updated_at timestamptz default now());
create table izytel_notification_devices(firebase_uid text,is_active boolean,updated_at timestamptz default now());
insert into izytel_staff_access(firebase_uid,role,is_active) values('admin','admin',true),('admin2','admin',true),('agent','manager',false);
insert into territory_zones values('z1',null,true,now()),('z2','other',true,now());
`);
const migration=await readFile(new URL('../migrations/20261101062508_admin_accounts_lifecycle.sql',import.meta.url),'utf8');
await db.exec(migration);
for(const role of ['anon','authenticated']) await test(role+' cannot execute privileged RPC',async()=>{
  await db.exec('set role '+role);
  await assert.rejects(()=>query("select izytel_user_admin_authorize('admin')"),e=>e.code==='42501');
  await db.exec('reset role');
});
await db.exec(`select set_config('request.jwt.claims','{"role":"service_role"}',false)`);
await test('service RPC rechecks active administrator',async()=>{
  assert.equal((await query("select izytel_user_admin_authorize('admin') ok"))[0].ok,true);
  await assert.rejects(()=>query("select izytel_user_admin_authorize('agent')"),/ADMIN_REQUIRED/);
});
const command=(role='agent',extra={})=>({action:'create',requestId:'req-1',name:'Test account',email:'test@example.invalid',phoneNumber:'010203',role,isActive:true,zoneIds:['z1'],authorizedNetworks:['orange'],...extra});
const begin=(id,uid,c)=>query('select izytel_user_admin_begin($1,$2,$3,$4::jsonb,null) result',['admin',uid,id,JSON.stringify(c)]);
const finish=id=>query('select izytel_user_admin_finish($1,null)',[id]);
for(const role of ['admin','manager','agent','cabiniste']) await test('create '+role+' inactive then activate then replay',async()=>{
  const uid='new-'+role,id='req-'+role,c=command(role,{requestId:id});
  assert.equal((await begin(id,uid,c))[0].result.fresh,true);
  await query('select izytel_user_admin_apply($1,false)',[id]);
  const table=role==='agent'?'phase5_agent_capacities':role==='cabiniste'?'partner_accounts':'izytel_staff_access';
  const field=role==='cabiniste'?'status':'is_active';const key=role==='agent'?'agent_id':'firebase_uid';
  assert.equal((await query(`select ${field} state from ${table} where ${key}=$1`,[uid]))[0].state,role==='cabiniste'?'suspended':false);
  await query('select izytel_user_admin_apply($1,true)',[id]);
  assert.equal((await query(`select ${field} state from ${table} where ${key}=$1`,[uid]))[0].state,role==='cabiniste'?'active':true);
  await finish(id);
  assert.equal((await begin(id,uid,c))[0].result.status,'completed');
});
await test('role changes retain balances and disable every previous population/device',async()=>{
  await db.exec(`update phase5_agent_capacities set orange_capacity=750 where agent_id='new-agent';insert into izytel_notification_devices values('new-agent',true,now());`);
  await begin('change-role','new-agent',command('cabiniste',{action:'update',requestId:'change-role'}));
  await query("select izytel_user_admin_apply('change-role',false)");await query("select izytel_user_admin_apply('change-role',true)");await finish('change-role');
  assert.deepEqual((await query("select is_active,orange_capacity::int from phase5_agent_capacities where agent_id='new-agent'"))[0],{is_active:false,orange_capacity:750});
  assert.equal((await query("select status from partner_accounts where firebase_uid='new-agent'"))[0].status,'active');
  assert.equal((await query("select is_active from izytel_notification_devices where firebase_uid='new-agent'"))[0].is_active,false);
});
await test('self, unknown zones, occupied zone and permanent deletion refused',async()=>{
  await assert.rejects(()=>begin('self','admin',command('agent')),/SELF_ADMIN/);
  await assert.rejects(()=>begin('bad-zone','target',command('agent',{zoneIds:['missing']})),/INVALID_ZONE/);
  await assert.rejects(()=>begin('occupied','target',command('manager',{zoneIds:['z2']})),/ZONE_OCCUPIED/);
  await assert.rejects(()=>begin('delete','target',{action:'delete'}),/REFERENCES_NOT_VERIFIED/);
});
await test('idempotency key cannot mutate a completed request',async()=>{
  await assert.rejects(()=>begin('req-agent','new-agent',command('admin',{requestId:'req-agent'})),/IDEMPOTENCY_CONFLICT/);
});
await test('independent denial survives a failed final provisioning transaction',async()=>{
  await begin('zone-race','new-manager',command('manager',{action:'update',requestId:'zone-race'}));
  await query("select izytel_user_admin_deny('zone-race')");
  await db.exec("update territory_zones set manager_id='concurrent-manager' where id='z1'");
  await assert.rejects(()=>query("select izytel_user_admin_apply('zone-race',true)"),/ZONE_OCCUPIED/);
  assert.equal((await query("select is_active from izytel_staff_access where firebase_uid='new-manager'"))[0].is_active,false);
  await finish('zone-race');
});
await test('last active administrator protected',async()=>{
  await db.exec("update izytel_staff_access set is_active=false where firebase_uid in ('admin','new-admin')");
  // admin2 is the only active admin; actor cannot target self even before count.
  const c=JSON.stringify(command('agent',{action:'update'}));
  await assert.rejects(()=>query('select izytel_user_admin_begin($1,$2,$3,$4::jsonb,null)',['admin2','admin2','last',c]),/SELF_ADMIN/);
  await db.exec("update izytel_staff_access set is_active=true where firebase_uid='admin'");
});
await test('territorial authorization changes remain visible in account history',async()=>{
  await db.exec(`insert into territory_audit_events(entity_type,entity_id,action,before_state,after_state,actor_uid) values('zone','z1','manager_reassigned','{"manager_id":"new-manager"}','{"manager_id":"other"}','admin')`);
  const events=(await query("select izytel_user_admin_history('admin','new-manager') result"))[0].result;
  assert.ok(events.some(e=>e.action==='territory_manager_reassigned'));
});
await test('failed saga blocks mutations and exposes audit history',async()=>{
  await begin('failed','failure-target',command());await query("select izytel_user_admin_finish('failed','PARTIAL_FAILURE')");
  await assert.rejects(()=>begin('after-failed','another-target',command()),/ADMIN_OPERATION_PENDING/);
  const rows=(await query("select izytel_user_admin_history('admin','failure-target') result"))[0].result;
  assert.equal(rows[0].status,'failed');assert.equal(rows[0].error_code,'PARTIAL_FAILURE');
});
await test('legacy SQL mutation cannot reactivate managed account',async()=>{
  await db.exec(`select set_config('request.jwt.claims','{"role":"authenticated"}',false)`);
  await assert.rejects(()=>query("update phase5_agent_capacities set is_active=true where agent_id='new-agent'"),/MANAGED_ACCOUNT_SERVER_REQUIRED/);
  await assert.rejects(()=>query("delete from partner_accounts where firebase_uid='new-agent'"),/MANAGED_ACCOUNT_SERVER_REQUIRED/);
  await assert.rejects(()=>query("insert into phase5_agent_capacities(agent_id,agent_name,is_active) values('new-cabiniste','legacy bypass',true)"),/MANAGED_ACCOUNT_SERVER_REQUIRED/);
  await db.exec("insert into partner_accounts(firebase_uid,display_name,status) values('unmanaged-legacy','Legacy','active')");
  await assert.rejects(()=>query("update partner_accounts set firebase_uid='new-admin' where firebase_uid='unmanaged-legacy'"),/MANAGED_ACCOUNT_SERVER_REQUIRED/);
});
await test('audit events remain append-only for the service API role',async()=>{
  await db.exec('set role service_role');
  await assert.rejects(()=>query("delete from izytel_user_admin_audit_events"),e=>e.code==='42501');
  await assert.rejects(()=>query("update izytel_user_admin_audit_events set error_code=null"),e=>e.code==='42501');
  await db.exec('reset role');
});
await test('legacy administrator cannot demote or disable their own SQL access',async()=>{
  await db.exec(`select set_config('request.jwt.claims','{"role":"authenticated","sub":"admin2"}',false)`);
  await assert.rejects(()=>query("update izytel_staff_access set role='manager' where firebase_uid='admin2'"),/SELF_ADMIN_OPERATION_FORBIDDEN/);
  await assert.rejects(()=>query("update izytel_staff_access set is_active=false where firebase_uid='admin2'"),/SELF_ADMIN_OPERATION_FORBIDDEN/);
});
await test('operational network edits retain audit without blocking the authorized RPC path',async()=>{
  await db.exec(`select set_config('request.jwt.claims','{"role":"authenticated","sub":"manager"}',false)`);
  await query("update phase5_agent_capacities set authorized_networks=array['mtn'] where agent_id='new-agent'");
  await db.exec(`select set_config('request.jwt.claims','{"role":"service_role"}',false)`);
  const events=(await query("select izytel_user_admin_history('admin','new-agent') result"))[0].result;
  assert.ok(events.some(e=>e.actor_uid==='manager'&&e.action==='access_phase5_agent_capacities_update'&&e.after_state.authorized_networks[0]==='mtn'));
});
await test('old token cannot reactivate a managed inactive notification device',async()=>{
  await db.exec(`select set_config('request.jwt.claims','{"role":"authenticated","sub":"new-manager"}',false)`);
  await assert.rejects(()=>query("insert into izytel_notification_devices(firebase_uid,is_active) values('new-manager',true)"),/ACCOUNT_INACTIVE/);
  await query("insert into izytel_notification_devices(firebase_uid,is_active) values('new-manager',false)");
  await assert.rejects(()=>query("update izytel_notification_devices set is_active=true where firebase_uid='new-manager'"),/ACCOUNT_INACTIVE/);
  await query("update izytel_notification_devices set is_active=false where firebase_uid='new-manager'");
  await db.exec(`select set_config('request.jwt.claims','{"role":"service_role"}',false)`);
  await query("update izytel_staff_access set is_active=true where firebase_uid='new-manager'");
  await db.exec(`select set_config('request.jwt.claims','{"role":"authenticated","sub":"new-manager"}',false)`);
  await query("update izytel_notification_devices set is_active=true where firebase_uid='new-manager'");
  assert.equal((await query("select is_active from izytel_notification_devices where firebase_uid='new-manager'"))[0].is_active,true);
});
await test('active partner and legacy client notification registration remain allowed',async()=>{
  await query("insert into izytel_notification_devices(firebase_uid,is_active) values('new-cabiniste',true),('legacy-client',true)");
  assert.equal((await query("select count(*)::int n from izytel_notification_devices where firebase_uid in ('new-cabiniste','legacy-client') and is_active"))[0].n,2);
});
await test('active managed Agent notification registration remains allowed',async()=>{
  await db.exec(`select set_config('request.jwt.claims','{"role":"service_role"}',false)`);
  await query("insert into izytel_user_admin_operations(request_id,actor_uid,target_uid,command,status) values('active-agent-device','admin','active-agent','{\"action\":\"create\"}','completed')");
  await query("insert into phase5_agent_capacities(agent_id,agent_name,is_active) values('active-agent','Active Agent',true)");
  await db.exec(`select set_config('request.jwt.claims','{"role":"authenticated","sub":"active-agent"}',false)`);
  await query("insert into izytel_notification_devices(firebase_uid,is_active) values('active-agent',true)");
  assert.equal((await query("select is_active from izytel_notification_devices where firebase_uid='active-agent'"))[0].is_active,true);
});
console.log(`PASS ${passed} SQL behavior checks`);
} finally {await db.close();}
