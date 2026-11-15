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
  await test('100-offer publication: eligibility summary, explicit exclusions, two batches, concurrent change and idempotent retry',async()=>{
    const data=rows(100,'PUBLICATION').map((row,i)=>({...fixtures[0],_row:i+2,code_offre:row.code_offre,activable_pour_tiers:i%5===0?'A_VERIFIER':'OUI',canal_activation:'MANUEL',verifie_le:new Date().toISOString().slice(0,10)}));
    await run(await prepare(data));
    const selected=(await rpc('offers_admin')).filter(value=>value.offer_code.startsWith('PUBLICATION-'));
    const id=crypto.randomUUID(),change={operation:'activate',items:selected.map(value=>({id:value.id,version:value.catalog_version}))};
    await identity('manager');await assert.rejects(()=>rpc('bulk_prepare',[id,JSON.stringify(change)],['uuid','jsonb']),/ADMIN_REQUIRED/);await identity();
    await rpc('bulk_prepare',[id,JSON.stringify(change)],['uuid','jsonb']);
    const preview=await get(id);assert.equal(preview.summary.update,80);assert.equal(preview.summary.error,20);assert.equal(preview.lines.length,20);
    assert.equal((await rpc('offers_admin')).filter(value=>value.offer_code.startsWith('PUBLICATION-')&&value.is_active).length,0);
    await assert.rejects(()=>rpc('import_confirm',[id,false],['uuid','boolean']),/ERRORS_REQUIRE_CONFIRMATION/);
    const concurrent=selected.find(value=>value.offer_code==='PUBLICATION-1');
    await rpc('offer_save',[concurrent.id,concurrent.catalog_version,JSON.stringify({...data[1],prix_fcfa:'777'}),null],['text','bigint','jsonb','text']);
    await rpc('import_confirm',[id,true],['uuid','boolean']);
    const first=await rpc('import_apply',[id],['uuid']);assert.equal(first.job.status,'running');assert.equal(first.job.cursor,50);
    const result=await rpc('import_apply',[id],['uuid']);assert.equal(result.job.status,'completed');assert.equal(result.job.cursor,100);assert.equal(result.summary.applied,79);assert.equal(result.summary.conflict,1);
    const after=await rpc('offers_admin');assert.equal(after.filter(value=>value.offer_code.startsWith('PUBLICATION-')&&value.is_active).length,79);
    const blocked=after.find(value=>value.offer_code==='PUBLICATION-0');assert.equal(blocked.catalog_status,'BROUILLON');assert.equal(blocked.catalog_version,selected.find(value=>value.id===blocked.id).catalog_version);
    assert.equal((await offer('PUBLICATION-1')).selling_price,777);assert.equal((await offer('PUBLICATION-1')).is_active,false);
    await rpc('import_apply',[id],['uuid']);assert.deepEqual(await rpc('offers_admin'),after);
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
  // Upgrade the exact historical pipeline above, then verify the new file-only
  // publication policy without weakening commercial validation or access.
  await db.exec('reset role');
  await db.exec(await readFile(resolve(root,'supabase/migrations/20261115205903_catalog_direct_file_publication.sql'),'utf8'));
  await identity();
  async function filePreview(data){const id=crypto.randomUUID();await rpc('file_import_prepare',[id,'direct.xlsx','b'.repeat(64),JSON.stringify(data)],['uuid','text','text','jsonb']);return id;}
  let directRows,directOffers;
  await test('53 file offers publish on confirmation without verification policy, channel or conditional delivery evidence',async()=>{
    const config=await rpc('configuration');await rpc('save_configuration',[config.settings.version,null,JSON.stringify(config.families)],['bigint','integer','jsonb']);
    directRows=rows(53,'DIRECT');const id=await filePreview(directRows),preview=await get(id);
    assert.equal(preview.summary.error,0);assert.equal(preview.summary.create,53);assert.ok(preview.lines.every(line=>line.data.statut==='ACTIF'));
    assert.equal(await offer('DIRECT-0'),undefined);await assert.rejects(()=>rpc('import_apply',[id],['uuid']),/CONFIRMATION_REQUIRED/);
    const result=await run(id);assert.equal(result.summary.applied,53);
    directOffers=(await rpc('offers_admin')).filter(value=>value.offer_code.startsWith('DIRECT-'));assert.equal(directOffers.length,53);assert.ok(directOffers.every(value=>value.is_active&&value.catalog_status==='ACTIF'));
    assert.ok(directOffers.every(value=>value.catalog_data.activable_pour_tiers==='A_VERIFIER'&&value.catalog_data.canal_activation==='A_VERIFIER'&&value.catalog_data.verifie_le===''&&value.delivery_proof===null));
    await identity('customer');assert.equal((await db.query("select count(*)::integer n from public.catalog_offers where offer_code like 'DIRECT-%' and is_active")).rows[0].n,53);await identity();
  });
  await test('same draft workbook reimport leaves published IDs, values and versions unchanged',async()=>{
    const id=await filePreview(directRows);assert.equal((await get(id)).summary.unchanged,53);await run(id);
    assert.deepEqual((await rpc('offers_admin')).filter(value=>value.offer_code.startsWith('DIRECT-')),directOffers);
  });
  await test('file import retains explicit inactive/deactivation and does not auto-publish editor or bulk-priority drafts',async()=>{
    const id=await filePreview([{...rows(1,'KEEP-INACTIVE')[0],statut:'INACTIF'},{_row:3,action:'DESACTIVER',code_offre:'DIRECT-0'}]);await run(id);
    assert.equal((await offer('KEEP-INACTIVE-0')).is_active,false);assert.equal((await offer('DIRECT-0')).is_active,false);
    await run(await prepare(rows(1,'MANUAL-DRAFT')));const before=await offer('MANUAL-DRAFT-0');assert.equal(before.catalog_status,'BROUILLON');
    const bulk=crypto.randomUUID();await rpc('bulk_prepare',[bulk,JSON.stringify({operation:'priority',value:'77',items:[{id:before.id,version:before.catalog_version}]})],['uuid','jsonb']);await run(bulk);assert.equal((await offer('MANUAL-DRAFT-0')).catalog_status,'BROUILLON');
  });
  await test('100-row direct import retains duplicate/price errors and explicit partial consent, applying only 97 valid offers',async()=>{
    const data=rows(100,'DIRECT-LARGE');data[1].code_offre=data[0].code_offre;data[2].prix_fcfa='-1';const id=await filePreview(data),preview=await get(id);
    assert.equal(preview.summary.error,3);assert.equal(preview.summary.create,97);await assert.rejects(()=>run(id),/ERRORS_REQUIRE_CONFIRMATION/);const result=await run(id,true);assert.equal(result.summary.applied,97);
    const visible=(await rpc('offers_admin')).filter(value=>value.offer_code.startsWith('DIRECT-LARGE-'));assert.equal(visible.length,97);assert.ok(visible.every(value=>value.is_active));
  });
  await test('direct publication preserves version conflicts, rollback and retry idempotency',async()=>{
    const before=await offer('DIRECT-1'),data=[{...directRows[1],prix_fcfa:'987'}],a=await filePreview(data),b=await filePreview(data);await run(a);
    const conflict=await run(b);assert.equal(conflict.summary.conflict,1);assert.equal(conflict.summary.applied,0);const changed=await offer('DIRECT-1');assert.equal(changed.id,before.id);assert.equal(changed.selling_price,987);
    await rpc('import_apply',[a],['uuid']);assert.equal((await offer('DIRECT-1')).catalog_version,changed.catalog_version);await rpc('import_restore',[a],['uuid']);assert.equal((await offer('DIRECT-1')).selling_price,before.selling_price);
  });
  await test('direct import rejects non-admin and foreign tokens; malformed fields and invalid families remain blocked',async()=>{
    for(const uid of ['manager','agent','customer']){await identity(uid);await assert.rejects(()=>filePreview(rows(1,'DENIED')),/ADMIN_REQUIRED/);}
    await identity('admin','foreign');await assert.rejects(()=>filePreview(rows(1,'DENIED')),/ADMIN_REQUIRED/);await identity();
    const id=await filePreview([{...rows(1,'BAD-DIRECT')[0],prix_fcfa:'oops'},{...rows(1,'BAD-FAMILY')[0],_row:3,famille:'UNKNOWN'}]);assert.equal((await get(id)).summary.error,2);
  });
  const presentationRows=[
    {...fixtures[0],_row:2,code_offre:'PRESENT-DEC',operateur:'MTN',nom_affiche:'2,2 GO',volume_data:'2.2000000000000002',unite_data:'GO',reference_operateur:'  Packs   Internet  ',source_url:'https://internal.invalid/private',commentaire:'Private note'},
    {...fixtures[0],_row:3,code_offre:'PRESENT-MAX',famille:'MAXIT',mis_en_avant:'OUI',reference_operateur:'Pass Max it'},
    {...fixtures[0],_row:4,code_offre:'PRESENT-CHIC',operateur:'MTN',famille:'CCHIC',reference_operateur:"C'Chic"},
    {...fixtures[0],_row:5,code_offre:'PRESENT-MIX',operateur:'MTN',famille:'MIX',type_forfait:'MIXTE',minutes_appels:'55',nombre_sms:'100',reference_operateur:'Free Plus'},
    {...fixtures[0],_row:6,code_offre:'PRESENT-CLASSICS',operateur:'MOOV',mis_en_avant:'OUI',reference_operateur:'Internet   Classics'},
  ];
  await run(await filePreview(presentationRows));
  const presentationBefore=(await rpc('offers_admin')).filter(value=>value.offer_code.startsWith('PRESENT-'));
  const decimalBefore=await offer('PRESENT-DEC');
  const featuredBefore=(await rpc('offers_admin')).filter(value=>value.badge_label!==null).map(value=>value.id).sort();
  assert.equal((await offer('PRESENT-DEC')).volume,'2.2000000000000002 GO');
  await db.exec('reset role');
  await db.query('insert into public.customer_order_recovery_registry(order_id,offer_id,offer_label,amount,izytel_fee,payment_fee) values($1,$2,$3,200,25,10)', ['presentation-order',presentationBefore.find(value=>value.offer_code==='PRESENT-DEC').id,'Original label']);
  const frozenPresentationOrder=(await db.query("select * from public.customer_order_recovery_registry where order_id='presentation-order'")).rows[0];
  await db.exec(await readFile(resolve(root,'supabase/migrations/20261115213025_catalog_offer_presentation.sql'),'utf8'));
  await identity();
  await test('existing 2.2 GB display becomes French 2,2 GO, keeping source decimal, identity, price, units and status',async()=>{
    const after=await offer('PRESENT-DEC'),before=decimalBefore;
    assert.equal(after.volume,'2,2 GO');assert.equal(after.details[0],'Packs Internet · 2,2 GO');assert.equal(after.details[1],'Validité 2 jours');
    for(const field of ['id','offer_code','title','selling_price','is_active','catalog_status','created_at','catalog_data'])assert.deepEqual(after[field],before[field],field);
    assert.equal(after.catalog_data.volume_data,'2.2000000000000002');assert.equal(after.catalog_data.unite_data,'GO');assert.equal(after.catalog_version,before.catalog_version+1);
  });
  await test('family uses existing badges only for featured offers; non-featured mixed offers retain all four details and validity',async()=>{
    const after=await rpc('offers_admin');assert.deepEqual(after.filter(value=>value.badge_label!==null).map(value=>value.id).sort(),featuredBefore);
    assert.equal((await offer('PRESENT-MAX')).badge_label,'Pass Max it');assert.equal((await offer('PRESENT-CLASSICS')).badge_label,'Internet Classics');
    const chic=await offer('PRESENT-CHIC'),mixed=await offer('PRESENT-MIX');assert.equal(chic.badge_label,null);assert.equal(chic.details[0],"C'Chic · 220 MO");
    assert.deepEqual(mixed.details,['Free Plus · 220 MO','55 min','100 SMS','Validité 2 jours']);
  });
  await test('presentation persists through reimport and legacy status updates without repeated family prefixes',async()=>{
    const before=await offer('PRESENT-DEC'),id=await filePreview(presentationRows);assert.equal((await get(id)).summary.unchanged,5);await run(id);assert.equal((await offer('PRESENT-DEC')).catalog_version,before.catalog_version);
    await db.query('select public.izytel_set_catalog_offer_active($1,false)',[before.id]);await db.query('select public.izytel_set_catalog_offer_active($1,true)',[before.id]);
    assert.equal((await offer('PRESENT-DEC')).details[0],'Packs Internet · 2,2 GO');
  });
  await test('future imports normalize volume display and family spaces; missing and long names keep existing badge semantics',async()=>{
    const data=[{...fixtures[0],_row:2,code_offre:'NEW-PRESENT',operateur:'MOOV',famille:'FOLIE',volume_data:'7.4000000000000004',unite_data:'GO',mis_en_avant:'OUI',reference_operateur:' Folie   Internet '},
      {...fixtures[0],_row:3,code_offre:'LONG-PRESENT',mis_en_avant:'OUI',reference_operateur:'Une famille avec un libellé commercial très long'},
      {...fixtures[0],_row:4,code_offre:'EMPTY-PRESENT',mis_en_avant:'OUI',reference_operateur:''}];
    await run(await filePreview(data));assert.equal((await offer('NEW-PRESENT')).volume,'7,4 GO');assert.equal((await offer('NEW-PRESENT')).badge_label,'Folie Internet');
    assert.equal((await offer('LONG-PRESENT')).badge_label,'Mis en avant');assert.match((await offer('LONG-PRESENT')).details[0],/^Une famille avec un libellé commercial très long · 220 MO$/);
    assert.equal((await offer('EMPTY-PRESENT')).badge_label,'Mis en avant');assert.equal((await offer('EMPTY-PRESENT')).details[0],'220 MO');
  });
  await test('presentation backfill leaves frozen orders and financial fields intact; backup and internal metadata remain private',async()=>{
    await db.exec('reset role');assert.deepEqual((await db.query("select * from public.customer_order_recovery_registry where order_id='presentation-order'")).rows[0],frozenPresentationOrder);
    const backup=(await db.query('select * from private.catalog_presentation_backup_20261115213025 where offer_id=$1',[presentationBefore[0].id])).rows[0];assert.ok(backup);assert.equal(backup.before_state.id,presentationBefore[0].id);
    assert.equal((await db.query("select private.catalog_quantity_label('0.000000001') label")).rows[0].label,'0,000000001');
    await identity('customer');await assert.rejects(()=>db.query('select * from private.catalog_presentation_backup_20261115213025'),/permission denied/);
    const visible=(await db.query("select * from public.catalog_offers where offer_code='PRESENT-DEC'")).rows[0];assert.equal(visible.catalog_data.source_url,undefined);assert.equal(visible.catalog_data.commentaire,undefined);assert.equal(visible.catalog_data.reference_operateur,undefined);
    await identity();assert.ok((await rpc('offer_history',[visible.id],['text'])).some(event=>event.action==='catalog_presentation_updated'));
  });
  console.log(`${passed} SQL integration cases passed.`);
  await writeFile(resolve(root,'docs/catalog_offers/sql-results.json'),JSON.stringify({date:new Date().toISOString(),passed,failed:0,engine:'PGlite isolated PostgreSQL',remote:false},null,2)+'\n');
}catch(error){console.error(JSON.stringify({message:error.message,code:error.code,detail:error.detail,where:error.where}));process.exitCode=1;}finally{await db.close();}
