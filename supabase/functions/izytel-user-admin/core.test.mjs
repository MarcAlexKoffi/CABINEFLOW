import test from 'node:test';
import assert from 'node:assert/strict';
import {execute,validate} from './core.mjs';
const command = (role='agent') => ({action:'create',requestId:'test-request-00001',name:'Compte Test',email:'test@example.invalid',phoneNumber:'0102030405',role,isActive:true,zoneIds:['zone-1'],authorizedNetworks:['orange']});
function dependencies(failure) {
  const calls=[];
  const step = async name => {calls.push(name);if(name===failure) throw Error('simulated');};
  const d={authorize:()=>step('authorize'),newUid:()=> 'target',load:async()=>({email:'test@example.invalid'}),begin:async()=>{await step('begin');return {fresh:true,status:'pending',request_id:'operation'};},deny:()=>step('denySQL'),sync:(_id,active)=>step(active?'activateSQL':'prepareInactiveSQL'),createAuth:()=>step('createAuth'),disableAuth:()=>step('disableAuth'),revoke:()=>step('revoke'),writeProfile:()=>step('writeProfile'),updateAuth:()=>step('updateAuth'),activateAccess:()=>step('activateAccess'),denyProfile:()=>step('denyProfile'),finish:()=>step('finish'),fail:()=>step('fail'),reset:async()=>{await step('reset');return 'https://example.invalid/reset';},audit:async()=>[]};
  d.result=async()=> 'pending';
  return {d,calls};
}
for(const role of ['admin','manager','agent','cabiniste']) test(`create ${role} uses denial before provisioning`,async()=>{
  const {d,calls}=dependencies();const result=await execute(command(role),'actor',d);
  assert.equal(result.ok,true);assert.deepEqual(calls,['authorize','begin','denySQL','createAuth','writeProfile','updateAuth','activateSQL','activateAccess','finish']);
});
test('invalid role and unknown fields rejected',()=>{
  assert.throws(()=>validate(command('supervisor')),/INVALID_ROLE/);
  assert.throws(()=>validate({...command(),actor:'spoofed'}),/UNKNOWN_FIELD/);
});
test('non administrator does not open operation',async()=>{
  const {d,calls}=dependencies('authorize');await assert.rejects(execute(command(),'actor',d));assert.deepEqual(calls,['authorize']);
});
test('self modification and deletion fail closed',async()=>{
  const {d}=dependencies();await assert.rejects(execute({...command(),action:'update',uid:'actor'},'actor',d),/SELF_ADMIN/);
  await assert.rejects(execute({action:'delete',uid:'target',requestId:'delete-request-001'},'actor',d),/REFERENCES_NOT_VERIFIED/);
});
for(const failAt of ['createAuth','writeProfile','updateAuth','activateSQL','activateAccess','finish']) test(`failure ${failAt} is explicit and denies all stores`,async()=>{
  const {d,calls}=dependencies(failAt);const result=await execute(command(),'actor',d);
  assert.equal(result.ok,false);assert.equal(result.requiresRepair,true);
  if(failAt==='createAuth') {assert.ok(!calls.includes('disableAuth'));assert.equal(calls.at(-1),'fail');}
  else assert.deepEqual(calls.slice(-4),['denySQL','disableAuth','denyProfile','fail']);
});
test('retry completed operation does not write twice',async()=>{
  const {d,calls}=dependencies();d.begin=async()=>({status:'completed',request_id:'operation'});
  assert.equal((await execute(command(),'actor',d)).replayed,true);assert.deepEqual(calls,['authorize']);
});
test('pending retry never replays a partial mutation',async()=>{
  const {d,calls}=dependencies();d.begin=async()=>({status:'failed',request_id:'operation'});
  await assert.rejects(execute(command(),'actor',d),/REQUIRES_REPAIR/);assert.deepEqual(calls,['authorize']);
});
test('reset failure does not disable user',async()=>{
  const {d,calls}=dependencies('reset');const result=await execute({action:'reset_password',uid:'target',requestId:'reset-request-0001'},'actor',d);
  assert.equal(result.ok,false);assert.ok(!calls.includes('disableAuth'));assert.ok(!calls.includes('denySQL'));
});
test('update revokes existing tokens before final activation',async()=>{
  const {d,calls}=dependencies();await execute({...command('manager'),action:'update',uid:'target'},'actor',d);
  assert.ok(calls.indexOf('revoke')<calls.indexOf('activateSQL'));
});
test('create cannot target an existing UID',()=>{
  assert.throws(()=>validate({...command(),uid:'existing'}),/INVALID_UID/);
});
test('duplicate email preflight produces no writes',async()=>{
  const {d,calls}=dependencies();d.checkEmail=async()=>{throw Error('EMAIL_ALREADY_EXISTS');};
  await assert.rejects(execute(command(),'actor',d),/EMAIL_ALREADY_EXISTS/);assert.deepEqual(calls,['authorize']);
});
test('inactive creation never activates SQL rights',async()=>{
  const {d,calls}=dependencies();const result=await execute({...command(),isActive:false},'actor',d);
  assert.equal(result.ok,true);assert.ok(calls.includes('prepareInactiveSQL'));assert.ok(!calls.includes('activateSQL'));
});
test('audit reads require administrator authorization',async()=>{
  const {d,calls}=dependencies();d.audit=async()=>[{status:'completed'}];
  const result=await execute({action:'audit',uid:'target',requestId:'audit-request-0001'},'actor',d);
  assert.deepEqual(result.events,[{status:'completed'}]);assert.deepEqual(calls,['authorize']);
});
test('a failed compensation remains explicit',async()=>{
  const {d}=dependencies('writeProfile');d.disableAuth=async()=>{throw Error('network');};let saved;
  d.fail=async(_id,code)=>{saved=code;};const result=await execute(command(),'actor',d);
  assert.equal(result.requiresRepair,true);assert.equal(saved,'DENIAL_INCOMPLETE');
});
test('lost completion response reconciles the durable result without undoing it',async()=>{
  const {d,calls}=dependencies('finish');d.result=async()=> 'completed';
  assert.equal((await execute(command(),'actor',d)).ok,true);assert.ok(!calls.includes('disableAuth'));
});
test('unknown completion outcome is explicit and does not undo a potentially committed result',async()=>{
  const {d,calls}=dependencies('finish');d.result=async()=>{throw Error('offline');};
  const result=await execute(command(),'actor',d);
  assert.equal(result.error,'OPERATION_RESULT_UNKNOWN');assert.equal(result.requiresRepair,true);assert.ok(!calls.includes('disableAuth'));
});
test('account details exposes bounded Auth identity without profile or claims',async()=>{
  const {d,calls}=dependencies();d.load=async()=>({email:'real@example.invalid',name:'Partner',disabled:false,profile:{private:'excluded'},customClaims:{role:'admin'}});
  const result=await execute({action:'details',uid:'target',requestId:'details-request-01'},'actor',d);
  assert.equal(result.account.email,'real@example.invalid');assert.equal(result.account.profile,undefined);assert.equal(result.account.customClaims,undefined);assert.deepEqual(calls,['authorize']);
});
