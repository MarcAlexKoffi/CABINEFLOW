import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import test from 'node:test';
import vm from 'node:vm';

// Exercise the actual HTTP boundary without loading Firebase/Supabase SDKs.
// Preflight and missing-token requests must return before any SDK is accessed.
const source = stripTypeScriptTypes(
  (await readFile(new URL('./index.ts', import.meta.url), 'utf8'))
    .replace(/^import .+;\r?$/gm, ''),
);
function handler(configuredOrigins = '') {
  let handle;
  vm.runInNewContext(source, {
    Request, Response,
    Deno: {
      env: { get: name => name === 'IZYTEL_ADMIN_ALLOWED_ORIGINS' ? configuredOrigins : undefined },
      serve: callback => { handle = callback; },
    },
  });
  return handle;
}
const endpoint = 'https://example.supabase.co/functions/v1/izytel-user-admin';
const origins = [
  'http://localhost:8080',
  'http://127.0.0.1:8080',
  'https://cabineflow-4bca7.web.app',
  'https://cabineflow-4bca7.firebaseapp.com',
  'https://izytel-backoffice-4bca7.web.app',
  'https://izytel-backoffice-4bca7.firebaseapp.com',
];
for (const origin of origins) {
  test(`preflight accepts the exact known origin ${origin}`, async () => {
    const response = await handler()(new Request(endpoint, {method:'OPTIONS', headers:{Origin:origin}}));
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('access-control-allow-origin'), origin);
    assert.equal(response.headers.get('vary'), 'Origin');
    assert.equal(response.headers.get('access-control-allow-methods'), 'POST, OPTIONS');
    for (const header of ['authorization', 'apikey', 'content-type', 'x-client-info']) {
      assert.ok(response.headers.get('access-control-allow-headers').includes(header));
    }
  });
}
for (const origin of [
  'https://example.invalid',
  'https://izytel-backoffice-4bca7.web.app.attacker.invalid',
  'http://izytel-backoffice-4bca7.web.app',
  'https://izytel-backoffice-4bca7.web.app:8443',
]) {
  test(`preflight denies an unlisted origin ${origin}`, async () => {
    const response = await handler()(new Request(endpoint, {method:'OPTIONS', headers:{Origin:origin}}));
    assert.equal(response.status, 403);
    assert.equal(response.headers.get('access-control-allow-origin'), null);
    assert.equal((await response.json()).error, 'ORIGIN_DENIED');
  });
}
test('an explicit configured list still replaces the defaults', async () => {
  const handle = handler(' https://admin.example.org, , https://admin2.example.org ');
  for (const origin of ['https://admin.example.org', 'https://admin2.example.org']) {
    const response = await handle(new Request(endpoint, {method:'OPTIONS',headers:{Origin:origin}}));
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('access-control-allow-origin'), origin);
  }
  const rejected = await handle(new Request(endpoint, {method:'OPTIONS',headers:{Origin:origins[4]}}));
  assert.equal(rejected.status, 403);
});
test('the hosted backoffice still needs a bearer token for account operations', async () => {
  const response = await handler()(new Request(endpoint, {method:'POST',headers:{Origin:origins[4]},body:'{}'}));
  assert.equal(response.status, 401);
  assert.equal(response.headers.get('access-control-allow-origin'), origins[4]);
  assert.equal((await response.json()).error, 'AUTH_REQUIRED');
});
test('CORS access does not enable unsupported HTTP methods', async () => {
  const response = await handler()(new Request(endpoint, {headers:{Origin:origins[4]}}));
  assert.equal(response.status, 405);
});
