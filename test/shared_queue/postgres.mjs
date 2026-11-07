import {initdb, postgres, pg_ctl} from '@embedded-postgres/windows-x64';
import pg from 'pg';
import {mkdir, mkdtemp} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {join} from 'node:path';
import {execFileSync, spawn} from 'node:child_process';
import {createServer} from 'node:net';

export const root = fileURLToPath(new URL('../../', import.meta.url));

// A new loopback-only cluster per run; never consumes a database URL or credentials.
export async function withPostgres(run) {
  await mkdir(join(root, 'scratch'), {recursive: true});
  const data = await mkdtemp(join(root, 'scratch/shared-queue-integration-'));
  const socket = createServer();
  await new Promise(resolve => socket.listen(0, '127.0.0.1', resolve));
  const port = socket.address().port;
  await new Promise(resolve => socket.close(resolve));
  execFileSync(initdb, ['-D', data, '-U', 'izytel_test', '-A', 'trust', '--no-locale', '--no-sync', '-E', 'UTF8'], {windowsHide: true, stdio: 'pipe'});
  const child = spawn(postgres, ['-D', data, '-p', String(port), '-h', '127.0.0.1'], {windowsHide: true, stdio: 'ignore'});
  const clients = [];
  const connect = async () => {
    const client = new pg.Client({host: '127.0.0.1', port, user: 'izytel_test', database: 'postgres', connectionTimeoutMillis: 10000});
    try { await client.connect(); } catch (error) { await client.end().catch(() => {}); throw error; }
    clients.push(client);
    return client;
  };
  try {
    let admin;
    for (let attempt = 0; attempt < 60; attempt++) {
      try { admin = await connect(); break; } catch { await new Promise(resolve => setTimeout(resolve, 100)); }
    }
    if (!admin) throw new Error('The isolated local PostgreSQL server did not start.');
    return await run({admin, connect});
  } finally {
    await Promise.all(clients.map(client => client.end().catch(() => {})));
    try { execFileSync(pg_ctl, ['-D', data, '-m', 'fast', '-w', 'stop'], {windowsHide: true, stdio: 'pipe'}); }
    catch { child.kill(); }
  }
}
