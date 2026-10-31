// Runs ONLY an in-memory PostgreSQL instance; this script has no network client.
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
const root = resolve(import.meta.dirname, '../..');
const modulePath = process.env.IZYTEL_PGLITE_MODULE ?? resolve(root,'scratch/ussd_20261031/tools/node_modules/@electric-sql/pglite/dist/index.js');
const { PGlite } = await import(pathToFileURL(modulePath).href);
const db = new PGlite();
let passed = 0;
async function test(name, run) { await run(); passed++; console.log(`PASS ${name}`); }
async function identity(uid, role='anon', issuer='synthetic-firebase') {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify(uid?{sub:uid,iss:issuer}:{})]);
  if (role !== 'postgres') await db.exec(`set role ${role === 'authenticated' ? 'authenticated' : 'anon'}`);
}
async function rpc(name, params=[], casts=[]) {
  const args=params.map((_,i)=>`$${i+1}${casts[i]?'::'+casts[i]:''}`).join(',');
  return (await db.query(`select public.izytel_ussd_${name}(${args}) as result`,params)).rows[0].result;
}
async function denied(fn, code='42501') { await assert.rejects(fn,e=> e.code===code); }
const payload = (extra={}) => ({network:'moov',service:'internetSubscription',actor_scope:'both',
  ussd_template:'*999*{{msisdn_local}}#',priority:0,effective_from:'2020-01-01T00:00:00Z',
  effective_until:null,family_id:null,offer_id:null,internal_note:'synthetic fixture',...extra});
async function create(extra={}) {return rpc('save_rule',[null,null,JSON.stringify(payload(extra))],['uuid','integer','jsonb']);}
async function current(id) {return (await rpc('configuration')).rules.find(r=>r.id===id);}
async function activate(id) {const r=await current(id);await rpc('set_status',[id,r.version,'active','SIM de test fictive']);return current(id);}
async function disable(id) {const r=await current(id);await rpc('set_status',[id,r.version,'disabled',null]);}
async function prepare(order,r,request) {return rpc('prepare',[order,r.rule.id,r.rule.version,JSON.stringify(r.context),request],['text','uuid','integer','jsonb','text']);}
try {
  await db.exec(await readFile(resolve(import.meta.dirname,'baseline_fixture.sql'),'utf8'));
  const migrations=await readdir(resolve(root,'supabase/migrations'));
  const migration=migrations.find(n=>n.endsWith('_ussd_dynamic_shortcuts_v1.sql'));
  assert.ok(migration,'local migration exists');
  await db.exec(await readFile(resolve(root,'supabase/migrations',migration),'utf8'));
  await test('all nine new tables have RLS and no client table grants',async()=>{
    const rows=(await db.query("select c.relname,c.relrowsecurity,has_table_privilege('anon',c.oid,'SELECT') as can_read,has_table_privilege('authenticated',c.oid,'TRUNCATE') as can_truncate from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and c.relname like 'ussd_%' order by c.relname")).rows;
    assert.equal(rows.length,9); for(const r of rows){assert.equal(r.relrowsecurity,true);assert.equal(r.can_read,false);assert.equal(r.can_truncate,false);}
  });
  const vectors=JSON.parse(await readFile(resolve(import.meta.dirname,'generation_vectors.json'),'utf8'));
  for(const v of vectors) await test(`SQL grammar: ${v.name}`,async()=>{
    const call=()=>db.query('select private.ussd_generate($1,$2,$3,$4,$5) as code',[v.template,v.beneficiary??null,v.amount??null,v.offer_code??null,v.quantity??null]);
    if(v.error) await assert.rejects(call,e=>e.message===v.error);else assert.equal((await call()).rows[0].code,v.expected);
  });
  await test('anonymous identity cannot read rules or use RPC',async()=>{
    await identity(null);await denied(()=>rpc('configuration'));await denied(()=>db.query('select * from public.ussd_execution_rules'));
  });
  await test('foreign Firebase issuer is rejected',async()=>{await identity('test-admin','anon','foreign');await denied(()=>rpc('configuration'));});
  for(const role of ['anon','authenticated']) {
    for(const uid of ['test-manager','test-agent','test-cabiniste','test-customer']) await test(`${role}: ${uid} cannot create rules`,async()=>{
      await identity(uid,role);await denied(()=>create());
    });
    await test(`${role}: admin can create a draft but cannot bypass table grants`,async()=>{
      await identity('test-admin',role);const id=await create({priority:role==='anon'?10:20});assert.equal((await current(id)).status,'draft');
      await denied(()=>db.query("update public.ussd_execution_rules set status='active'"));
    });
  }
  await identity('test-admin');
  let generic = await create();
  await test('human SIM validation required for activation',async()=>{await assert.rejects(()=>rpc('set_status',[generic,1,'active',null]),/sim_validation_required/);});
  await activate(generic);
  await test('same level priority and overlapping scope cannot be activated',async()=>{
    const other=await create({actor_scope:'agent'});await assert.rejects(()=>activate(other),/ambiguous_rule/);
  });
  let family,exact;
  await test('family and offer IDs reuse catalogue associations',async()=>{
    family=await rpc('save_family',['moov','internetSubscription','Famille synthétique']);
    await rpc('save_binding',['synthetic-offer',family,'00123',2]);
    await rpc('register_order_context',['order-agent','synthetic-offer']);
    await rpc('register_order_context',['order-cabiniste','synthetic-offer']);
    const bad=await rpc('save_family',['orange','callBundle','Autre famille']);
    await assert.rejects(()=>rpc('save_binding',['synthetic-offer',bad,'1',1]),/invalid_association/);
  });
  await test('generic offer-code variable cannot be activated without offer context',async()=>{
    const id=await create({ussd_template:'*999*{{offer_code}}#',priority:7});await assert.rejects(()=>activate(id),/missing_offer_context/);
  });
  let familyRule;
  await test('exact offer outranks family which outranks generic despite priority',async()=>{
    familyRule=await create({family_id:family,priority:-10});await activate(familyRule);
    exact=await create({offer_id:'synthetic-offer',ussd_template:'*999*{{offer_code}}*{{quantity}}#',priority:-100});await activate(exact);
    await identity('test-agent');assert.equal((await rpc('resolve',['order-agent'])).rule.id,exact);
    await identity('test-admin');await disable(exact);await identity('test-agent');assert.equal((await rpc('resolve',['order-agent'])).rule.id,familyRule);
    await identity('test-admin');await disable(familyRule);await identity('test-agent');assert.equal((await rpc('resolve',['order-agent'])).rule.id,generic);
    await identity('test-admin');await activate(exact);
  });
  await test('active binding is protected against silent code changes',async()=>{await assert.rejects(()=>rpc('save_binding',['synthetic-offer',family,'456',1]),/active_binding_in_use/);});
  await test('agents and cabinistes may resolve only their own assigned orders',async()=>{
    await identity('test-agent');assert.equal((await rpc('resolve',['order-agent'])).code,'*999*00123*2#');await denied(()=>rpc('resolve',['order-cabiniste']));
    await identity('test-cabiniste');assert.equal((await rpc('resolve',['order-cabiniste'])).status,'available');await denied(()=>rpc('resolve',['order-agent']));
    await identity('test-customer');await denied(()=>rpc('resolve',['order-agent']));
    await identity('test-admin');await denied(()=>rpc('resolve',['order-agent']));
  });
  await test('inactive actor loses launch permission immediately',async()=>{
    await identity('test-admin','postgres');await db.exec("update public.phase5_agent_capacities set is_active=false where agent_id='test-agent'");
    await identity('test-agent');await denied(()=>rpc('resolve',['order-agent']));
    await identity('test-admin','postgres');await db.exec("update public.phase5_agent_capacities set is_active=true where agent_id='test-agent'");
  });
  let attempt;
  await test('prepare and dialer outcome change no business row or capacity',async()=>{
    await identity('test-admin','postgres');const before=(await db.query('select to_jsonb(o) as row from public.phase4_assignment_orders o order by order_id')).rows;
    const capacities=(await db.query('select * from public.phase5_agent_capacities order by agent_id')).rows;
    await identity('test-agent');const r=await rpc('resolve',['order-agent']);attempt=await prepare('order-agent',r,'attempt-1');
    assert.ok(attempt.attempt_id);assert.ok(attempt.valid_for_ms>0 && attempt.valid_for_ms<=10000);await rpc('record_result',[attempt.attempt_id,'dialer_opened',null]);
    const duplicate=await prepare('order-agent',r,'attempt-1');assert.equal(duplicate.reason,'duplicate_attempt');
    await identity('test-admin','postgres');assert.deepEqual((await db.query('select to_jsonb(o) as row from public.phase4_assignment_orders o order by order_id')).rows,before);
    assert.deepEqual((await db.query('select * from public.phase5_agent_capacities order by agent_id')).rows,capacities);
  });
  await test('audit outcome owner is enforced and cannot be rewritten',async()=>{
    await identity('test-cabiniste');await assert.rejects(()=>rpc('record_result',[attempt.attempt_id,'failed','dialer_unavailable']));
    await identity('test-agent');await assert.rejects(()=>rpc('record_result',[attempt.attempt_id,'failed','dialer_unavailable']),/attempt_already_recorded/);
  });
  await test('revocation between preview and prepare blocks new launch',async()=>{
    await identity('test-agent');const r=await rpc('resolve',['order-agent']);
    await identity('test-admin');await disable(exact);
    await identity('test-agent');assert.equal((await prepare('order-agent',r,'attempt-revoked')).reason,'rule_changed');
    await identity('test-admin');await activate(exact);
  });
  await test('order change while confirming requires fresh confirmation',async()=>{
    await identity('test-agent');const r=await rpc('resolve',['order-agent']);
    await identity('test-admin','postgres');await db.exec("update public.phase4_assignment_orders set amount=2000 where order_id='order-agent'");
    await identity('test-agent');assert.equal((await prepare('order-agent',r,'attempt-stale')).reason,'rule_changed');
    await identity('test-admin','postgres');await db.exec("update public.phase4_assignment_orders set amount=1000 where order_id='order-agent'");
  });
  await test('editing active rule creates draft, preserves history, optimistic version enforced',async()=>{
    await identity('test-admin');const old=await current(exact);
    await rpc('save_rule',[exact,old.version,JSON.stringify(payload({offer_id:'synthetic-offer',ussd_template:'*999*{{offer_code}}#'}))],['uuid','integer','jsonb']);
    assert.equal((await current(exact)).status,'draft');const history=await rpc('history',[exact]);assert.ok(history.some(r=>r.version===old.version&&r.status==='active'));
    await assert.rejects(()=>rpc('set_status',[exact,old.version,'active','test']),/rule_changed/);
  });
  await test('future and expired rules are not selected',async()=>{
    await identity('test-admin');const future=await create({priority:1000,effective_from:'2100-01-01T00:00:00Z'});await activate(future);
    const expired=await create({effective_from:'2000-01-01T00:00:00Z',effective_until:'2001-01-01T00:00:00Z'});await assert.rejects(()=>activate(expired),/expired_rule/);
    await identity('test-agent');assert.equal((await rpc('resolve',['order-agent'])).rule.id,generic);
  });
  await test('manager reads only relevant rule scope and cannot launch',async()=>{
    await identity('test-admin');const id=await create({network:'orange',service:'callBundle'});await activate(id);
    await identity('test-manager');assert.ok(!(await rpc('configuration')).rules.some(r=>r.id===id));await denied(()=>rpc('resolve',['order-agent']));
    await identity('test-manager-b');assert.ok((await rpc('configuration')).rules.some(r=>r.id===id));
  });
  let report;
  await test('Agent and Cabiniste reports share supervision with territorial isolation',async()=>{
    await identity('test-agent');const r=await rpc('resolve',['order-agent']);report=await rpc('report',['order-agent',r.rule.id,r.rule.version,'incorrect_code','Menu à vérifier']);
    await identity('test-cabiniste');await rpc('report',['order-cabiniste',null,null,'other','SIM à vérifier']);
    await identity('test-manager-b');assert.equal((await rpc('reports')).length,0);await denied(()=>rpc('review_report',[report,'resolved','test']));
    await identity('test-manager');assert.equal((await rpc('reports')).length,2);await rpc('review_report',[report,'escalated','Validation Administrateur nécessaire']);
    const rows=await rpc('reports');assert.equal(rows.find(r=>r.id===report).events.length,2);
  });
  await test('report rejects full beneficiary/code and customer writes',async()=>{
    await identity('test-agent');await assert.rejects(()=>rpc('report',['order-agent',null,null,'other','0101010101']),/sensitive_report_content/);
    await assert.rejects(()=>rpc('report',['order-agent',null,null,'other','*999*2#']),/sensitive_report_content/);
    await identity('test-customer');await denied(()=>rpc('report',['order-agent',null,null,'other','test']));
  });
  await test('logs contain no full code, beneficiary or JWT',async()=>{
    await identity('test-admin');const text=JSON.stringify(await rpc('logs'));
    assert.ok(!text.includes('*999')&&!text.includes('0101010101')&&!text.includes('synthetic-firebase'));
  });
  await test('non-processable and no-rule conditions preserve manual processing',async()=>{
    await identity('test-admin','postgres');await db.exec("update public.phase4_assignment_orders set order_status='completed' where order_id='order-agent'");
    await identity('test-agent');assert.equal((await rpc('resolve',['order-agent'])).reason,'order_not_processable');
    await identity('test-admin','postgres');await db.exec("update public.phase4_assignment_orders set order_status='inProgress' where order_id='order-agent'");
    await identity('test-admin');await disable(generic);await identity('test-agent');assert.equal((await rpc('resolve',['order-agent'])).reason,'no_rule');
  });
  for(const uid of ['test-manager','test-agent','test-cabiniste','test-customer']) {
    await test(`${uid}: all configuration mutations and version histories are protected`,async()=>{
      await identity(uid);await denied(()=>rpc('save_family',['moov','internetSubscription','Interdit']));
      await denied(()=>rpc('save_binding',['synthetic-offer',family,'1',1]));
      await denied(()=>rpc('set_status',[generic,1,'active','test']));
      await denied(()=>rpc('history',[generic]));await denied(()=>rpc('binding_history',['synthetic-offer']));
    });
  }
  await test('staff-synchronized offer identity outranks customer registry and labels are never matched',async()=>{
    await identity('test-admin');await activate(generic);await activate(exact);
    await identity('test-admin','postgres');
    await db.exec("insert into public.phase4_assignment_orders select 'legacy-order',network,operation_type,amount,beneficiary_phone,offer_label,order_status,payment_status,assignment_state,assigned_agent_id,assigned_cabiniste_id,zone_id from public.phase4_assignment_orders where order_id='order-agent'; insert into public.customer_order_recovery_registry values('legacy-order','synthetic-offer')");
    await identity('test-agent');assert.equal((await rpc('resolve',['legacy-order'])).rule.id,generic);
    await denied(()=>rpc('register_order_context',['legacy-order','synthetic-offer']));
    await identity('test-admin');await rpc('register_order_context',['legacy-order','synthetic-offer']);
    await identity('test-agent');assert.equal((await rpc('resolve',['legacy-order'])).rule.id,exact);
  });
  await test('Manager cannot register another territory order context',async()=>{
    await identity('test-manager');await denied(()=>rpc('register_order_context',['order-zone-b','synthetic-orange']));
  });
  await test('network mismatch warns without changing confirmed order network',async()=>{
    await identity('test-admin','postgres');await db.exec("update public.phase4_assignment_orders set beneficiary_phone='0707070707' where order_id='order-agent'");
    await identity('test-agent');const r=await rpc('resolve',['order-agent']);assert.equal(r.network_mismatch,true);assert.equal(r.context.network,'moov');
    await identity('test-admin','postgres');await db.exec("update public.phase4_assignment_orders set beneficiary_phone='+2250101010101' where order_id='order-agent'");
  });
  await test('inactive Cabiniste and revoked network authorizations cannot execute',async()=>{
    await identity('test-admin','postgres');await db.exec("update public.partner_accounts set status='inactive'");
    await identity('test-cabiniste');await denied(()=>rpc('resolve',['order-cabiniste']));
    await identity('test-admin','postgres');await db.exec("update public.partner_accounts set status='active'; update public.phase5_agent_capacities set authorized_networks=array['orange'] where agent_id='test-agent'");
    await identity('test-agent');await denied(()=>rpc('resolve',['order-agent']));
    await identity('test-admin','postgres');await db.exec("update public.phase5_agent_capacities set authorized_networks=array['orange','mtn','moov'] where agent_id='test-agent'");
  });
  await test('ambiguous double assignment refuses both actors',async()=>{
    await identity('test-admin','postgres');await db.exec("update public.phase4_assignment_orders set assigned_cabiniste_id='00000000-0000-4000-8000-000000000001' where order_id='order-agent'");
    for(const uid of ['test-agent','test-cabiniste']){await identity(uid);await denied(()=>rpc('resolve',['order-agent']));}
    await identity('test-admin','postgres');await db.exec("update public.phase4_assignment_orders set assigned_cabiniste_id=null where order_id='order-agent'");
  });
  await test('staff role cannot execute with a leftover active Agent profile',async()=>{
    await identity('test-admin','postgres');await db.exec("insert into public.izytel_staff_access values('test-agent','manager',true)");
    await identity('test-agent');await denied(()=>rpc('resolve',['order-agent']));
    await identity('test-admin','postgres');await db.exec("delete from public.izytel_staff_access where firebase_uid='test-agent'");
  });
  await test('report privacy validation also catches formatted phone numbers',async()=>{
    await identity('test-agent');await assert.rejects(()=>rpc('report',['order-agent',null,null,'other','+225 01 01 01 01 01']),/sensitive_report_content/);
  });
  await test('unimplemented business SMS service remains a draft',async()=>{
    await identity('test-admin');const id=await create({service:'sms',ussd_template:'*999#'});
    await assert.rejects(()=>activate(id),/unsupported_order_service/);assert.equal((await current(id)).status,'draft');
  });
  await test('binding revisions are immutable and retrievable for historical logs',async()=>{
    await identity('test-admin');await disable(exact);await rpc('save_binding',['synthetic-offer',family,'456',1]);
    const history=await rpc('binding_history',['synthetic-offer']);assert.equal(history.length,2);
    assert.equal(history[0].offer_code,'456');assert.equal(history[1].offer_code,'00123');
    await denied(()=>db.exec("delete from public.ussd_binding_versions"));
  });
  await test('a report cannot reference a different offer shortcut',async()=>{
    await identity('test-admin','postgres');await db.exec("insert into public.catalog_offers(id,network,service,operation_type,title) values('other-offer','moov','internetSubscription','internetSubscription','Autre offre fictive')");
    await identity('test-admin');const id=await create({offer_id:'other-offer'});
    await identity('test-agent');await assert.rejects(()=>rpc('report',['order-agent',id,1,'wrong_offer','test']),/invalid_association/);
  });
  await test('prepare rate is bounded without repeated opening outcomes',async()=>{
    await identity('test-agent');const r=await rpc('resolve',['order-agent']);
    for(let i=0;i<9;i++){assert.ok((await prepare('order-agent',r,'burst-'+i)).attempt_id);}
    await assert.rejects(()=>prepare('order-agent',r,'burst-overflow'),/USSD_RATE_LIMIT/);
  });
  await test('Appels and mixed bundles use stable operation IDs despite shared catalogue service',async()=>{
    await identity('test-admin','postgres');
    await db.exec("insert into public.catalog_offers(id,network,service,operation_type,title) values('mixed-offer','mtn','calls','mixedBundle','Libelle fictif'); insert into public.phase4_assignment_orders values('mixed-order','mtn','mixedBundle',1000,'0505050505','Appels fictifs','inProgress','confirmed','accepted','test-agent',null,'zone-a')");
    await identity('test-admin');const mix=await create({network:'mtn',service:'mixedBundle',ussd_template:'*999*2#'});await activate(mix);
    const calls=await create({network:'mtn',service:'callBundle',ussd_template:'*999*1#'});await activate(calls);
    await identity('test-agent');const r=await rpc('resolve',['mixed-order']);assert.equal(r.rule.id,mix);assert.equal(r.code,'*999*2#');
  });
  console.log(`SQL SUMMARY: ${passed} passed, 0 failed; in-memory synthetic database only.`);
} finally {await db.close();}
