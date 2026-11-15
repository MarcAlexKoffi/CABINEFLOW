// Read-only smoke checks for the deployed Back-office and import authorization.
const fs = require('node:fs');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const origin = 'https://izytel-backoffice-4bca7.web.app';
const endpoint = 'https://zrxeztxaxnzxevjuhzcc.supabase.co/functions/v1/izytel-catalog-import';
const build = 'build/catalog_import_backoffice/';
const localVersion = JSON.parse(fs.readFileSync(build + 'version.json', 'utf8'));
const results = [];
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
async function request(url, options = {}) {
  return fetch(url, {...options, signal: AbortSignal.timeout(20000)});
}
async function check(name, fn) {
  try { const details = await fn(); results.push({name, passed:true, ...details}); }
  catch (error) { results.push({name, passed:false, error:error.message}); }
}
(async () => {
  await Promise.all([
    check('backoffice_index', async () => {
      const response = await request(origin + '/'); const html = await response.text();
      assert.equal(response.status, 200); assert.ok(html.includes('<title>IzyTel Back-office</title>'));
      assert.equal(hash(html), hash(fs.readFileSync(build + 'index.html')));
      assert.ok(response.headers.get('x-robots-tag')?.includes('noindex'));
      assert.ok(response.headers.get('cache-control')?.includes('no-cache'));
      return {status:response.status, sha256:hash(html), robots:response.headers.get('x-robots-tag')};
    }),
    check('version_marker', async () => {
      const response = await request(origin + '/version.json'); assert.equal(response.status, 200);
      const version = await response.json(); assert.deepEqual(version, localVersion);
      assert.ok(response.headers.get('cache-control')?.includes('no-store'));
      return {status:response.status, version};
    }),
    check('main_bundle', async () => {
      const response = await request(origin + '/main.dart.js'); assert.equal(response.status, 200);
      const bytes = Buffer.from(await response.arrayBuffer()); assert.equal(hash(bytes), localVersion.mainDartJsSha256);
      return {status:response.status, bytes:bytes.length, sha256:hash(bytes)};
    }),
    check('bootstrap', async () => {
      const response = await request(origin + '/flutter_bootstrap.js'); assert.equal(response.status, 200);
      const bytes = Buffer.from(await response.arrayBuffer()); assert.equal(hash(bytes), hash(fs.readFileSync(build + 'flutter_bootstrap.js')));
      return {status:response.status, sha256:hash(bytes)};
    }),
    check('backoffice_manifest', async () => {
      const response = await request(origin + '/manifest.json'); assert.equal(response.status, 200);
      const manifest = await response.json(); assert.equal(manifest.name, 'IzyTel Back-office');
      return {status:response.status, name:manifest.name};
    }),
    check('xlsx_template', async () => {
      const response = await request(origin + '/assets/assets/templates/Modele_import_offres_IzyTel.xlsx'); assert.equal(response.status, 200);
      const bytes = Buffer.from(await response.arrayBuffer()); assert.equal(hash(bytes), hash(fs.readFileSync('assets/templates/Modele_import_offres_IzyTel.xlsx')));
      return {status:response.status, bytes:bytes.length, sha256:hash(bytes)};
    }),
    check('spa_rewrite', async () => {
      const response = await request(origin + '/hosting-spa-probe'); assert.equal(response.status, 200);
      assert.equal(hash(await response.text()), hash(fs.readFileSync(build + 'index.html')));
      return {status:response.status};
    }),
    ...[origin, 'https://izytel-backoffice-4bca7.firebaseapp.com', 'https://cabineflow-4bca7.web.app'].map(allowed => check('cors_' + new URL(allowed).hostname, async () => {
      const response = await request(endpoint, {method:'OPTIONS',headers:{Origin:allowed,'Access-Control-Request-Method':'POST','Access-Control-Request-Headers':'authorization,apikey,content-type,x-client-info'}});
      assert.equal(response.status, 200); assert.equal(response.headers.get('access-control-allow-origin'), allowed);
      for (const header of ['authorization','apikey','content-type','x-client-info']) assert.ok(response.headers.get('access-control-allow-headers')?.includes(header));
      return {status:response.status, allowOrigin:response.headers.get('access-control-allow-origin')};
    })),
    check('unauthenticated_import_denied', async () => {
      const response = await request(endpoint, {method:'POST',headers:{Origin:origin}});
      assert.equal(response.status, 401); assert.equal(response.headers.get('access-control-allow-origin'), origin);
      return {status:response.status};
    }),
    check('invalid_token_import_denied', async () => {
      const response = await request(endpoint, {method:'POST',headers:{Origin:origin,Authorization:'Bearer invalid-token'}});
      assert.equal(response.status, 403); return {status:response.status};
    }),
    check('unknown_origin_denied', async () => {
      const response = await request(endpoint, {method:'OPTIONS',headers:{Origin:'https://example.invalid'}});
      assert.equal(response.status, 403); assert.equal(response.headers.get('access-control-allow-origin'), null);
      return {status:response.status};
    })
  ]);
  results.sort((a,b) => a.name.localeCompare(b.name));
  const report = {verifiedAt:new Date().toISOString(),url:origin,applicationCommit:localVersion.applicationCommit,passed:results.filter(r=>r.passed).length,failed:results.filter(r=>!r.passed).length,checks:results};
  fs.writeFileSync('scratch/backoffice_hosting_http_results.json', JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify(report, null, 2));
  if (report.failed) process.exitCode = 1;
})().catch(error => {console.error(error);process.exitCode=1;});
