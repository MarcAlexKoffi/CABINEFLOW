// Run with IZYTEL_QA_NODE_MODULES set to an existing Playwright/jszip installation.
const path=require('node:path');
const fs=require('node:fs');
const assert=require('node:assert/strict');
const modules=process.env.IZYTEL_QA_NODE_MODULES;
if(!modules)throw new Error('Set IZYTEL_QA_NODE_MODULES to existing Playwright and jszip modules.');
const {chromium}=require(path.join(modules,'playwright'));
const JSZip=require(path.join(modules,'jszip'));
const root=path.resolve(__dirname,'..'),out=path.join(__dirname,'evidence');
fs.mkdirSync(out,{recursive:true});
const workbook=path.join(root,'Modele_import_offres_IzyTel.xlsx');
const base=process.env.IZYTEL_DESIGN_URL||'http://127.0.0.1:4317';
const checks=[],errors=[];
let browser;
async function check(name,fn){await fn();checks.push(name);console.log(`PASS ${name}`);}
(async()=>{
  browser=await chromium.launch({channel:'msedge',headless:true});
  const context=await browser.newContext({viewport:{width:1440,height:1100},deviceScaleFactor:1});
  const page=await context.newPage();page.on('pageerror',error=>errors.push(error.message));
  await page.goto(base);await page.locator('.offer-card').first().waitFor();await page.evaluate(()=>document.fonts.ready);
  await page.screenshot({path:path.join(out,'catalogue-1440.png'),fullPage:true});
  await check('catalogue: 8 cards, two columns, operator families, search',async()=>{
    assert.equal(await page.locator('.offer-card').count(),8);
    assert.equal(await page.locator('.offer-grid').evaluate(el=>getComputedStyle(el).gridTemplateColumns.split(' ').length),2);
    await page.getByRole('button',{name:/Orange.*3/}).click();assert.equal(await page.locator('.offer-card').count(),3);
    assert.ok((await page.locator('#family').textContent()).includes('MAXIT'));assert.ok(!(await page.locator('#family').textContent()).includes('CCHIC'));
    await page.locator('#search').fill('OR-DAT-001');assert.equal(await page.locator('.offer-card').count(),1);
    await page.locator('#search').fill('introuvable');assert.equal(await page.locator('.empty').count(),1);
    await page.getByRole('button',{name:'Effacer les filtres'}).click();assert.equal(await page.locator('.offer-card').count(),8);
  });
  await check('keyboard: search shortcut, menu, modal Escape and focus return',async()=>{
    await page.locator('h1').click();await page.keyboard.press('/');assert.equal(await page.locator('#search').evaluate(el=>el===document.activeElement),true);
    const menu=page.getByRole('button',{name:'Actions pour OR-DAT-001',exact:true});await menu.click();await page.keyboard.press('ArrowDown');assert.equal(await page.getByRole('menuitem',{name:'Dupliquer'}).evaluate(el=>el===document.activeElement),true);await page.keyboard.press('Escape');
    await page.getByRole('button',{name:'Ajouter une offre',exact:true}).click();assert.equal(await page.locator('dialog').evaluate(el=>el.open),true);await page.keyboard.press('Escape');assert.equal(await page.locator('#add').evaluate(el=>el===document.activeElement),true);
  });
  await check('responsive: 320, 390, 768 and 1440 px with no page overflow',async()=>{
    for(const width of [320,390,768,1440]){
      await page.setViewportSize({width,height:1000});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true,`overflow ${width}`);
      if(width<=390)assert.equal(await page.locator('.offer-grid').evaluate(el=>getComputedStyle(el).gridTemplateColumns.split(' ').length),1);
      if([390,768].includes(width))await page.screenshot({path:path.join(out,`catalogue-${width}.png`),fullPage:true});
      await page.locator('#import').click();assert.equal(await page.locator('dialog').evaluate(el=>el.scrollWidth<=el.clientWidth+1),true,`dialog overflow ${width}`);
      if(width===390)await page.screenshot({path:path.join(out,'import-390.png')});await page.keyboard.press('Escape');
    }
  });
  async function actualPreview(){await page.locator('#import').click();await page.locator('#file-input').setInputFiles(workbook);await page.getByRole('heading',{name:'Vérifier les changements'}).waitFor();}
  async function confirm(){await page.locator('#preview-continue').click();await page.locator('#confirm-check').check();await page.locator('#confirm-import').click();await page.getByRole('heading',{name:'Compte rendu de l’import'}).waitFor();}
  await check('real XLSX: 40 rows from OFFRES only; preview does not change catalog',async()=>{
    await actualPreview();assert.match(await page.locator('.import-file').textContent(),/40 lignes dans OFFRES/);assert.equal(await page.locator('.impact.error b').textContent(),'0');assert.equal(await page.locator('#nav-count').textContent(),'8');
    await page.screenshot({path:path.join(out,'apercu-modele-1440.png')});
    await confirm();await page.locator('#done-import').click();assert.equal(await page.locator('#nav-count').textContent(),'40');
    await actualPreview();assert.equal(await page.locator('.impact.unchanged b').textContent(),'40');assert.equal(await page.locator('.impact.create b').textContent(),'0');await page.keyboard.press('Escape');
  });
  await check('four drafts: create then reimport unchanged',async()=>{
    await page.locator('#reset').click();await page.locator('#import').click();await page.getByRole('button',{name:'4 nouveaux brouillons'}).click();assert.equal(await page.locator('.impact.create b').textContent(),'4');await confirm();await page.locator('#another-import').click();await page.getByRole('button',{name:'4 nouveaux brouillons'}).click();assert.equal(await page.locator('.impact.unchanged b').textContent(),'4');await page.keyboard.press('Escape');
  });
  await check('price change: stable ID and historical order snapshot',async()=>{
    await page.locator('#snapshot').click();const before=await page.locator('.snapshot>div').first().textContent();await page.locator('#snapshot-price').click();assert.equal(await page.locator('.impact.update b').textContent(),'1');assert.match(await page.locator('.preview-wrap').textContent(),/prix_fcfa/);await confirm();await page.locator('#done-import').click();await page.locator('#snapshot').click();assert.equal(await page.locator('.snapshot>div').first().textContent(),before);await page.screenshot({path:path.join(out,'snapshot-commande.png')});await page.keyboard.press('Escape');
  });
  await check('duplicate codes: all lines blocked; partial import requires explicit choice',async()=>{
    await page.locator('#import').click();await page.getByRole('button',{name:'Doublons & erreurs'}).click();assert.equal(await page.locator('.impact.error b').textContent(),'4');assert.equal(await page.locator('#preview-continue').isDisabled(),true);assert.match(await page.locator('.preview-wrap').textContent(),/lignes 2, 3/);await page.locator('#partial-check').check();assert.equal(await page.locator('#preview-continue').isEnabled(),true);await page.screenshot({path:path.join(out,'erreurs-import-1440.png')});await page.keyboard.press('Escape');
  });
  await check('large import: pagination, interruption, same importId, resumed result and restore',async()=>{
    await page.locator('#reset').click();await page.locator('#import').click();await page.getByRole('button',{name:'520 lignes & reprise'}).click();assert.equal(await page.locator('.preview-wrap tbody tr').count(),20);assert.equal(await page.locator('.impact.create b').textContent(),'515');assert.equal(await page.locator('.impact.error b').textContent(),'5');await page.locator('#preview-next').click();assert.match(await page.locator('.pagination').textContent(),/21–40/);await page.locator('#partial-check').check();await page.locator('#preview-continue').click();await page.locator('#confirm-check').check();await page.locator('#interrupt-check').check();await page.locator('#confirm-import').click();await page.getByRole('heading',{name:'Import interrompu · reprise disponible'}).waitFor();const id=await page.locator('.import-id').textContent();await page.locator('#resume-import').click();await page.getByRole('heading',{name:'Compte rendu de l’import'}).waitFor();assert.equal(await page.locator('.import-id').textContent(),id);assert.match(await page.locator('.progress-area p').textContent(),/515 changements appliqués/);await page.screenshot({path:path.join(out,'rapport-520-lignes.png'),fullPage:true});
    const downloaded=page.waitForEvent('download');await page.locator('#download-report').click();assert.match((await downloaded).suggestedFilename(),/rapport\.json$/);
    await page.locator('#restore-import').click();await page.locator('#restore-confirm').click();await page.getByRole('heading',{name:'Révision restaurée'}).waitFor();await page.locator('#done-import').click();assert.equal(await page.locator('#nav-count').textContent(),'523');
  });
  await check('file rejection: missing OFFRES, formula, macro and oversized input',async()=>{
    const original=fs.readFileSync(workbook);
    for(const kind of ['missing','formula','macro','size']){
      let buffer;
      if(kind==='size')buffer=Buffer.alloc(5*1024*1024+1);
      else{const zip=await JSZip.loadAsync(original);
        if(kind==='missing'){const file='xl/workbook.xml';zip.file(file,(await zip.file(file).async('string')).replace('name="OFFRES"','name="AUTRE"'));}
        if(kind==='formula'){const file='xl/worksheets/sheet1.xml';zip.file(file,(await zip.file(file).async('string')).replace(/(<c[^>]+r="G2"[^>]*>)/,'$1<f>1+1</f>'));}
        if(kind==='macro')zip.file('xl/vbaProject.bin',Buffer.from('not executed'));
        buffer=await zip.generateAsync({type:'nodebuffer',compression:'DEFLATE'});
      }
      await page.locator('#import').click();await page.locator('#file-input').setInputFiles({name:`test-${kind}.xlsx`,mimeType:'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',buffer});await page.locator('#file-error .notice.error').waitFor();const message=await page.locator('#file-error').textContent();assert.match(message,kind==='missing'?/OFFRES est absente/:kind==='formula'?/Formule refusée/:kind==='macro'?/macros/:/volumineux/);await page.keyboard.press('Escape');
    }
  });
  await check('table selection, bulk impact preview, manual duplicate editor and no HTML execution',async()=>{
    await page.locator('#reset').click();await page.locator('#view-table').click();await page.locator('[data-select]').first().check();await page.locator('#bulk-edit').click();await page.locator('#bulk-preview').click();assert.equal(await page.locator('.impact.deactivate b').textContent(),'1');await page.keyboard.press('Escape');
    await page.getByRole('button',{name:'Actions pour OR-DAT-001',exact:true}).click();await page.getByRole('menuitem',{name:'Dupliquer'}).click();await page.locator('[name="nom_affiche"]').fill('<img src=x onerror=alert(1)>');await page.getByRole('button',{name:'Enregistrer',exact:true}).click();await page.locator('#search').fill('<img');assert.equal(await page.locator('.data-table tbody tr').count(),1);assert.equal(await page.locator('#offers img[src="x"]').count(),0);
  });
  assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(out,'results.json'),JSON.stringify({revision:'R1',status:'DESIGN_REVIEW',date:new Date().toISOString(),browser:await browser.version(),checks,errors,productionBackendTested:false},null,2)+'\n');
  console.log(`${checks.length} browser scenarios passed, no page errors.`);
})().catch(error=>{console.error(error);process.exitCode=1;}).finally(async()=>{await browser?.close();});
