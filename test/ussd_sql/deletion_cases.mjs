import assert from 'node:assert/strict';

export async function runDeletionCases({db,test,identity,rpc,denied,payload,current,create,activate,prepare}) {
  await identity('test-admin');
  const draft=await create({service:'unitTransfer'});
  const family=await rpc('save_family',['moov','unitTransfer','Famille à supprimer']);
  for(const role of ['anon','authenticated']) {
    for(const uid of [null,'test-manager','test-agent','test-cabiniste','test-customer']) {
      await test(`${role}: ${uid??'no identity'} cannot delete any USSD configuration`,async()=>{
        await identity(uid,role);
        await denied(()=>rpc('delete_rule',[draft,1]));
        await denied(()=>rpc('delete_family',[family]));
        await denied(()=>rpc('delete_binding',['synthetic-offer',1]));
      });
    }
  }
  await test('a foreign Firebase issuer cannot delete USSD configuration',async()=>{
    await identity('test-admin','anon','foreign');
    await denied(()=>rpc('delete_rule',[draft,1]));
    await denied(()=>rpc('delete_family',[family]));
    await denied(()=>rpc('delete_binding',['synthetic-offer',1]));
  });
  await test('Admin deletes a draft with history and a replay creates no duplicate version',async()=>{
    await identity('test-admin');
    await assert.rejects(()=>rpc('delete_rule',[draft,9]),/rule_changed/);
    assert.ok(await current(draft));
    await rpc('delete_rule',[draft,1]);
    assert.equal(await current(draft),undefined);
    const history=await rpc('history',[draft]);
    assert.equal(history.length,2);
    assert.equal(history[0].deleted_by,'test-admin');
    assert.equal(history[0].status,'disabled');
    assert.equal(history[1].status,'draft');
    await rpc('delete_rule',[draft,1]);
    assert.equal((await rpc('history',[draft])).length,2);
    await assert.rejects(()=>rpc('set_status',[draft,2,'active','SIM fictive']),/rule_deleted/);
    await assert.rejects(()=>rpc('save_rule',[draft,2,JSON.stringify(payload({service:'unitTransfer'}))],['uuid','integer','jsonb']),/rule_deleted/);
    await denied(()=>db.query('delete from public.ussd_execution_rules where id=$1',[draft]));
  });
  await test('Admin can delete an unused family and recreate its label under a new identity',async()=>{
    await identity('test-admin','authenticated');
    await rpc('delete_family',[family]);
    await rpc('delete_family',[family]);
    assert.ok(!(await rpc('configuration')).families.some(f=>f.id===family));
    const replacement=await rpc('save_family',['moov','unitTransfer','Famille à supprimer']);
    assert.notEqual(replacement,family);
    await assert.rejects(()=>create({service:'unitTransfer',family_id:family}),/invalid_association/);
  });
  let usedFamily, familyRule;
  await test('even a draft protects its family until its reference is removed',async()=>{
    await identity('test-admin');
    usedFamily=await rpc('save_family',['moov','internetSubscription','Famille utilisée']);
    familyRule=await create({family_id:usedFamily});
    await assert.rejects(()=>rpc('delete_family',[usedFamily]),/family_in_use/);
    await rpc('delete_rule',[familyRule,1]);
    await rpc('delete_family',[usedFamily]);
    assert.ok((await rpc('history',[familyRule])).some(r=>r.family_id===usedFamily));
    await assert.rejects(()=>rpc('save_binding',['synthetic-offer',usedFamily,'1',1]),/invalid_association/);
  });
  await test('deleting an active rule blocks a confirmation already open and keeps execution logs intact',async()=>{
    await identity('test-admin','postgres');
    // Isolate this resolver scenario from earlier active synthetic rules.
    const live=(await rpc('configuration')).rules.filter(r=>r.status==='active');
    for(const r of live) await rpc('set_status',[r.id,r.version,'disabled',null]);
    await db.exec("delete from public.ussd_execution_logs where actor_uid='test-agent'");
    const id=await create({priority:999});
    const active=await activate(id);
    await identity('test-agent');
    const resolved=await rpc('resolve',['order-agent']);
    assert.equal(resolved.rule.id,id);
    const attempt=await prepare('order-agent',resolved,'before-rule-delete');
    assert.equal(attempt.status,'available');
    await identity('test-admin');
    await rpc('delete_rule',[id,active.version]);
    assert.ok((await rpc('logs')).some(l=>l.rule_id===id));
    await identity('test-agent');
    const after=await prepare('order-agent',resolved,'after-rule-delete');
    assert.notEqual(after.status,'available');
    await identity('test-cabiniste');
    assert.notEqual((await rpc('resolve',['order-cabiniste'])).status,'available');
  });
  let bindingVersion, bindingFamily;
  await test('binding dependencies and stale versions are checked before deletion',async()=>{
    await identity('test-admin');
    bindingFamily=await rpc('save_family',['moov','internetSubscription','Association conservée']);
    await rpc('save_binding',['synthetic-offer',bindingFamily,'007',3]);
    bindingVersion=(await rpc('configuration')).offers.find(o=>o.id==='synthetic-offer').binding.version;
    await assert.rejects(()=>rpc('delete_family',[bindingFamily]),/family_in_use/);
    await assert.rejects(()=>rpc('delete_binding',['synthetic-offer',bindingVersion-1]),/binding_changed/);
    const id=await create({offer_id:'synthetic-offer',ussd_template:'*999*{{offer_code}}#'});
    await activate(id);
    await assert.rejects(()=>rpc('delete_binding',['synthetic-offer',bindingVersion]),/active_binding_in_use/);
    const rule=await current(id);
    await rpc('delete_rule',[id,rule.version]);
  });
  await test('deleting and recreating an association preserves the catalogue and monotonically versions history',async()=>{
    await identity('test-admin','authenticated');
    await rpc('delete_binding',['synthetic-offer',bindingVersion]);
    const offer=(await rpc('configuration')).offers.find(o=>o.id==='synthetic-offer');
    assert.ok(offer);assert.equal(offer.binding,null);
    let history=await rpc('binding_history',['synthetic-offer']);
    assert.equal(history[0].version,bindingVersion+1);
    assert.equal(history[0].deleted_by,'test-admin');
    const count=history.length;
    await rpc('delete_binding',['synthetic-offer',bindingVersion]);
    assert.equal((await rpc('binding_history',['synthetic-offer'])).length,count);
    await rpc('delete_family',[bindingFamily]);
    await rpc('save_binding',['synthetic-offer',null,'008',4]);
    const recreated=(await rpc('configuration')).offers.find(o=>o.id==='synthetic-offer').binding;
    assert.equal(recreated.version,bindingVersion+2);
    await assert.rejects(()=>rpc('delete_binding',['synthetic-offer',bindingVersion]),/binding_changed/);
    history=await rpc('binding_history',['synthetic-offer']);
    assert.equal(history.length,count+1);
    assert.equal(history[1].deleted_by,'test-admin');
  });
  await test('guard triggers are private, wrappers are invoker, tables remain RPC-only',async()=>{
    await identity('test-admin','postgres');
    const rows=(await db.query("select p.proname,p.prosecdef,has_function_privilege('anon',p.oid,'EXECUTE') as anon_exec from pg_proc p join pg_namespace n on n.oid=p.pronamespace where p.proname in ('ussd_guard_deleted_rule','ussd_guard_deleted_family_binding','izytel_ussd_delete_rule','izytel_ussd_delete_family','izytel_ussd_delete_binding')")).rows;
    assert.equal(rows.length,5);
    for(const r of rows) {assert.equal(r.prosecdef,false);assert.equal(r.anon_exec,r.proname.startsWith('izytel_'));}
    await identity('test-admin');
    await denied(()=>db.query('delete from public.ussd_offer_families'));
    await denied(()=>db.query('delete from public.ussd_offer_bindings'));
    await denied(()=>db.query('delete from public.ussd_binding_versions'));
  });
}
