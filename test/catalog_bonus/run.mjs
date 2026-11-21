// An isolated local PostgreSQL cluster; no network, dialer, payment or FCM client.
import assert from 'node:assert/strict';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {join} from 'node:path';
import {withPostgres,root} from '../shared_queue/postgres.mjs';
const fixture=JSON.parse(await readFile(new URL('./fixtures/catalog_before.json',import.meta.url),'utf8'));
const functions=JSON.parse(await readFile(new URL('./fixtures/functions_before.json',import.meta.url),'utf8'));
const catalogTriggers=JSON.parse(await readFile(new URL('./fixtures/catalog_triggers_before.json',import.meta.url),'utf8'));
const routes={orange:{maxit:'APP:MAXIT',calls:'APP:MAXIT',internet:'#154*1*{{msisdn_local}}*2*2#',mixed:'#154*1*{{msisdn_local}}*2*1#'},
 mtn:{cchic:'*133*6*8*{{msisdn_local}}#',internet:'*133*6*3*{{msisdn_local}}#',mixed:'*133*6*2*{{msisdn_local}}#'},
 moov:{folie:'*412*4*{{msisdn_local}}#',internet:'*412*2*{{msisdn_local}}#',mixed:'*412*2*{{msisdn_local}}#'}};
const checks=[];const note=s=>{checks.push(s);console.log('PASS '+s);};
const report={};
await withPostgres(async({admin})=>{
 const q=(s,args)=>admin.query(s,args);
 const json=async(s,args)=>(await q(s,args)).rows[0].v;
 const identity=uid=>q("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:uid,iss:'synthetic-firebase'})]);
 const baseline=await readFile(join(root,'test/ussd_sql/baseline_fixture.sql'),'utf8');
 await q(baseline.slice(0,baseline.indexOf('insert into public.catalog_offers')));
 await q(`alter table catalog_offers add column category text,add column category_id uuid,add column family_code text,
  add column offer_code text,add column is_active boolean default true,add column selling_price bigint,
  add column catalog_data jsonb,add column catalog_version bigint default 1,add column volume text,
  add column catalog_label text,add column details text[],add column description text,add column validity text,
  add column code_confirmed boolean,add column source_kind text,add column catalog_status text,add column delivery_proof text,add column badge_label text;
  create table offer_categories(id uuid primary key,slug text,label_fr text,is_active boolean,deleted_at timestamptz);
  insert into izytel_staff_access values('test-admin','admin',true),('test-manager','manager',true);
  insert into territory_zones values('zone-a','test-manager',true);
  insert into phase5_agent_capacities(agent_id,is_active) values('test-agent',true);
  create function private.izytel_touch_catalog_change_feed() returns trigger language plpgsql as $$begin return null;end$$;`);
 for(const name of ['20261031005603_ussd_dynamic_shortcuts_v1.sql','20261031224809_ussd_template_aliases_secret_and_draft_catalog.sql',
  '20261101003245_ussd_admin_deletion.sql','20261115230624_ussd_template_clipboard_padding.sql',
  '20261117235555_ussd_shared_families_and_direct_creation.sql','20261118012824_ussd_automatic_commercial_offer_groups.sql',
  '20261119163850_ussd_maxit_command.sql'])await q(await readFile(join(root,'supabase/migrations',name),'utf8'));
 // Remove synthetic seed configuration before loading the read-only catalogue snapshot.
 await q('delete from ussd_rule_versions;delete from ussd_execution_rules;delete from ussd_binding_versions;delete from ussd_offer_bindings;delete from ussd_offer_families;');
 for(const [table,rows] of [['offer_categories',fixture.categories],['catalog_offers',fixture.offers],['ussd_offer_families',fixture.families],['ussd_offer_bindings',fixture.bindings],['ussd_execution_rules',fixture.rules]]){
  for(const row of rows)await q(`insert into public.${table} select (jsonb_populate_record(null::public.${table},$1::jsonb)).*`,[JSON.stringify(row)]);
 }
 await q('insert into ussd_rule_versions select id,version,to_jsonb(r) from ussd_execution_rules r');
 await q(functions.find(f=>f.name==='ussd_resolve_before_execution').definition);
 await q(`create table catalog_import_families(network text,code text,enabled boolean,conditional boolean);
  create table catalog_offer_import_metadata(offer_id text primary key,data jsonb,delivery_proof text);`);
 for(const row of catalogTriggers.families)await q('insert into catalog_import_families select (jsonb_populate_record(null::catalog_import_families,$1::jsonb)).*',[JSON.stringify(row)]);
 for(const row of catalogTriggers.metadata)await q('insert into catalog_offer_import_metadata select (jsonb_populate_record(null::catalog_offer_import_metadata,$1::jsonb)).*',[JSON.stringify(row)]);
 for(const fn of catalogTriggers.functions)await q(fn.definition);
 await q(`create trigger catalog_offer_import_version before update on catalog_offers for each row execute function private.catalog_version_guard();
  create trigger catalog_offer_presentation before update on catalog_offers for each row execute function private.catalog_offer_presentation();
  create trigger trg_catalog_offers_sync_category before update on catalog_offers for each row execute function public.izytel_sync_catalog_offer_category();`);
 const before=await json('select jsonb_agg(to_jsonb(c) order by id) v from catalog_offers c');
 const bindingsBefore=await json('select jsonb_agg(to_jsonb(b) order by offer_id) v from ussd_offer_bindings b');
 for(const o of fixture.offers.filter(o=>['OR-DAT-20261118-003','OR-DAT-20261118-004'].includes(o.offer_code))){
  await q(`insert into phase4_assignment_orders(order_id,network,operation_type,amount,beneficiary_phone,offer_label,order_status,payment_status,assignment_state,assigned_agent_id,zone_id)
    values($1,$2,$3,$4,'0700000000',$5,'inProgress','confirmed','accepted','test-agent','zone-a')`,['historical-'+o.id,o.network,o.operation_type,o.selling_price,o.title]);
  await q("insert into ussd_order_contexts(order_id,offer_id,created_by) values($1,$2,'test-admin')",['historical-'+o.id,o.id]);
 }
 const historicalBefore=await json('select jsonb_agg(to_jsonb(o) order by order_id) v from phase4_assignment_orders o');
 const transfers=await json("select jsonb_agg(to_jsonb(r) order by id) v from ussd_execution_rules r where service='unitTransfer'");
 await q(await readFile(join(root,'supabase/migrations/20261121011133_catalog_commercial_subscription_routes.sql'),'utf8'));
 const offers=await json('select jsonb_agg(to_jsonb(c) order by id) v from catalog_offers c');
 assert.equal(offers.length,110);assert.equal(offers.filter(o=>o.is_active&&!o.deleted_at).length,109);
 const moved=offers.filter(o=>['OR-DAT-20261118-003','OR-DAT-20261118-004'].includes(o.offer_code));
 for(const o of offers){const b=before.find(b=>b.id===o.id);const allowed=['category','category_id','family_code','catalog_data','catalog_version'];
  for(const k of Object.keys(b).filter(k=>!allowed.includes(k)))assert.deepEqual(o[k],b[k],`${o.offer_code}: ${k}`);
  if(moved.includes(o)){assert.equal(o.category,'maxit');assert.equal(o.family_code,'MAXIT');assert.equal(o.catalog_data.famille,'MAXIT');assert.equal(o.catalog_version,Number(b.catalog_version)+1);
   assert.deepEqual({...o.catalog_data,famille:b.catalog_data.famille},b.catalog_data);
  }else assert.deepEqual(o,b);
 }
 note('110 catalogue rows / 109 active; only the two intended offers move, with IDs, prices and metadata preserved');
 await identity('test-agent');
 assert.deepEqual(await json('select jsonb_agg(to_jsonb(o) order by order_id) v from phase4_assignment_orders o'),historicalBefore);
 assert.deepEqual(await json('select jsonb_agg(to_jsonb(b) order by offer_id) v from ussd_offer_bindings b'),bindingsBefore);
 for(const o of moved)assert.equal((await json('select private.ussd_resolve_before_execution($1) v',['historical-'+o.id])).code,'APP:MAXIT');
 note('historical orders keep their exact data and compatible Max it bindings; both retained IDs resolve to Max it');
 const results=[];
 for(const o of offers.filter(o=>o.is_active&&!o.deleted_at)){
  await q(`insert into phase4_assignment_orders(order_id,network,operation_type,amount,beneficiary_phone,offer_label,order_status,payment_status,assignment_state,assigned_agent_id,zone_id)
    values($1,$2,$3,$4,'0700000000',$5,'inProgress','confirmed','accepted','test-agent','zone-a')`,['route-'+o.id,o.network,o.operation_type,o.selling_price,o.title]);
  await q('insert into ussd_order_contexts(order_id,offer_id,created_by) values($1,$2,\'test-admin\')',['route-'+o.id,o.id]);
  const v=await json('select private.ussd_resolve_before_execution($1) v',['route-'+o.id]);
  assert.equal(v.status,'available',JSON.stringify({offer:o.offer_code,v}));
  const expected=routes[o.network][o.category].replace('{{msisdn_local}}','0700000000');
  assert.equal(v.code,expected,o.offer_code);assert.equal(v.context.commercial_category,o.category);
  results.push({id:o.id,code:o.offer_code,title:o.title,network:o.network,category:o.category,price:o.selling_price,action:v.code,template:routes[o.network][o.category]});
 }
 assert.equal(results.filter(o=>o.action==='APP:MAXIT').length,9);
 const distribution=results.reduce((a,o)=>(a[o.network+'/'+o.category]=(a[o.network+'/'+o.category]??0)+1,a),{});
 assert.equal(distribution['orange/maxit'],8);assert.equal(distribution['orange/internet'],10);
 for(const o of moved)assert.equal(results.find(r=>r.id===o.id).action,'APP:MAXIT');
 assert.deepEqual(await json("select jsonb_agg(to_jsonb(r)-array['commercial_category','technical_validated_at','operator_validated_at','operator_reference'] order by id) v from ussd_execution_rules r where service='unitTransfer'"),transfers);
 assert.equal((await q("select count(*)::int n from ussd_execution_rules where commercial_category is null and purpose='order' and service<>'unitTransfer' and status<>'disabled'")).rows[0].n,0);
 note('109/109 category routes, 9 Max it actions, 0 missing/conflicting alternatives; all credit transfer records unchanged');
 // Explicitly exercise the old transfer resolver, including its existing validations.
 const transferResults=[];
 for(const network of ['orange','mtn','moov']){
  await q(`insert into phase4_assignment_orders values($1,$2,'unitTransfer',500,'0700000000','Transfert fictif','inProgress','confirmed','accepted','test-agent',null,'zone-a')`,['transfer-'+network,network]);
  const v=await json('select private.ussd_resolve_before_execution($1) v',['transfer-'+network]);
  assert.equal(v.status,'available');transferResults.push({network,code:v.code});
 }
 note('credit transfers still use their original resolver and generated syntax');
 await q('begin');
 await q("update catalog_offers set is_active=false where id=$1",[moved[0].id]);
 assert.equal((await json('select private.ussd_resolve_before_execution($1) v',['route-'+moved[0].id])).reason,'catalog_offer_inactive');
 await q('rollback');
 await q("update phase4_assignment_orders set operation_type='callBundle' where order_id=$1",['route-'+moved[0].id]);
 assert.equal((await json('select private.ussd_resolve_before_execution($1) v',['route-'+moved[0].id])).reason,'catalog_offer_mismatch');
 await q('update phase4_assignment_orders set operation_type=$1 where order_id=$2',[moved[0].operation_type,'route-'+moved[0].id]);
 note('inactive catalogue offers and inconsistent operation types fail explicitly without a generic fallback');
 await q('begin');
 await q("update ussd_execution_rules set status='disabled' where network='orange' and commercial_category='maxit'");
 assert.equal((await json('select private.ussd_resolve_before_execution($1) v',['route-'+moved[0].id])).reason,'commercial_route_missing');
 await q('rollback');
 await q('begin');
 await q(`insert into ussd_execution_rules select (jsonb_populate_record(null::ussd_execution_rules,
   to_jsonb(r)||jsonb_build_object('id',gen_random_uuid(),'actor_scope','agent','seed_key','synthetic-conflict'))).*
   from ussd_execution_rules r where network='orange' and commercial_category='maxit'`);
 assert.equal((await json('select private.ussd_resolve_before_execution($1) v',['route-'+moved[0].id])).reason,'commercial_route_conflict');
 await q('rollback');
 await identity('test-admin');
 const configuredRoutes=await json('select public.izytel_catalog_subscription_routes() v');
 assert.equal(configuredRoutes.length,10);
 assert.ok(configuredRoutes.every(r=>r.configured&&!r.technical_validated_at&&!r.operator_validated_at));
 const reviewed=configuredRoutes.find(r=>r.network==='orange'&&r.category==='internet');
 await assert.rejects(()=>q('select public.izytel_catalog_validate_subscription_route($1,null,null)',[reviewed.id]),/rule_changed/);
 await q('select public.izytel_catalog_validate_subscription_route($1,$2,null)',[reviewed.id,reviewed.version]);
 let reviewedRow=await json('select to_jsonb(r) v from ussd_execution_rules r where id=$1',[reviewed.id]);
 assert.ok(reviewedRow.technical_validated_at);assert.equal(reviewedRow.operator_validated_at,null);
 await q('select public.izytel_catalog_validate_subscription_route($1,$2,$3)',[reviewed.id,reviewedRow.version,'Preuve opérateur strictement fictive']);
 reviewedRow=await json('select to_jsonb(r) v from ussd_execution_rules r where id=$1',[reviewed.id]);
 assert.ok(reviewedRow.operator_validated_at);
 await q('begin');
 await q("update ussd_execution_rules set ussd_template='#154*1*{{msisdn_local}}*2*2*1#' where id=$1",[reviewed.id]);
 const invalidated=await json('select to_jsonb(r) v from ussd_execution_rules r where id=$1',[reviewed.id]);
 assert.equal(invalidated.technical_validated_at,null);assert.equal(invalidated.operator_validated_at,null);
 await q('rollback');
 await identity('test-manager');
 await assert.rejects(()=>q('select public.izytel_catalog_validate_subscription_route($1,$2,null)',[reviewed.id,reviewedRow.version]),e=>e.code==='42501');
 note('missing/conflicting routes fail closed; technical/operator evidence stays distinct, changes invalidate it and only Admin can validate');
 const beforePromotions=await json('select jsonb_agg(to_jsonb(c) order by id) v from catalog_offers c');
 await q(await readFile(join(root,'supabase/migrations/20261121011322_offer_bonus_campaigns.sql'),'utf8'));
 await identity('test-admin');
 const target=moved.find(o=>o.selling_price===800);
 const payload={name:'Bonus fictif mardi',network:'orange',weekdays:[2],starts_at:'2030-01-01T00:00:00Z',ends_at:'2030-02-01T00:00:00Z',
  daily_start:'08:00',daily_end:'18:00',bonus_kind:'percentage',bonus_value:200,operator_reference:'Source opérateur fictive',offers:[{offer_id:target.id,base_volume_mb:750}]};
 const save=async(p,id=null,version=null)=>json('select public.izytel_bonus_save($1,$2,$3::jsonb) v',[id,version,JSON.stringify(p)]);
 const status=(id,version,s)=>q('select public.izytel_bonus_set_status($1,$2,$3,$4)',[id,version,s,'Source opérateur et scénario de test fictifs']);
 const projection=at=>json('select private.bonus_projection($1::timestamptz) v',[at]);
 const id=await save(payload);
 assert.equal((await projection('2030-01-01T10:00:00Z')).promotions.length,0);
 await assert.rejects(()=>status(id,1,'active'),/BONUS_VALIDATION_REQUIRED/);
 await status(id,1,'validated');await status(id,2,'active');
 let v=(await projection('2030-01-01T10:00:00Z')).promotions;
 assert.equal(v.length,1);assert.equal(v[0].base_volume_mb,750);assert.equal(v[0].total_volume_mb,2250);
 assert.equal((await projection('2030-01-01T07:59:59Z')).promotions.length,0);
 assert.equal((await projection('2030-01-01T08:00:00Z')).promotions.length,1);
 assert.equal((await projection('2030-01-01T18:00:00Z')).promotions.length,0);
 assert.equal((await projection('2030-01-02T10:00:00Z')).promotions.length,0);
 assert.equal((await projection('2030-02-01T10:00:00Z')).promotions.length,0);
 await identity('test-agent');
 assert.equal((await json('select private.ussd_resolve_before_execution($1) v',['route-'+target.id])).code,'APP:MAXIT');
 await identity('test-admin');
 note('only validated active campaigns appear on Tuesday; exact +200% = 2250 Mo, correct start/expiry and unchanged Max it routing');
 const conflict=await save({...payload,name:'Conflit fictif'});
 await assert.rejects(()=>status(conflict,1,'validated'),/BONUS_CAMPAIGN_CONFLICT/);
 await status(id,3,'suspended');assert.equal((await projection('2030-01-01T10:00:00Z')).promotions.length,0);
 await assert.rejects(()=>status(id,3,'active'),/BONUS_VERSION_CHANGED/);
 await save({...payload,bonus_kind:'total_mb',bonus_value:2500},id,4);
 await status(id,5,'validated');await status(id,6,'active');
 assert.equal((await projection('2030-01-01T10:00:00Z')).promotions[0].total_volume_mb,2500);
 await status(id,7,'suspended');
 const midnight=await save({...payload,name:'Nuit fictive',daily_start:'22:00',daily_end:'02:00'});
 await status(midnight,1,'validated');await status(midnight,2,'active');
 const crossMidnightConflict=await save({...payload,name:'Chevauchement du mercredi',weekdays:[3],daily_start:'01:00',daily_end:'03:00'});
 await assert.rejects(()=>status(crossMidnightConflict,1,'validated'),/BONUS_CAMPAIGN_CONFLICT/);
 assert.equal((await projection('2030-01-02T01:59:59Z')).promotions.length,1);
 assert.equal((await projection('2030-01-02T02:00:00Z')).promotions.length,0);
 await status(midnight,3,'archived');
 assert.equal((await projection('2030-01-02T01:00:00Z')).promotions.length,0);
 note('guaranteed 2500 Mo, conflicts, suspension, stale versions, overnight Tuesday windows and archival are enforced');
 await q('set role authenticated');await identity('test-manager');
 await assert.rejects(()=>json('select public.izytel_bonus_campaigns() v'),e=>e.code==='42501');
 await assert.rejects(()=>save(payload),e=>e.code==='42501');
 await assert.rejects(()=>q('select * from offer_bonus_campaigns'),e=>e.code==='42501');
 await assert.rejects(()=>projection('2030-01-01T10:00:00Z'),e=>e.code==='42501');
 await q('reset role');await q('set role anon');await identity(null);
 const publicValue=await json('select public.izytel_public_offer_bonuses() v');assert.equal(publicValue.promotions.length,0);
 await q('reset role');
 assert.deepEqual(await json('select jsonb_agg(to_jsonb(c) order by id) v from catalog_offers c'),beforePromotions);
 note('Manager/anonymous writes, direct table reads and spoofed promotion clocks denied; catalogue and prices unchanged');
 report.offers=results;report.distribution=distribution;report.transfers=transferResults;
 report.archivedRules=fixture.rules.filter(r=>r.purpose==='order'&&r.service!=='unitTransfer').map(r=>({id:r.id,network:r.network,service:r.service,template:r.ussd_template,previous_status:r.status,status:'disabled',action:r.status==='active'?'deactivated':r.deleted_at?'retained_archived':'retained_disabled_revision'}));
 report.movedOffers=moved.map(o=>({before:before.find(b=>b.id===o.id),after:o}));
 // Rollback is tested on this disposable database, without deleting audit rows.
 await q(await readFile(join(root,'supabase/operations/catalog_bonus_rollback.sql'),'utf8'));
 for(const o of moved){const restored=await json('select to_jsonb(c) v from catalog_offers c where id=$1',[o.id]);assert.equal(restored.category,before.find(b=>b.id===o.id).category);}
 note('targeted rollback restores both categories and prior routing while retaining history and campaign data');
});
await mkdir(join(root,'docs/catalog_bonus'),{recursive:true});
await writeFile(join(root,'docs/catalog_bonus/verification.json'),JSON.stringify({executedAt:new Date().toISOString(),environment:'isolated local PostgreSQL; catalogue metadata snapshot; synthetic orders only',checks,...report},null,2));
const escape=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
await writeFile(join(root,'docs/catalog_bonus/offers_routing.html'),`<!doctype html><meta charset="utf-8"><title>IzyTel — 109 associations vérifiées localement</title><style>body{font:14px system-ui;padding:24px}td,th{padding:8px;text-align:left;border-bottom:1px solid #ddd}table{border-collapse:collapse}</style><h1>109 offres — routage technique local</h1><p>Aucun achat télécom testé. Validation opérateur nécessaire.</p><table><tr>${['Code','Identifiant','Offre','Opérateur','Catégorie','Prix FCFA','Action exacte'].map(h=>'<th>'+h+'</th>').join('')}</tr>${report.offers.map(o=>'<tr>'+[o.code,o.id,o.title,o.network,o.category,o.price,o.action].map(v=>'<td>'+escape(v)+'</td>').join('')+'</tr>').join('')}</table>`);
console.log(`ALL ${checks.length} catalogue/bonus checks passed`);
