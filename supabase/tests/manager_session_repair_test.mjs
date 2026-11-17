import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {PGlite} from '../../scratch/ussd_reprise_tools/node_modules/@electric-sql/pglite/dist/index.js';

const db = new PGlite();
const query = async (sql, args=[]) => (await db.query(sql,args)).rows;
let passed=0;
const test=async(name,fn)=>{await fn();passed++;console.log('PASS '+name);};
const claims=async(sub,valid=true)=>query("select set_config('request.jwt.claims',$1,false)", [JSON.stringify({sub,iss:valid?'firebase':'other'})]);
try {
  await db.exec(`
    create schema private; create schema auth;
    create role anon; create role authenticated;
    create function auth.jwt() returns jsonb language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
    create function public.is_izytel_firebase_jwt() returns boolean language sql stable as $$select coalesce(auth.jwt()->>'iss'='firebase',false)$$;
    create function private.is_izytel_finance_admin() returns boolean language sql stable as $$select auth.jwt()->>'sub'='admin'$$;
    create function private.izytel_staff_display_name() returns text language sql stable as $$select auth.jwt()->>'sub'$$;
    create function private.izytel_staff_can_access_agent(p_id text) returns boolean language sql stable as $$select private.is_izytel_finance_admin() or (auth.jwt()->>'sub'='manager' and p_id='agent')$$;
    create table territory_zones(id text,manager_id text,is_active boolean);
    create table izytel_staff_access(firebase_uid text,role text,is_active boolean);
    create function private.izytel_wc5_manager_owns_zone(p_zone_id text,p_manager_uid text) returns boolean language sql stable security definer set search_path='' as $$
      select exists(select 1 from public.territory_zones z join public.izytel_staff_access s on s.firebase_uid=z.manager_id
        where z.id=btrim(coalesce(p_zone_id,'')) and z.is_active=true and z.manager_id=btrim(coalesce(p_manager_uid,''))
          and s.is_active=true and s.role in ('manager','supervisor'))$$;
    create table phase4_assignment_orders(order_id text,zone_id text);
    create table customer_order_contexts(order_id text,zone_id text,updated_at timestamptz default now());
    create table support_requests(id text primary key,order_id text,status text,assigned_to text,assigned_to_name text,in_progress_at timestamptz,
      resolution_note text,resolved_at timestamptz,resolved_by text,resolved_by_name text,
      customer_notified_at timestamptz,customer_notified_by text,customer_notified_by_name text,notification_channel text,
      closed_at timestamptz,closed_by text,closed_by_name text,updated_at timestamptz);
    create table phase5_success_finalizations(order_id text,agent_id text,network text,order_amount bigint,financial_applied_at timestamptz default now());
    create table order_economics(order_id text,izytel_gross_gain bigint,reversed_at timestamptz);
    create table phase5_commissions(agent_id text,order_id text,order_reference text,network text,order_amount bigint,commission_amount bigint,earned_at timestamptz default now());
    create table phase5_commission_payouts(agent_id text,amount bigint,payment_channel text,payment_reference text,note text,paid_at timestamptz);
    create table phase5_network_movements(agent_id text,network text,direction text,movement_type text,amount bigint,capacity_before bigint,capacity_after bigint,order_reference text,occurred_at timestamptz);
    insert into territory_zones values('zone','manager',true),('other-zone','other-manager',true),('inactive','manager',false);
    insert into izytel_staff_access values('manager','manager',true),('other-manager','manager',true),('disabled','manager',false);
    insert into phase4_assignment_orders values('order','zone'),('other-order','other-zone'),('inactive-order','inactive');
    insert into customer_order_contexts(order_id,zone_id) values('context-order','zone');
    insert into support_requests(id,order_id,status) values('request','order','new'),('context-request','context-order','new'),('outside','other-order','new'),('unscoped','no-order','new'),('inactive','inactive-order','new');
    insert into phase5_success_finalizations(order_id,agent_id,network,order_amount) values('historical','agent','orange',1000);
    insert into phase5_commissions(agent_id,order_id,order_reference,network,order_amount,commission_amount) values('agent','historical','CF-FIXTURE','orange',1000,20);
  `);
  await db.exec(await readFile(new URL('../migrations/20261117203038_team_activity_and_manager_support_repair.sql',import.meta.url),'utf8'));
  await claims('manager');
  await test('agent history reads recorded commissions without any compensation plan',async()=>{
    const history=(await query("select private.izytel_team_member_activity_history('agent','agent',25) h"))[0].h;
    assert.equal(history.currentMonth.processedAmount,1000);
    assert.equal(history.currentMonth.commissionEarned,20);
    assert.equal(history.currentMonth.izytelGrossGain,null);
    assert.equal(history.earnings.length,1);
  });
  await test('recorded economics are returned without recalculating history',async()=>{
    await query("insert into order_economics values('historical',50,null)");
    assert.equal((await query("select private.izytel_team_member_activity_history('agent','agent',25) h"))[0].h.currentMonth.izytelGrossGain,50);
  });
  await test('agent history preserves scope denial',async()=>{
    await claims('other-manager');
    await assert.rejects(()=>query("select private.izytel_team_member_activity_history('agent','agent',25)"),e=>e.code==='42501');
  });
  for(const [uid,valid,id] of [['other-manager',true,'request'],['disabled',true,'request'],['customer',true,'request'],['manager',false,'request'],['manager',true,'unscoped'],['manager',true,'inactive']]) {
    await test(`support denies ${uid}/${valid}/${id} without mutations`,async()=>{
      await claims(uid,valid);
      await assert.rejects(()=>query('select izytel_take_support_request($1)',[id]),e=>e.code==='42501');
      assert.equal((await query('select status from support_requests where id=$1',[id]))[0].status,'new');
    });
  }
  await claims('manager');
  await test('manager processes a request in their zone through closure',async()=>{
    await query("select izytel_take_support_request('request')");
    await assert.rejects(()=>query("select izytel_take_support_request('request')"),/SUPPORT_TRANSITION_INVALID/);
    await query("select izytel_resolve_support_request('request','Service rétabli')");
    await assert.rejects(()=>query("select izytel_close_support_request('request')"),/SUPPORT_CLOSE_INVALID/);
    await query("select izytel_mark_support_customer_notified('request')");
    await query("select izytel_close_support_request('request')");
    const row=(await query("select * from support_requests where id='request'"))[0];
    assert.equal(row.status,'closed'); assert.equal(row.assigned_to,'manager'); assert.equal(row.closed_by,'manager');
  });
  await test('customer context supplies zone before assignment publication',async()=>{
    await query("select izytel_take_support_request('context-request')");
    assert.equal((await query("select status from support_requests where id='context-request'"))[0].status,'inProgress');
  });
  await test('administrator retains global access',async()=>{
    await claims('admin'); await query("select izytel_take_support_request('outside')");
    assert.equal((await query("select status from support_requests where id='outside'"))[0].status,'inProgress');
  });
  await test('internal authorization helper is not a client RPC',async()=>{
    assert.equal((await query("select has_function_privilege('authenticated','private.izytel_can_process_support_order(text)','execute') allowed"))[0].allowed,false);
  });
  console.log(`${passed} checks passed`);
} finally { await db.close(); }
