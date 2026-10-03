// The only way the app talks to the network. Every call: timeout, privacy guard, ledger entry (F-46).

import { http } from '@kit.NetworkKit';
import { Config } from './Config';
import { Logger } from './Logger';
import { forbiddenFields, Ledger, LedgerEntry } from '../privacy/Ledger';

const log: Logger = new Logger('Net');

// Where a request goes. Default: the app backend (Config.BACKEND_URL). Sharing always uses Supabase (shareTarget).
export class NetTarget {
  base: string;
  key: string;

  constructor(base: string, key: string) {
    this.base = base;
    this.key = key;
  }
}

export function backendTarget(): NetTarget {
  return new NetTarget(Config.hasBackend() ? Config.BACKEND_URL : '', Config.SUPABASE_ANON_KEY);
}

export function shareTarget(): NetTarget {
  return new NetTarget(Config.SHARE_BACKEND_URL, Config.SHARE_ANON_KEY);
}

function jsonHeaders(key: string, prefer: string): Record<string, string> {
  const h: Record<string, string> = {
    'Content-Type': 'application/json',
    'apikey': key,
    'Authorization': `Bearer ${key}`
  };
  if (prefer !== '') {
    h['Prefer'] = prefer;
  }
  return h;
}

export class NetResult {
  ok: boolean;
  status: number;
  body: string;

  constructor(ok: boolean, status: number, body: string) {
    this.ok = ok;
    this.status = status;
    this.body = body;
  }
}

export async function postJson(path: string, fields: Record<string, string>, timeoutMs: number,
  target: NetTarget = backendTarget()): Promise<NetResult> {
  return sendJson(http.RequestMethod.POST, path, fields, timeoutMs, target);
}

// DELETE with a JSON body (e.g. revoking a share). Same guard and ledger as postJson.
export async function deleteJson(path: string, fields: Record<string, string>, timeoutMs: number,
  target: NetTarget = backendTarget()): Promise<NetResult> {
  return sendJson(http.RequestMethod.DELETE, path, fields, timeoutMs, target);
}

// PostgREST upsert (insert, or merge on the primary key). Same guard and ledger; 200/201/204 count as success.
export async function upsertJson(path: string, fields: Record<string, string>, timeoutMs: number,
  target: NetTarget = backendTarget()): Promise<NetResult> {
  return sendJson(http.RequestMethod.POST, path, fields, timeoutMs, target, 'resolution=merge-duplicates');
}

async function sendJson(method: http.RequestMethod, path: string, fields: Record<string, string>,
  timeoutMs: number, target: NetTarget, prefer: string = ''): Promise<NetResult> {
  const names: string[] = Object.keys(fields);
  const blocked: string[] = forbiddenFields(names);
  const body: string = JSON.stringify(fields);
  const entry: LedgerEntry = { ts: Date.now(), endpoint: path, fields: names, bytes: body.length, outcome: 'OK' };
  if (blocked.length > 0) {
    entry.outcome = 'BLOCKED';
    await Ledger.add(entry);
    log.error(`blocked personal fields: ${blocked.join(',')}`);
    return new NetResult(false, 0, '');
  }
  if (target.base === '' || target.key === '') {
    return new NetResult(false, 0, '');
  }
  const req: http.HttpRequest = http.createHttp();
  try {
    const options: http.HttpRequestOptions = {
      method: method,
      header: jsonHeaders(target.key, prefer),
      extraData: body,
      connectTimeout: timeoutMs,
      readTimeout: timeoutMs
    };
    const res: http.HttpResponse = await req.request(`${target.base}${path}`, options);
    const ok: boolean = res.responseCode === 200 || (prefer !== '' && (res.responseCode === 201 || res.responseCode === 204));
    entry.outcome = ok ? 'OK' : 'ERROR';
    await Ledger.add(entry);
    return new NetResult(ok, res.responseCode, res.result as string);
  } catch (e) {
    entry.outcome = 'ERROR';
    await Ledger.add(entry);
    log.warn(`request ${path} failed: ${JSON.stringify(e)}`);
    return new NetResult(false, 0, '');
  } finally {
    req.destroy();
  }
}

// GET for read-only PostgREST views (no request body, so nothing personal leaves the device; still ledgered).
// Polling callers pass ledger=false after their first call so a 2 s poll doesn't flood the 200-entry ledger.
export async function getJson(path: string, timeoutMs: number, ledger: boolean = true,
  target: NetTarget = backendTarget()): Promise<NetResult> {
  const entry: LedgerEntry = { ts: Date.now(), endpoint: path, fields: [], bytes: 0, outcome: 'OK' };
  if (target.base === '' || target.key === '') {
    return new NetResult(false, 0, '');
  }
  const req: http.HttpRequest = http.createHttp();
  try {
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      header: {
        'apikey': target.key,
        'Authorization': `Bearer ${target.key}`
      },
      connectTimeout: timeoutMs,
      readTimeout: timeoutMs
    };
    const res: http.HttpResponse = await req.request(`${target.base}${path}`, options);
    entry.outcome = res.responseCode === 200 ? 'OK' : 'ERROR';
    if (ledger) {
      await Ledger.add(entry);
    }
    return new NetResult(res.responseCode === 200, res.responseCode, res.result as string);
  } catch (e) {
    entry.outcome = 'ERROR';
    if (ledger) {
      await Ledger.add(entry);
    }
    log.warn(`request ${path} failed: ${JSON.stringify(e)}`);
    return new NetResult(false, 0, '');
  } finally {
    req.destroy();
  }
}
