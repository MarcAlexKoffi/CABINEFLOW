import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {PGlite} from '../../scratch/ussd_reprise_tools/node_modules/@electric-sql/pglite/dist/index.js';

const db=new PGlite();
const query=async(sql,params=[])=>(await db.query(sql,params)).rows;
let passed=0;
const test=async(name,fn)=>{await fn();passed++;console.log('PASS '+name);};
const claims=async(sub,role='authenticated')=>query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub,role})]);
try {
  await db.exec(`
    create schema private; create schema auth;
    create function auth.jwt() returns jsonb language sql as $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
    create function public.is_izytel_firebase_jwt() returns boolean language sql as $$select auth.jwt()->>'sub' is not null$$;
    create function private.is_izytel_finance_admin() returns boolean language sql as $$select auth.jwt()->>'sub'='admin'$$;
    create function private.izytel_current_staff_role() returns text language sql as $$select case auth.jwt()->>'sub' when 'admin' then 'admin' when 'manager' then 'manager' else 'agent' end$$;
    create function private.izytel_manager_can_access_agent(p_id text) returns boolean language sql as $$select auth.jwt()->>'sub'='manager' and p_id='agent'$$;
    create table phase5_agent_capacities(agent_id text primary key,agent_name text,orange_capacity bigint default 0,mtn_capacity bigint default 0,moov_capacity bigint default 0,initialized_from text,agent_code text,zone_ids text[],is_active boolean,availability text,authorized_networks text[],active_networks text[],daily_transaction_limit bigint,max_transactions_per_day int,last_seen_at timestamptz,updated_at timestamptz);
    create table izytel_staff_access(firebase_uid text,role text,is_active boolean);
    create table izytel_user_admin_operations(target_uid text,command jsonb);
    create table phase5_network_movements(id uuid default gen_random_uuid(),source_key text,network text,direction text,movement_type text,amount bigint,capacity_before bigint,capacity_after bigint,agent_id text,agent_name text,created_by_uid text,created_by_name text,created_by_role text,occurred_at timestamptz);
    create table phase5_ledger_events(source_collection text,source_id text,event_kind text,agent_id text,agent_name text,network text,amount bigint,occurred_at timestamptz,payload jsonb);
    create view movements as select network,capacity_before as before_amount,capacity_after as after_amount from phase5_network_movements;
    insert into phase5_agent_capacities values('agent','Agent',10400,2000,0,'supabase','AG-1',array['zone1'],true,'available',array['orange','mtn','moov'],array['orange'],500000,150,null,now());
    insert into izytel_user_admin_operations values('agent','{"action":"create"}');
  `);
  const lifecycle=await readFile(new URL('../migrations/20261101062508_admin_accounts_lifecycle.sql',import.meta.url),'utf8');
  const guard=lifecycle.slice(lifecycle.indexOf('create function private.izytel_guard_managed_account_access()'),lifecycle.indexOf('revoke all on function private.izytel_guard_managed_account_access()'));
  await db.exec(guard+`create trigger managed_guard before insert or update or delete on phase5_agent_capacities for each row execute function private.izytel_guard_managed_account_access();`);
  await db.exec(await readFile(new URL('../migrations/20261102012359_agent_operations_staff_capacity.sql',import.meta.url),'utf8'));
  await claims('agent');
  await test('generic adjustment RPC cannot be used to bypass Agent restrictions',async()=>{
    await assert.rejects(()=>query("select phase5_adjust_capacity('agent','Agent','orange',90000,'Agent','admin')"),e=>e.code==='42501'&&/CAPACITY_STAFF_REQUIRED/.test(e.message));
  });
  await test('availability and network switches preserve all balances',async()=>{
    const result=(await query("select phase3_update_own_agent_operations('unavailable',array['mtn']) as profile"))[0].profile;
    assert.equal(result.orange_capacity,10400); assert.equal(result.mtn_capacity,2000);
    assert.deepEqual(result.active_networks,['mtn']); assert.equal((await query('select count(*)::int n from movements'))[0].n,0);
  });
  for(const amounts of [[20000,2000,0],[10400,5000,0],[10400,2000,100]]) await test('legacy client cannot change balance '+amounts,async()=>{
    await assert.rejects(()=>query("select phase3_update_own_agent_operations('available',array['orange'],$1,$2,$3)",amounts),e=>e.code==='42501'&&/CAPACITY_STAFF_REQUIRED/.test(e.message));
  });
  await test('unapproved network remains forbidden',async()=>{
    await assert.rejects(()=>query("select phase3_update_own_agent_operations('available',array['unknown'])"),/NETWORK_NOT_AUTHORIZED/);
  });
  await claims('admin');
  await test('old upsert reproduces managed account failure',async()=>{
    await assert.rejects(()=>query("insert into phase5_agent_capacities(agent_id) values('agent') on conflict(agent_id) do update set updated_at=now()"),/MANAGED_ACCOUNT_SERVER_REQUIRED/);
  });
  const adminUpdate=(zones,orange=10400)=>query("select private.phase3_admin_update_agent_operations('agent','Agent',true,$1,array['orange','mtn','moov'],array['orange'],500000,150,$2,2000,0) as profile",[zones,orange]);
  await test('direct access change still requires the authorized server',async()=>{
    await assert.rejects(()=>adminUpdate(['zone1','zone2']),/MANAGED_ACCOUNT_SERVER_REQUIRED/);
  });
  await claims('admin','service_role');
  await query("update phase5_agent_capacities set zone_ids=array['zone1','zone2'] where agent_id='agent'");
  await claims('admin');
  await test('admin saves a second zone after the administration gateway',async()=>{
    const p=(await adminUpdate(['zone1','zone2']))[0].profile;
    assert.deepEqual(p.zone_ids,['zone1','zone2']);assert.equal(p.orange_capacity,10400);
    assert.equal((await query('select count(*)::int n from movements'))[0].n,0);
  });
  await test('admin balance adjustment remains traced',async()=>{
    assert.equal((await adminUpdate(['zone1','zone2'],12000))[0].profile.orange_capacity,12000);
    assert.deepEqual((await query('select * from movements')),[{network:'orange',before_amount:10400,after_amount:12000}]);
  });
  await claims('agent');
  await test('new client switches availability after recharge without restoring stale stock',async()=>{
    assert.equal((await query("select phase3_update_own_agent_operations('available',array['orange']) as p"))[0].p.orange_capacity,12000);
  });
  await test('agent cannot call the admin operation',async()=>{
    await assert.rejects(()=>adminUpdate(['zone1','zone2']),e=>e.code==='42501');
  });
  await claims('manager');
  await test('scoped Manager can still adjust and journal a balance',async()=>{
    const result=(await query("select phase5_adjust_capacity('agent','Agent','mtn',3000,'Manager','manager') as result"))[0].result;
    assert.equal(result.capacity_after,3000);
    assert.equal((await query("select created_by_role from phase5_network_movements where network='mtn'"))[0].created_by_role,'manager');
  });
  console.log(`${passed} tests passed`);
} catch (error) {
  console.error(error.code || 'TEST_FAILED', error.message);
  process.exitCode=1;
} finally { await db.close(); }
