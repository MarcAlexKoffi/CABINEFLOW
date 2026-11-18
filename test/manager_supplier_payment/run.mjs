import assert from 'node:assert/strict';
import {readFile,readdir} from 'node:fs/promises';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
const root=resolve(import.meta.dirname,'../..');
const {PGlite}=await import(pathToFileURL(resolve(root,'scratch/ussd_reprise_tools/node_modules/@electric-sql/pglite/dist/index.js')).href);
const db=new PGlite();let passed=0;
const query=(sql,params=[])=>db.query(sql,params);
const test=async(name,fn)=>{await fn();console.log('PASS '+name);passed++;};
async function identity(uid,valid=true){await db.exec('reset role');await query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:uid,role:'authenticated',iss:valid?'fixture-firebase':'untrusted'})]);await db.exec('set role authenticated');}
async function pay({supplier='s1',amount=1000,channel='wave',reference='WAVE-001',legacy=null,key='payment-001'}={}){
  return (await query('select public.phase5_record_supplier_payment($1,$2,$3,$4,null,$5,$6,$7) as id',[supplier,amount,channel,reference,'Forged name',legacy,key])).rows[0].id;
}
try{
await db.exec(`create schema auth;create schema private;create role anon;create role authenticated;
grant usage on schema public,private,auth to anon,authenticated;
create function auth.jwt() returns jsonb language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
create function public.is_izytel_firebase_jwt() returns boolean language sql stable as $$select auth.jwt()->>'iss'='fixture-firebase'$$;
create table public.izytel_staff_access(firebase_uid text primary key,role text,is_active boolean);
create table public.manager_profiles(firebase_uid text primary key,display_name text);
create table public.finance_suppliers(id text primary key,name text,is_deleted boolean,manager_id text);
create table public.phase5_supplier_accounts(supplier_id text primary key,supplier_name text,total_owed bigint,total_paid bigint,total_recharged bigint,last_payment_id uuid,updated_at timestamptz,check(total_paid<=total_owed));
create table public.phase5_supplier_payments(id uuid primary key,source_firestore_id text unique,operation_key text unique,supplier_id text,supplier_name text,amount bigint check(amount>0),payment_channel text,payment_reference text,note text,paid_at timestamptz,created_by_uid text,created_by_name text,created_at timestamptz);
insert into izytel_staff_access values('admin','admin',true),('manager-a','manager',true),('manager-b','manager',true),('agent','agent',true),('inactive','manager',false),('supervisor','supervisor',true);
insert into manager_profiles values('manager-a','Manager A'),('manager-b','Manager B');
insert into finance_suppliers values('s1','Own supplier',false,'manager-a'),('s2','Other supplier',false,'manager-b'),('s3','Admin supplier',false,null),('deleted','Deleted supplier',true,'manager-a');
insert into phase5_supplier_accounts values('s1','Own supplier',10000,0,10400,null,now()),('s2','Other supplier',20000,0,20800,null,now()),('s3','Admin supplier',5000,0,5200,null,now());
create function private.izytel_current_staff_role() returns text language sql stable security definer set search_path='' as $$select role from public.izytel_staff_access where firebase_uid=auth.jwt()->>'sub' and is_active$$;
create function private.is_izytel_finance_admin() returns boolean language sql stable security definer set search_path='' as $$select public.is_izytel_firebase_jwt() and coalesce(private.izytel_current_staff_role()='admin',false)$$;
create function private.izytel_manager_owns_supplier(p_supplier_id text) returns boolean language sql stable security definer set search_path='' as $$select coalesce(private.izytel_current_staff_role() in('manager','supervisor') and exists(select 1 from public.finance_suppliers where id=btrim(p_supplier_id) and not is_deleted and manager_id=auth.jwt()->>'sub'),false)$$;
alter table finance_suppliers enable row level security;alter table phase5_supplier_accounts enable row level security;alter table phase5_supplier_payments enable row level security;
grant select on finance_suppliers,phase5_supplier_accounts,phase5_supplier_payments to authenticated;
`);
const name=(await readdir(resolve(root,'supabase/migrations'))).find(n=>n.endsWith('_manager_supplier_payments.sql'));
assert.ok(name,'migration exists');await db.exec(await readFile(resolve(root,'supabase/migrations',name),'utf8'));
await db.exec(`create function public.phase5_record_supplier_payment(p_supplier_id text,p_amount bigint,p_channel text,p_reference text,p_note text,p_staff_name text,p_legacy_id text default null,p_operation_key text default null) returns text language sql set search_path='' as $$select private.phase5_record_supplier_payment(p_supplier_id,p_amount,p_channel,p_reference,p_note,p_staff_name,p_legacy_id,p_operation_key)$$;
revoke all on function public.phase5_record_supplier_payment(text,bigint,text,text,text,text,text,text) from public;
grant execute on function public.phase5_record_supplier_payment(text,bigint,text,text,text,text,text,text) to anon,authenticated;`);
await test('manager cannot pay a foreign or unassigned supplier',async()=>{
  await identity('manager-a');for(const supplier of ['s2','s3','deleted'])await assert.rejects(()=>pay({supplier}),/SUPPLIER_SCOPE_DENIED/);
});
let first;
await test('manager records an owned supplier payment with authenticated audit identity',async()=>{
  await identity('manager-a');first=await pay();await db.exec('reset role');
  const p=(await query('select * from phase5_supplier_payments')).rows[0];
  assert.equal(p.amount,1000);assert.equal(p.created_by_uid,'manager-a');assert.equal(p.created_by_name,'Manager A');
  assert.equal((await query("select total_paid from phase5_supplier_accounts where supplier_id='s1'")).rows[0].total_paid,1000);
});
await test('replaying the same intent and reference does not pay twice',async()=>{
  await identity('manager-a');assert.equal(await pay(),first);assert.equal(await pay({key:'another-key'}),first);
  await db.exec('reset role');assert.equal((await query('select count(*)::int n from phase5_supplier_payments')).rows[0].n,1);
});
await test('operation keys and payment references cannot be reused with different amounts',async()=>{
  await identity('manager-a');await assert.rejects(()=>pay({amount:2000}),/DUPLICATE_REFERENCE/);
  await assert.rejects(()=>pay({amount:2000,key:'different-key'}),/DUPLICATE_REFERENCE/);
});
await test('overpayments and invalid amounts, channels and references are refused',async()=>{
  for(const amount of [0,-1,null,10001])await assert.rejects(()=>pay({amount,reference:'OTHER',key:'other'}),/INVALID_AMOUNT|PAYMENT_EXCEEDS_BALANCE/);
  await assert.rejects(()=>pay({channel:'invalid'}),/INVALID_CHANNEL/);await assert.rejects(()=>pay({reference:''}),/INVALID_REFERENCE/);
});
await test('a manager cannot import arbitrary historical payments',async()=>{
  await assert.rejects(()=>pay({legacy:'forged-legacy'}),/ADMIN_REQUIRED/);
});
await test('non-managers, inactive users and non-Firebase sessions remain forbidden',async()=>{
  for(const uid of ['agent','inactive','supervisor','unknown']){await identity(uid);await assert.rejects(()=>pay(),/SUPPLIER_SCOPE_DENIED/);}
  await identity('manager-a',false);await assert.rejects(()=>pay(),/AUTH_REQUIRED/);
});
await test('another manager cannot replay the first manager payment',async()=>{
  await identity('manager-b');await assert.rejects(()=>pay(),/SUPPLIER_SCOPE_DENIED/);
  await assert.rejects(()=>pay({supplier:'s2'}),/DUPLICATE_REFERENCE/);
});
await test('admin retains access to other suppliers and existing balance guards',async()=>{
  await identity('admin');await pay({supplier:'s2',amount:2000,key:'admin-payment',reference:'ADMIN-001'});
  await pay({supplier:'s3',amount:500,key:'admin-unassigned',reference:'ADMIN-002'});
  await db.exec('reset role');assert.equal((await query("select total_paid from phase5_supplier_accounts where supplier_id='s2'")).rows[0].total_paid,2000);
});
await test('direct table writes remain unavailable to the manager',async()=>{
  await identity('manager-a');await assert.rejects(()=>query("update phase5_supplier_accounts set total_paid=0 where supplier_id='s1'"),e=>e.code==='42501');
});
console.log(`SQL SUMMARY: ${passed} passed, 0 failed; synthetic isolated database only.`);
}finally{await db.close();}
