import assert from 'node:assert/strict';

// Run after the historical migration cases, against the final schema.
export async function runSharedFamilyCases({db,test,identity,rpc,denied,payload,current,create}) {
  await identity('test-admin','postgres');
  await db.exec("update public.ussd_execution_rules set status='disabled' where deleted_at is null");
  const businessBefore = (await db.query('select to_jsonb(o) as row from public.phase4_assignment_orders o order by order_id')).rows;
  await identity('test-admin');
  let family, shared;
  await test('shared family is created independently and rejects a different network',async()=>{
    family=await rpc('save_family',['moov','all','Folie commune']);
    await assert.rejects(()=>rpc('save_binding',['synthetic-orange',family,null,null]),/invalid_association/);
  });
  await test('creation is active in version one with truthful administrative validation',async()=>{
    shared=await create({service:'all',family_id:family,ussd_template:'*412*4*numéro#'});
    const row=await current(shared);
    assert.equal(row.status,'active');assert.equal(row.version,1);
    assert.equal(row.validation_method,'creation');assert.equal(row.validation_sim_type,null);
    assert.equal(row.validated_by,'test-admin');assert.ok(row.validated_at);
    const history=await rpc('history',[shared]);assert.equal(history.length,1);assert.equal(history[0].status,'active');
  });
  await test('same Folie syntax resolves both order services through stable offer bindings',async()=>{
    await rpc('save_binding',['synthetic-offer',family,null,null]);
    await rpc('save_binding',['moov-calls-500',family,null,null]);
    await identity('test-admin','postgres');
    await db.exec("insert into public.phase4_assignment_orders select 'order-folie-calls',network,'callBundle',amount,beneficiary_phone,'Folie appels',order_status,payment_status,assignment_state,assigned_agent_id,assigned_cabiniste_id,zone_id from public.phase4_assignment_orders where order_id='order-agent'");
    await identity('test-manager');await rpc('register_order_context',['order-folie-calls','moov-calls-500']);
    await rpc('register_order_context',['order-agent','synthetic-offer']);
    assert.ok((await rpc('configuration')).rules.some(r=>r.id===shared));
    await identity('test-manager-b');assert.ok(!(await rpc('configuration')).rules.some(r=>r.id===shared));
    await identity('test-agent');
    for(const order of ['order-agent','order-folie-calls']) {
      const result=await rpc('resolve',[order]);
      assert.equal(result.status,'available',JSON.stringify(result));assert.equal(result.rule.id,shared);assert.equal(result.code,'*412*4*0101010101#');
    }
  });
  await test('shared rule does not catch unassociated offers; exact rule keeps precedence',async()=>{
    await identity('test-admin');
    const generic=await create({service:'callBundle',priority:1000,ussd_template:'*412*1#'});
    const exact=await create({service:'callBundle',offer_id:'moov-calls-500',ussd_template:'*412*1#',priority:-1000});
    await identity('test-agent');assert.equal((await rpc('resolve',['order-folie-calls'])).rule.id,exact);
    await identity('test-admin','postgres');
    await db.exec("insert into public.phase4_assignment_orders select 'order-normal-calls',network,operation_type,amount,beneficiary_phone,'Appels normaux',order_status,payment_status,assignment_state,assigned_agent_id,assigned_cabiniste_id,zone_id from public.phase4_assignment_orders where order_id='order-folie-calls'");
    await identity('test-manager');await rpc('register_order_context',['order-normal-calls','unrelated-folie-title']);
    await identity('test-agent');assert.equal((await rpc('resolve',['order-normal-calls'])).rule.id,generic);
  });
  await test('conflicting creations are rejected atomically across shared and specific services',async()=>{
    await identity('test-admin');const before=(await rpc('configuration')).rules.length;
    await assert.rejects(()=>create({service:'internetSubscription',family_id:family}),/ambiguous_rule/);
    await assert.rejects(()=>create({service:'all',family_id:family}),/ambiguous_rule/);
    assert.equal((await rpc('configuration')).rules.length,before);
  });
  await test('invalid templates and incomplete offer variables never leave a saved draft',async()=>{
    const before=(await rpc('configuration')).rules.length;
    await assert.rejects(()=>create({ussd_template:'invalid'}),/invalid_template/);
    await assert.rejects(()=>create({service:'all',family_id:family,priority:5,ussd_template:'*412*{{offer_code}}#'}),/missing_offer_context/);
    assert.equal((await rpc('configuration')).rules.length,before);
    await assert.rejects(()=>rpc('save_binding',['synthetic-offer',family,'123',1]),/active_binding_in_use/);
  });
  await test('special family names stay extensible and support common or exact service rules',async()=>{
    for(const [network,label,offer,service] of [['orange','Maxit','synthetic-orange','callBundle'],['mtn','C’Chic',null,null],['moov','Passe nuit',null,null]]) {
      const id=await rpc('save_family',[network,'all',label]);assert.ok(id);
      if(offer) await rpc('save_binding',[offer,id,null,null]);
      const rule=await create({network,service:service??'all',family_id:id});assert.equal((await current(rule)).status,'active');
    }
    const balance=await create({network:'mtn',purpose:'balance',service:null,ussd_template:'*133#'});
    assert.equal((await current(balance)).status,'active');
  });
  await test('direct activation remains administrator-only and helper has no client grant',async()=>{
    for(const uid of ['test-manager','test-agent','test-cabiniste','test-customer']) {
      await identity(uid);await denied(()=>create({network:'mtn',priority:888}));
    }
    await identity('test-admin','postgres');
    const permissions=(await db.query("select has_function_privilege('anon','private.ussd_validate_rule(public.ussd_execution_rules)','EXECUTE') a,has_function_privilege('authenticated','private.ussd_validate_rule(public.ussd_execution_rules)','EXECUTE') b")).rows[0];
    assert.deepEqual(permissions,{a:false,b:false});
  });
  await test('existing order rows stay unchanged and editing still revokes the active version',async()=>{
    assert.deepEqual((await db.query("select to_jsonb(o) as row from public.phase4_assignment_orders o where order_id not in ('order-folie-calls','order-normal-calls') order by order_id")).rows,businessBefore);
    await identity('test-admin');const previous=await current(shared);
    await rpc('save_rule',[shared,previous.version,JSON.stringify(payload({service:'all',family_id:family}))],['uuid','integer','jsonb']);
    assert.equal((await current(shared)).status,'draft');
    await assert.rejects(()=>rpc('set_status',[shared,previous.version+1,'active',null]),/sim_validation_required/);
  });
}
