import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

export async function runAutomaticGroupCases({db,test,identity,rpc,denied,current,create,prepare}) {
  await identity('test-admin','postgres');
  await db.exec("update public.ussd_execution_rules set status='disabled' where deleted_at is null");
  const vectors=JSON.parse(await readFile(new URL('./catalog_offer_group_vectors.json',import.meta.url),'utf8'));
  for(const v of vectors) await db.query('insert into public.catalog_offers(id,network,service,operation_type,title,family_code) values($1,$2,$3,$3,$4,$5)',[v.id,v.network,v.operation_type,v.title,v.family_code]);
  const classify=(network,family,title)=>db.query('select private.ussd_catalog_offer_group($1,$2,$3) as result',[network,family,title]);
  await test('all 133 supplied catalogue offers classify correctly, including CChic SOCIAL',async()=>{
    for(const v of vectors) assert.equal((await classify(v.network,v.family_code,v.title)).rows[0].result,v.expected_group,v.id);
    assert.equal(vectors.filter(v=>v.expected_group==='folie').length,19);
    assert.equal(vectors.filter(v=>v.expected_group==='cchic').length,20);
    assert.equal(vectors.filter(v=>v.expected_group==='cchic'&&v.family_code==='SOCIAL').length,2);
  });
  await test('name variants recognize apostrophes and case without partial-word or foreign-network matches',async()=>{
    for(const title of ["C'Chic Appels",'C’CHIC social','c chic nuit','CCHIC Internet','C-Chic Mix']) assert.equal((await classify('mtn','SOCIAL',title)).rows[0].result,'cchic');
    for(const title of ['FOLIE Appels','MoovFolie Internet','Moov Folie nuit']) assert.equal((await classify('moov',null,title)).rows[0].result,'folie');
    for(const [network,title] of [['mtn','Chicory'],['moov','Foliettes'],['orange','Folie Internet'],['moov',"C'Chic"]]) assert.equal((await classify(network,null,title)).rows[0].result,null);
  });
  await identity('test-admin');
  let folie,chic,generic;
  await test('a single active rule is registered for each automatic group without any bindings',async()=>{
    folie=await create({service:'all',offer_group:'folie',ussd_template:'*412*4*{{msisdn_local}}#'});
    chic=await create({network:'mtn',service:'all',offer_group:'cchic',ussd_template:'*133*6*8*{{msisdn_local}}#'});
    generic=await create({service:'all',priority:10000,ussd_template:'*412*2*{{msisdn_local}}#'});
    for(const id of [folie,chic]) {const row=await current(id);assert.equal(row.status,'active');assert.equal(row.family_id,null);assert.equal(row.offer_id,null);}
    const offers=(await rpc('configuration')).offers;
    for(const v of vectors) assert.equal(offers.find(o=>o.id===v.id).offer_group,v.expected_group,v.id);
  });
  async function orderFor(v,id='auto-'+v.id) {
    await identity('test-admin','postgres');
    await db.query("insert into public.phase4_assignment_orders select $1,$2,$3,amount,$4,$5,order_status,payment_status,assignment_state,assigned_agent_id,assigned_cabiniste_id,zone_id from public.phase4_assignment_orders where order_id='order-agent'",[id,v.network,v.operation_type,v.network==='mtn'?'0505050505':'0101010101',v.title]);
    await identity('test-manager');await rpc('register_order_context',[id,v.id]);
    await identity('test-agent');return rpc('resolve',[id]);
  }
  await test('one Folie and one CChic rule resolve all 39 named offers across all catalogue services',async()=>{
    for(const v of vectors.filter(v=>v.expected_group)) {
      const r=await orderFor(v);assert.equal(r.status,'available',v.id);
      assert.equal(r.rule.id,v.expected_group==='folie'?folie:chic,v.id);
      assert.equal(r.code,v.expected_group==='folie'?'*412*4*0101010101#':'*133*6*8*0505050505#',v.id);
      assert.equal(r.context.offer_group,v.expected_group);
    }
    await identity('test-admin','postgres');
    assert.equal((await db.query("select count(*)::int as n from public.ussd_offer_bindings where offer_id=any($1)",[vectors.map(v=>v.id)])).rows[0].n,0);
  });
  await test('normal internet and a misleading order label do not get the Folie syntax',async()=>{
    const v=vectors.find(v=>v.network==='moov'&&v.family_code==='INTERNET');
    const r=await orderFor(v);assert.equal(r.rule.id,generic);
    await identity('test-admin','postgres');
    await db.exec("insert into public.phase4_assignment_orders select 'auto-no-context',network,operation_type,amount,beneficiary_phone,'Folie Internet',order_status,payment_status,assignment_state,assigned_agent_id,assigned_cabiniste_id,zone_id from public.phase4_assignment_orders where order_id='order-agent'");
    await identity('test-agent');assert.equal((await rpc('resolve',['auto-no-context'])).rule.id,generic);
  });
  await test('a future imported offer is recognized immediately, and renaming invalidates confirmation',async()=>{
    await identity('test-admin','postgres');
    await db.exec("insert into public.catalog_offers(id,network,service,operation_type,title,family_code) values('future-folie','moov','internetSubscription','internetSubscription','Folie nouveau forfait','INTERNET')");
    const before=await orderFor({id:'future-folie',network:'moov',operation_type:'internetSubscription',title:'Folie nouveau forfait'});
    assert.equal(before.rule.id,folie);
    await identity('test-admin','postgres');await db.exec("update public.catalog_offers set title='Internet classique' where id='future-folie'");
    await identity('test-agent');assert.equal((await rpc('resolve',['auto-future-folie'])).rule.id,generic);
    assert.equal((await prepare('auto-future-folie',before,'auto-name-changed')).reason,'rule_changed');
  });
  await test('explicit family and exact offer rules remain deterministic overrides',async()=>{
    await identity('test-admin');
    const family=await rpc('save_family',['moov','all','Exception explicite']);
    await rpc('save_binding',['MO-FOL-001',family,null,null]);
    const manual=await create({service:'all',family_id:family,priority:-1000});
    await identity('test-agent');assert.equal((await rpc('resolve',['auto-MO-FOL-001'])).rule.id,manual);
    await identity('test-admin');const exact=await create({offer_id:'MO-FOL-001',priority:-9999});
    await identity('test-agent');assert.equal((await rpc('resolve',['auto-MO-FOL-001'])).rule.id,exact);
  });
  await test('group conflicts, incompatible scopes and missing per-offer variables are rejected atomically',async()=>{
    await identity('test-admin');const before=(await rpc('configuration')).rules.length;
    await assert.rejects(()=>create({service:'all',offer_group:'folie'}),/ambiguous_rule/);
    await assert.rejects(()=>create({network:'mtn',service:'all',offer_group:'folie'}),e=>e.code==='23514');
    await assert.rejects(()=>create({service:'internetSubscription',offer_group:'folie'}),e=>e.code==='23514');
    await assert.rejects(()=>create({service:'all',offer_group:'folie',priority:8,ussd_template:'*412*{{offer_code}}#'}),/missing_offer_context/);
    assert.equal((await rpc('configuration')).rules.length,before);
  });
  await test('automatic groups stay scoped to managers and protected against non-admin writes',async()=>{
    await identity('test-manager');assert.ok((await rpc('configuration')).rules.some(r=>r.id===folie));
    await identity('test-manager-b');assert.ok(!(await rpc('configuration')).rules.some(r=>r.id===folie));
    for(const uid of ['test-agent','test-cabiniste','test-manager','test-customer']) {await identity(uid);await denied(()=>create({service:'all',offer_group:'folie',priority:444}));}
    await identity('test-admin','postgres');
    for(const role of ['anon','authenticated']) assert.equal((await db.query("select has_function_privilege($1,'private.ussd_catalog_offer_group(text,text,text)','EXECUTE') allowed",[role])).rows[0].allowed,false);
  });
  await test('per-offer variables cover only their group and remain protected from deletion or silent edits',async()=>{
    await identity('test-admin');
    const targets=vectors.filter(v=>v.expected_group==='cchic');
    for(const v of targets) await rpc('save_binding',[v.id,null,'123',2]);
    const variableRule=await create({network:'mtn',service:'all',offer_group:'cchic',priority:10,ussd_template:'*133*{{offer_code}}*{{quantity}}#'});
    await identity('test-agent');const r=await rpc('resolve',['auto-'+targets[0].id]);
    assert.equal(r.rule.id,variableRule);assert.equal(r.code,'*133*123*2#');
    await identity('test-admin');
    await assert.rejects(()=>rpc('delete_binding',[targets[0].id,1]),/active_binding_in_use/);
    await assert.rejects(()=>rpc('save_binding',[targets[0].id,null,'456',2]),/active_binding_in_use/);
    await identity('test-admin','postgres');
    await db.exec("insert into public.catalog_offers(id,network,service,operation_type,title,family_code) values('future-chic','mtn','internetSubscription','internetSubscription','CChic futur','CCHIC')");
    await identity('test-admin');
    await assert.rejects(()=>rpc('save_binding',['future-chic',null,null,null]),/missing_offer_context/);
    await rpc('save_binding',['future-chic',null,'789',3]);
    const future=await orderFor({id:'future-chic',network:'mtn',operation_type:'internetSubscription',title:'CChic futur'});
    assert.equal(future.rule.id,variableRule);assert.equal(future.code,'*133*789*3#');
  });
}
