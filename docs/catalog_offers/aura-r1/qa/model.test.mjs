import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createState,preview,makeBatch,applyNext,restore,counts} from '../model.mjs';
const fixtures=JSON.parse(fs.readFileSync(new URL('../fixtures.json',import.meta.url),'utf8'));
const four=()=>fixtures.slice(0,4).map((row,index)=>({...row,_row:index+2,code_offre:`TEST-NEW-${index+1}`}));
function applyAll(state,entries){const batch=makeBatch(entries,'test');while(batch.status!=='complete')applyNext(state,batch);return batch;}
test('40 proposals from OFFRES remain drafts; preview has no writes',()=>{
  const state=createState(fixtures),before=JSON.stringify([...state.catalog]);
  assert.equal(fixtures.length,40);assert.ok(fixtures.every(r=>r.statut==='BROUILLON'));
  const entries=preview(fixtures,state.catalog);assert.equal(counts(entries).error,0);assert.equal(JSON.stringify([...state.catalog]),before);
});
test('four new drafts, identical reimport and importId replay do not duplicate',()=>{
  const state=createState(fixtures),batch=applyAll(state,preview(four(),state.catalog));
  assert.equal(state.catalog.size,12);assert.equal(batch.applied.length,4);
  assert.ok(four().every(row=>state.catalog.get(row.code_offre).statut==='BROUILLON'));
  assert.deepEqual(counts(preview(four(),state.catalog)),{create:0,update:0,deactivate:0,unchanged:4,error:0});
  applyNext(state,batch);assert.equal(batch.applied.length,4);assert.equal(state.catalog.size,12);
});
test('price update preserves identity, created date, other offers and order snapshot',()=>{
  const state=createState(fixtures),order=structuredClone(state.orders[0]),before=structuredClone(state.catalog.get(order.code)),other=JSON.stringify(state.catalog.get(fixtures[0].code_offre));
  const batch=applyAll(state,preview([{...before,_row:2,action:'UPSERT',prix_fcfa:'777'}],state.catalog));
  const after=state.catalog.get(order.code);assert.equal(after._id,before._id);assert.equal(after._created,before._created);assert.equal(after.prix_fcfa,'777');assert.deepEqual(state.orders[0],order);assert.equal(JSON.stringify(state.catalog.get(fixtures[0].code_offre)),other);
  restore(state,batch);assert.equal(state.catalog.get(order.code).prix_fcfa,before.prix_fcfa);assert.deepEqual(state.orders[0],order);
});
test('deactivation needs only action and code; preserves offer and history',()=>{
  const state=createState(fixtures),before=state.catalog.get(fixtures[0].code_offre);
  applyAll(state,preview([{_row:2,action:'DESACTIVER',code_offre:before.code_offre}],state.catalog));
  const after=state.catalog.get(before.code_offre);assert.equal(after.statut,'INACTIF');assert.equal(after._id,before._id);assert.equal(after.nom_affiche,before.nom_affiche);assert.equal(state.catalog.size,8);
});
test('all duplicate-code lines blocked with source line numbers; cross-operator collision blocked',()=>{
  const state=createState(fixtures),rows=four();rows[1].code_offre=rows[0].code_offre;
  const entries=preview(rows,state.catalog);assert.equal(counts(entries).error,2);assert.match(entries[0].errors[0],/2, 3/);assert.match(entries[1].errors[0],/2, 3/);
  const existing=[...state.catalog.values()][2];assert.equal(preview([{...existing,operateur:'MTN'}],state.catalog)[0].kind,'error');
});
test('unsafe publication and incompatible families blocked; units retain precision',()=>{
  const state=createState(fixtures),row={...four()[0],statut:'ACTIF',activable_pour_tiers:'NON',famille:'FOLIE'};
  const entry=preview([row],state.catalog)[0];assert.equal(entry.kind,'error');assert.ok(entry.errors.some(e=>e.includes('tiers')));assert.ok(entry.errors.some(e=>e.includes('Famille')));
  const data={...four()[0],volume_data:'1,5',unite_data:'GO'};applyAll(state,preview([data],state.catalog));
  const entry2=preview([{...data,volume_data:'1500',unite_data:'MO'}],state.catalog)[0];assert.equal(entry2.kind,'update');assert.ok(entry2.changes.includes('unite_data'));assert.equal(state.catalog.get(data.code_offre).volume_data,'1.5');
});
test('520 lines: errors excluded, 50-row batching resumed without double application',()=>{
  const state=createState(fixtures),rows=Array.from({length:520},(_,index)=>({...four()[0],_row:index+2,code_offre:`TEST-LOT-${index}`,prix_fcfa:index%104===0?'-20':'200'}));
  const entries=preview(rows,state.catalog);assert.equal(counts(entries).error,5);const batch=makeBatch(entries,'large');applyNext(state,batch,50);assert.equal(batch.cursor,50);assert.equal(batch.applied.length,49);
  while(batch.status!=='complete')applyNext(state,batch,50);assert.equal(batch.applied.length,515);assert.equal(state.catalog.size,523);assert.equal(counts(preview(rows,state.catalog)).unchanged,515);
});
test('optimistic conflicts prevent import overwrite and subsequent rollback overwrite',()=>{
  const state=createState(fixtures),before=[...state.catalog.values()][2],entry=preview([{...before,prix_fcfa:'888'}],state.catalog);
  state.catalog.set(before.code_offre,{...before,prix_fcfa:'999',_version:before._version+1});const batch=applyAll(state,entry);assert.equal(batch.conflicts.length,1);assert.equal(batch.applied.length,0);assert.equal(state.catalog.get(before.code_offre).prix_fcfa,'999');
  const next=applyAll(state,preview(four(),state.catalog)),created=state.catalog.get(four()[0].code_offre);state.catalog.set(created.code_offre,{...created,_version:created._version+1});assert.throws(()=>restore(state,next),/modifié/);
});
test('rollback of creations makes them inactive without deletion and records a revision',()=>{
  const state=createState(fixtures),batch=applyAll(state,preview(four(),state.catalog));restore(state,batch);
  assert.equal(state.catalog.size,12);assert.ok(four().every(row=>state.catalog.get(row.code_offre).statut==='INACTIF'));assert.equal(batch.status,'restored');assert.throws(()=>restore(state,batch),/déjà restaurée/);
});
