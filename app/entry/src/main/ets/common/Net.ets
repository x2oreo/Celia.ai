// The only way the app talks to the network. Every call: timeout, privacy guard, ledger entry (F-46).

import { http } from '@kit.NetworkKit';
import { Config } from './Config';
import { Logger } from './Logger';
import { blockedFields, forbiddenFields, Ledger, LedgerEntry, PersonalDataException } from '../privacy/Ledger';

const log: Logger = new Logger('Net');

// Where a request goes. Default: the app backend (Config.BACKEND_URL). Sharing always uses Supabase (shareTarget).
// `bearer` is the signed-in user's access token (JWT); empty → the request is made with the public key alone.
export class NetTarget {
  base: string;
  key: string;
  bearer: string;

  constructor(base: string, key: string, bearer: string = '') {
    this.base = base;
    this.key = key;
    this.bearer = bearer;
  }
}

// The signed-in user's access token, provided by account/Session.ets (Net cannot import Session: Session uses
// AuthClient, which uses Net). '' when signed out or when the stored token has expired (offline): the request then
// goes with the public key alone, which still reads the shared demo watch.
let userBearer: () => string = () => '';

export function setUserBearer(provider: () => string): void {
  userBearer = provider;
}

export function backendTarget(): NetTarget {
  return new NetTarget(Config.hasBackend() ? Config.BACKEND_URL : '', Config.SUPABASE_ANON_KEY);
}

// Database reads and writes (`/rest/v1/…`) on the accounts project carry the signed-in user's JWT, so row-level
// security can tell whose watch is asking (migration 20261004100200). Edge Functions (`/functions/v1/…`, the AI
// paths) never get it: the token names the user, and those requests stay anonymous.
export function sendsUserToken(path: string, base: string, accountsBase: string): boolean {
  return path.startsWith('/rest/v1/') && base.length > 0 && base === accountsBase;
}

function withUser(target: NetTarget, path: string): NetTarget {
  if (target.bearer.length > 0 || !sendsUserToken(path, target.base, Config.SHARE_BACKEND_URL)) {
    return target;
  }
  const token: string = userBearer();
  return token.length > 0 ? new NetTarget(target.base, target.key, token) : target;
}

export function shareTarget(): NetTarget {
  return new NetTarget(Config.SHARE_BACKEND_URL, Config.SHARE_ANON_KEY);
}

// The deployed Supabase project for accounts: Auth and the user's own rows. Pass the access token for requests
// made as the user (RLS `auth.uid()`); leave it empty for sign-up / log-in / refresh.
export function accountTarget(accessToken: string = ''): NetTarget {
  return Config.hasAccountBackend() ? new NetTarget(Config.SHARE_BACKEND_URL, Config.SHARE_ANON_KEY, accessToken) :
    new NetTarget('', '', '');
}

// The one place that decides the Authorization header: the user's JWT when there is one, else the public key.
// `apikey` is always the public key (Supabase's gateway needs it on every request).
function authHeaders(target: NetTarget): Record<string, string> {
  const h: Record<string, string> = {
    'apikey': target.key,
    'Authorization': `Bearer ${target.bearer.length > 0 ? target.bearer : target.key}`
  };
  return h;
}

function jsonHeaders(target: NetTarget, prefer: string): Record<string, string> {
  const h: Record<string, string> = authHeaders(target);
  h['Content-Type'] = 'application/json';
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
      header: jsonHeaders(withUser(target, path), prefer),
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
      header: authHeaders(withUser(target, path)),
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

// Options for requestJson (accounts and profile sync).
export class RequestOpts {
  prefer: string = '';
  // Named exception that lets this one endpoint carry the personal fields it lists (privacy/Ledger.ets).
  exception: PersonalDataException | undefined = undefined;
}

// Any method with a ready-made JSON body (nested objects allowed), for Supabase Auth and PostgREST calls made as the
// signed-in user. `fields` names what the body carries - top-level keys plus any personal fields nested inside -
// so the privacy guard and the ledger see them. Personal fields are refused unless `opts.exception` covers them for
// this endpoint. Any 2xx counts as success; the body is returned on errors too (Auth puts its error code there).
export async function requestJson(method: http.RequestMethod, path: string, body: string, fields: string[],
  timeoutMs: number, target: NetTarget, opts: RequestOpts = new RequestOpts()): Promise<NetResult> {
  const blocked: string[] = blockedFields(path, fields, opts.exception);
  const entry: LedgerEntry = { ts: Date.now(), endpoint: path, fields: fields, bytes: body.length, outcome: 'OK' };
  if (opts.exception !== undefined && forbiddenFields(fields).length > 0) {
    entry.exception = opts.exception.id;
  }
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
      header: jsonHeaders(target, opts.prefer),
      connectTimeout: timeoutMs,
      readTimeout: timeoutMs
    };
    if (body.length > 0) {
      options.extraData = body;
    }
    const res: http.HttpResponse = await req.request(`${target.base}${path}`, options);
    const ok: boolean = res.responseCode >= 200 && res.responseCode < 300;
    entry.outcome = ok ? 'OK' : 'ERROR';
    await Ledger.add(entry);
    return new NetResult(ok, res.responseCode, typeof res.result === 'string' ? res.result as string : '');
  } catch (e) {
    entry.outcome = 'ERROR';
    await Ledger.add(entry);
    log.warn(`request ${path} failed: ${JSON.stringify(e)}`);
    return new NetResult(false, 0, '');
  } finally {
    req.destroy();
  }
}
