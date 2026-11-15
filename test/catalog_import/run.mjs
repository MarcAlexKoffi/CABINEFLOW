// Isolated PostgreSQL/WASM only. Never reads a production URL or credentials.
import assert from 'node:assert/strict';
import {readFile,writeFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {existsSync} from 'node:fs';
const root=resolve(import.meta.dirname,'../..');
const ownModule=resolve(import.meta.dirname,'node_modules/@electric-sql/pglite/dist/index.js');
const modulePath=process.env.IZYTEL_PGLITE_MODULE??(existsSync(ownModule)?ownModule:resolve(root,'scratch/ussd_reprise_tools/node_modules/@electric-sql/pglite/dist/index.js'));
const {PGlite}=await import(pathToFileURL(modulePath).href);
const db=new PGlite();let passed=0;
async function test(name,fn){await fn();passed++;console.log(`PASS ${name}`);}
async function identity(uid='admin',issuer='synthetic-firebase'){
  await db.exec('reset role');await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:uid,iss:issuer})]);await db.exec('set role anon');
}
async function rpc(name,params=[],casts=[]){return(await db.query(`select public.izytel_catalog_${name}(${params.map((_,i)=>`$${i+1}${casts[i]?'::'+casts[i]:''}`).join(',')}) result`,params)).rows[0].result;}
const fixtures=JSON.parse(await readFile(resolve(import.meta.dirname,'fixtures/offres.json'),'utf8'));
const rows=(n=4,prefix='NEW')=>Array.from({length:n},(_,i)=>({...fixtures[i%fixtures.length],_row:i+2,code_offre:`${prefix}-${i}`}));
async function prepare(data){const id=crypto.randomUUID();await rpc('import_prepare',[id,'test.xlsx','a'.repeat(64),JSON.stringify(data)],['uuid','text','text','jsonb']);return id;}
async function get(id){return rpc('import_get',[id],['uuid']);}
async function run(id,partial=false){await rpc('import_confirm',[id,partial],['uuid','boolean']);let result;do{result=await rpc('import_apply',[id],['uuid']);}while(result.job.status==='running');return result;}
async function offer(code){await db.exec('reset role');const r=(await db.query('select * from public.catalog_offers where offer_code=$1',[code])).rows[0];await identity();return r;}
try{
  await db.exec(`create schema auth;create schema private;create role anon;create role authenticated;
    grant usage on schema public,private,auth to anon,authenticated;
    create function auth.jwt() returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;
    create function public.is_izytel_firebase_jwt() returns boolean language sql stable as $$ select auth.jwt()->>'iss'='synthetic-firebase' $$;
    create function private.is_izytel_finance_admin() returns boolean language sql stable as $$ select public.is_izytel_firebase_jwt() and auth.jwt()->>'sub'='admin' $$;
    create function private.izytel_staff_display_name() returns text language sql stable as $$ select 'Synthetic admin'::text $$;`);
  await db.exec('create publication supabase_realtime');
  await db.exec(await readFile(resolve(root,'supabase/migrations/20260915013543_bo4_catalog_supabase_cutover.sql'),'utf8'));
  await db.exec('alter table public.catalog_offers add column deleted_at timestamptz,add column deleted_by_uid text,add column deleted_by_name text');
  await db.exec("insert into public.catalog_offers(id,network,service,operation_type,title,catalog_label,selling_price) values('legacy-id','orange','internetSubscription','internetSubscription','Legacy title','Legacy label',1000)");
  await db.exec(`create table public.customer_order_recovery_registry(order_id text primary key,offer_id text,offer_label text,amount integer,izytel_fee integer,payment_fee integer);
    create table public.phase4_assignment_orders(order_id text primary key,offer_label text,amount integer);
    insert into public.customer_order_recovery_registry values('historical','legacy-id','Historical label',900,25,10);`);
  await db.exec(await readFile(resolve(root,'supabase/migrations/20261115133000_catalog_offer_imports.sql'),'utf8'));
  await test('migration preserves existing identity, price, visibility and provisional code',async()=>{const value=await offer('legacy-id');assert.equal(value.id,'legacy-id');assert.equal(value.is_active,true);assert.equal(value.selling_price,1000);assert.equal(value.code_confirmed,false);});
  await test('non-admin, foreign issuer and direct table access rejected',async()=>{
    for(const uid of ['manager','agent','cabiniste','customer']){await identity(uid);await assert.rejects(()=>rpc('configuration'),/ADMIN_REQUIRED/);await assert.rejects(()=>prepare(rows()),/ADMIN_REQUIRED/);await assert.rejects(()=>rpc('import_history'),/ADMIN_REQUIRED/);}
    await identity('admin','foreign');await assert.rejects(()=>rpc('configuration'),/ADMIN_REQUIRED/);await identity();
    for(const table of ['catalog_offer_imports','catalog_offer_import_lines','catalog_import_configuration','catalog_import_families','catalog_offer_import_metadata'])await assert.rejects(()=>db.query(`select * from public.${table}`),/permission denied/);
  });
  let first;
  await test('preview validates four drafts without changing catalogue; explicit confirmation required',async()=>{
    first=await prepare(rows());const preview=await get(first);assert.equal(preview.summary.create,4);assert.equal(preview.summary.error,0);await assert.rejects(()=>rpc('import_apply',[first],['uuid']),/CONFIRMATION_REQUIRED/);assert.equal(await offer('NEW-0'),undefined);
  });
  await test('four new drafts created; same importId and same file produce no duplicates or new versions',async()=>{
    const result=await run(first);assert.equal(result.summary.applied,4);const value=await offer('NEW-0');assert.equal(value.is_active,false);assert.equal(value.catalog_status,'BROUILLON');
    await rpc('import_apply',[first],['uuid']);assert.equal((await offer('NEW-0')).catalog_version,value.catalog_version);
    const second=await prepare(rows());assert.equal((await get(second)).summary.unchanged,4);await run(second);assert.equal((await offer('NEW-0')).catalog_version,value.catalog_version);
  });
  await test('price update keeps ID/creation; missing offers intact; stale preview conflicts',async()=>{
    const old=await offer('NEW-0'),other=await offer('NEW-1'),update=[{...rows()[0],prix_fcfa:'777'}],a=await prepare(update),b=await prepare(update);
    await run(a);const after=await offer('NEW-0');assert.equal(after.id,old.id);assert.deepEqual(after.created_at,old.created_at);assert.equal(after.selling_price,777);assert.deepEqual(await offer('NEW-1'),other);
    const conflict=await run(b);assert.equal(conflict.summary.conflict,1);assert.equal(conflict.summary.applied,0);
    await rpc('import_restore',[a],['uuid']);assert.equal((await offer('NEW-0')).selling_price,old.selling_price);
  });
  await test('duplicate codes block every occurrence with row numbers; partial scope requires explicit consent',async()=>{
    const data=rows(3,'DUP');data[1].code_offre=data[0].code_offre;const id=await prepare(data),before=await get(id);assert.equal(before.summary.error,2);assert.match(JSON.stringify(before.lines[0].errors),/2, 3/);await assert.rejects(()=>run(id),/ERRORS_REQUIRE_CONFIRMATION/);const after=await run(id,true);assert.equal(after.summary.applied,1);assert.equal(await offer('DUP-0'),undefined);
  });
  await test('DESACTIVER accepts only code/action and retains the offer',async()=>{
    const old=await offer('NEW-1'),id=await prepare([{_row:2,action:'DESACTIVER',code_offre:'NEW-1'}]);await run(id);const after=await offer('NEW-1');assert.equal(after.id,old.id);assert.equal(after.catalog_status,'INACTIF');assert.equal(after.title,old.title);
  });
  await test('publication blocked until policy, third-party eligibility, channel, recent verification and conditional proof',async()=>{
    const row={...rows(1,'ACTIVE')[0],statut:'ACTIF',activable_pour_tiers:'NON'};let id=await prepare([row]);assert.equal((await get(id)).summary.error,1);
    const config=await rpc('configuration');await rpc('save_configuration',[config.settings.version,30,JSON.stringify(config.families)],['bigint','integer','jsonb']);
    row.activable_pour_tiers='OUI';row.canal_activation='MANUEL';row.verifie_le=new Date().toISOString().slice(0,10);id=await prepare([row]);assert.equal((await get(id)).summary.error,0);await run(id);assert.equal((await offer(row.code_offre)).is_active,true);
    row.famille='MAXIT';id=await prepare([row]);assert.equal((await get(id)).summary.error,1);
    row.statut='BROUILLON';const saved=await rpc('offer_save',[null,null,JSON.stringify({...row,code_offre:'CONDITIONAL'}),'Livraison testée pour un tiers'],['text','bigint','jsonb','text']);
    row.statut='ACTIF';row.code_offre='CONDITIONAL';id=await prepare([row]);assert.equal((await get(id)).summary.error,0);await run(id);assert.equal((await offer('CONDITIONAL')).is_active,true);
    await assert.rejects(()=>rpc('offer_save',[saved.id,saved.catalog_version,JSON.stringify(row),null],['text','bigint','jsonb','text']),/VERSION_CONFLICT/);
  });
  await test('cross-operator collisions, incompatible families, quantity and date errors rejected',async()=>{
    const bad=[{...rows()[0],operateur:'MTN'},{...rows(1,'BAD')[0],famille:'CCHIC'},{...rows(1,'BAD2')[0],prix_fcfa:'-2'},{...rows(1,'BAD3')[0],verifie_le:'2026-02-30'}].map((row,i)=>({...row,_row:i+2}));const id=await prepare(bad);assert.equal((await get(id)).summary.error,4);
  });
  await test('520 rows: 20-row pages, 50-row batches, partial errors and retry after response loss',async()=>{
    const data=rows(520,'LARGE');for(let i=0;i<data.length;i+=104)data[i].prix_fcfa='-1';const id=await prepare(data);let value=await get(id);assert.equal(value.lines.length,20);assert.equal(value.summary.create,515);assert.equal(value.summary.error,5);await rpc('import_confirm',[id,true],['uuid','boolean']);value=await rpc('import_apply',[id],['uuid']);assert.equal(value.job.cursor,50);value=await run(id,true);assert.equal(value.summary.applied,515);assert.equal(value.job.cursor,520);
    await rpc('import_restore',[id],['uuid']);assert.equal((await offer('LARGE-1')).catalog_status,'INACTIF');assert.equal((await get(id)).job.status,'restored');
  });
  await test('restore conflict refuses whole rollback; audit is retained and code becomes immutable',async()=>{
    const id=await prepare(rows(2,'RESTORE'));await run(id);const old=await offer('RESTORE-0');await rpc('offer_save',[old.id,old.catalog_version,JSON.stringify({...rows(1,'RESTORE')[0],prix_fcfa:'300'}),null],['text','bigint','jsonb','text']);await assert.rejects(()=>rpc('import_restore',[id],['uuid']),/RESTORE_CONFLICT/);assert.equal((await get(id)).job.status,'completed');assert.ok((await rpc('offer_history',[old.id],['text'])).length>=2);
    const updated=await offer('RESTORE-0');await assert.rejects(()=>rpc('offer_save',[old.id,updated.catalog_version,JSON.stringify({...rows(1,'OTHER')[0]}),null],['text','bigint','jsonb','text']),/CODE_IMMUTABLE/);
  });
  await test('bulk operations use the same server preview/confirmation and reject stale selection',async()=>{
    const current=await offer('NEW-2'),id=crypto.randomUUID(),change={operation:'priority',value:'99',items:[{id:current.id,version:current.catalog_version}]};
    await rpc('bulk_prepare',[id,JSON.stringify(change)],['uuid','jsonb']);assert.equal((await get(id)).summary.update,1);assert.notEqual((await offer('NEW-2')).display_order,99);await run(id);assert.equal((await offer('NEW-2')).display_order,99);
    assert.equal(await rpc('bulk_prepare',[id,JSON.stringify(change)],['uuid','jsonb']),id);await assert.rejects(()=>rpc('bulk_prepare',[crypto.randomUUID(),JSON.stringify(change)],['uuid','jsonb']),/VERSION_CONFLICT/);
  });
  await test('new canonical orders freeze price, volume, fees and label; later import never changes snapshot',async()=>{
    const before=await offer('NEW-2');await db.exec('reset role');
    await db.query('insert into public.customer_order_recovery_registry values($1,$2,$3,$4,25,10,null)',['snapshot-order',before.id,'Historical selected label',before.selling_price]);
    const snapshot=(await db.query("select catalog_snapshot from public.customer_order_recovery_registry where order_id='snapshot-order'")).rows[0].catalog_snapshot;
    assert.equal(snapshot.volume,before.volume);assert.equal(snapshot.order_fields.izytel_fee,25);assert.equal(snapshot.order_fields.payment_fee,10);
    await identity();const id=await prepare([{...rows()[2],prix_fcfa:'888',volume_data:'9',unite_data:'GO'}]);await run(id);
    await db.exec('reset role');assert.deepEqual((await db.query("select catalog_snapshot from public.customer_order_recovery_registry where order_id='snapshot-order'")).rows[0].catalog_snapshot,snapshot);
    await db.exec("insert into public.phase4_assignment_orders(order_id,offer_label,amount) values('snapshot-order','Current bridge label',888)");assert.deepEqual((await db.query("select catalog_snapshot from public.phase4_assignment_orders where order_id='snapshot-order'")).rows[0].catalog_snapshot,snapshot);
    await assert.rejects(()=>db.exec("update public.customer_order_recovery_registry set catalog_snapshot='{}' where order_id='snapshot-order'"),/IMMUTABLE/);
    await db.exec("insert into public.phase4_assignment_orders(order_id,offer_label,amount) values('historical','Historical label',900)");assert.equal((await db.query("select catalog_snapshot from public.phase4_assignment_orders where order_id='historical'")).rows[0].catalog_snapshot.historical_without_catalog_snapshot,true);await identity();
  });
  await test('legacy activation RPC cannot publish imported unverified offers; legacy deactivation can be restored',async()=>{
    const before=await offer('NEW-3');await assert.rejects(()=>db.query('select public.izytel_set_catalog_offer_active($1,true)',[before.id]),/PUBLICATION_BLOCKED/);
    const old=await offer('legacy-id');const id=await prepare([{_row:2,action:'DESACTIVER',code_offre:old.offer_code}]);await run(id);assert.equal((await offer('legacy-id')).is_active,false);await rpc('import_restore',[id],['uuid']);assert.equal((await offer('legacy-id')).is_active,true);
  });
  await test('legacy editor has optimistic locking and cannot overwrite an offer structured after opening',async()=>{
    const old=await offer('legacy-id'),payload={network:'orange',service:'internetSubscription',operationType:'internetSubscription',title:'Legacy edited title',catalogLabel:'Legacy edited label',sellingPrice:1200,details:[],category:'internet',displayOrder:1,isActive:true};
    await rpc('offer_update_legacy',[old.id,old.catalog_version,JSON.stringify(payload)],['text','bigint','jsonb']);await assert.rejects(()=>rpc('offer_update_legacy',[old.id,old.catalog_version,JSON.stringify(payload)],['text','bigint','jsonb']),/VERSION_CONFLICT/);
    const structured=await offer('NEW-2');await assert.rejects(()=>rpc('offer_update_legacy',[structured.id,structured.catalog_version,JSON.stringify(payload)],['text','bigint','jsonb']),/STRUCTURED_EDIT_REQUIRED/);
  });
  await test('internal comments and delivery evidence are excluded from the public catalogue and available only to Admin',async()=>{
    await identity('customer');const visible=(await db.query("select catalog_data,delivery_proof from public.catalog_offers where offer_code='CONDITIONAL'")).rows[0];assert.equal(visible.delivery_proof,'CONFIRMED');assert.equal(visible.catalog_data.commentaire,undefined);assert.equal(visible.catalog_data.source_url,undefined);assert.equal(visible.catalog_data.reference_operateur,undefined);await assert.rejects(()=>rpc('offers_admin'),/ADMIN_REQUIRED/);await assert.rejects(()=>db.query('select * from public.catalog_offer_import_metadata'),/permission denied/);
    await identity();const full=(await rpc('offers_admin')).find(offer=>offer.offer_code==='CONDITIONAL');assert.equal(full.delivery_proof,'Livraison testée pour un tiers');assert.ok(full.catalog_data.commentaire.length>0);
  });
  console.log(`${passed} SQL integration cases passed.`);
  await writeFile(resolve(root,'docs/catalog_offers/sql-results.json'),JSON.stringify({date:new Date().toISOString(),passed,failed:0,engine:'PGlite isolated PostgreSQL',remote:false},null,2)+'\n');
}catch(error){console.error(JSON.stringify({message:error.message,code:error.code,detail:error.detail,where:error.where}));process.exitCode=1;}finally{await db.close();}
