import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '../../scratch/ussd_reprise_tools/node_modules/@electric-sql/pglite/dist/index.js';
const db = new PGlite();
let passed=0;
const test=async(name,fn)=>{await fn();passed++;console.log('PASS '+name);};
try {
await db.exec(`
create role anon; create role authenticated;
create schema private;
create function private.is_izytel_finance_admin() returns boolean language sql as $$
select current_setting('test.admin',true)='true' $$;
create table public.finance_customer_credits(id text primary key,amount bigint);
create table public.finance_customer_credit_settlements(id uuid primary key);
create table public.finance_expenses(id uuid primary key, amount bigint);
create table public.finance_wave_settings(id smallint primary key);
create table public.finance_wave_balance_adjustments(id uuid primary key);
create table public.finance_daily_closings(date_key text primary key);
create table public.phase5_supplier_accounts(supplier_id text primary key);
create table public.phase5_agent_recharges(source_firestore_id text primary key);
create table public.phase5_supplier_payments(id uuid primary key);
insert into public.finance_customer_credits select lpad(n::text,4,'0'),n from generate_series(1,1007) n;
`);
await db.exec(await readFile(new URL('../../supabase/migrations/20261101012308_finance_mobile_canonical_reads.sql',import.meta.url),'utf8'));
for(const role of ['anon','authenticated']){
 await db.exec('set role '+role);
 await db.exec("select set_config('test.admin','false',false)");
 await test(role+' non-admin denied',async()=>assert.rejects(()=>db.query("select public.izytel_finance_read_page('credits')"),e=>e.code==='42501'));
 await db.exec("select set_config('test.admin','true',false)");
 await test(role+' cannot bypass RPC table access',async()=>assert.rejects(()=>db.query('select * from public.finance_customer_credits'),e=>e.code==='42501'));
 await test(role+' closed dataset whitelist and bounded pages',async()=>{
  for(const kind of ["users","finance_customer_credits; drop table public.finance_expenses;--"])
   await assert.rejects(()=>db.query('select public.izytel_finance_read_page($1)',[kind]),e=>e.code==='22023');
  for(const limit of [0,501,null]) await assert.rejects(()=>db.query("select public.izytel_finance_read_page('credits',null,$1)",[limit]),e=>e.code==='22023');
 });
 await test(role+' keyset pagination reads all 1007 credits once',async()=>{
  let after=null;const all=[];
  while(true){const page=(await db.query("select public.izytel_finance_read_page('credits',$1,250) as rows",[after])).rows[0].rows;
   all.push(...page);if(page.length<250)break;after=page.at(-1).id;
  }
  assert.equal(all.length,1007);assert.equal(new Set(all.map(r=>r.id)).size,1007);
  assert.equal(all.reduce((s,r)=>s+r.amount,0),1007*1008/2);
 });
 await test(role+' every mapped dataset can be read',async()=>{
  for(const kind of ['settlements','expenses','opening','adjustments','closings','supplier_accounts','supplier_recharges','supplier_payments']){
   assert.deepEqual((await db.query('select public.izytel_finance_read_page($1) as rows',[kind])).rows[0].rows,[]);
  }
 });
 await db.exec('reset role');
}
console.log(passed+' finance mobile SQL tests passed');
} finally {await db.close();}

