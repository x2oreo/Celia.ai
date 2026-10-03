// The only way the app talks to the network. Every call: timeout, privacy guard, ledger entry (F-46).

import { http } from '@kit.NetworkKit';
import { Config } from './Config';
import { Logger } from './Logger';
import { forbiddenFields, Ledger, LedgerEntry } from '../privacy/Ledger';

const log: Logger = new Logger('Net');

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

export async function postJson(path: string, fields: Record<string, string>, timeoutMs: number): Promise<NetResult> {
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
  if (!Config.hasBackend()) {
    return new NetResult(false, 0, '');
  }
  const req: http.HttpRequest = http.createHttp();
  try {
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        'apikey': Config.SUPABASE_ANON_KEY,
        'Authorization': `Bearer ${Config.SUPABASE_ANON_KEY}`
      },
      extraData: body,
      connectTimeout: timeoutMs,
      readTimeout: timeoutMs
    };
    const res: http.HttpResponse = await req.request(`${Config.BACKEND_URL}${path}`, options);
    entry.outcome = res.responseCode === 200 ? 'OK' : 'ERROR';
    await Ledger.add(entry);
    return new NetResult(res.responseCode === 200, res.responseCode, res.result as string);
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
export async function getJson(path: string, timeoutMs: number): Promise<NetResult> {
  const entry: LedgerEntry = { ts: Date.now(), endpoint: path, fields: [], bytes: 0, outcome: 'OK' };
  if (!Config.hasBackend()) {
    return new NetResult(false, 0, '');
  }
  const req: http.HttpRequest = http.createHttp();
  try {
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      header: {
        'apikey': Config.SUPABASE_ANON_KEY,
        'Authorization': `Bearer ${Config.SUPABASE_ANON_KEY}`
      },
      connectTimeout: timeoutMs,
      readTimeout: timeoutMs
    };
    const res: http.HttpResponse = await req.request(`${Config.BACKEND_URL}${path}`, options);
    entry.outcome = res.responseCode === 200 ? 'OK' : 'ERROR';
    await Ledger.add(entry);
    return new NetResult(res.responseCode === 200, res.responseCode, res.result as string);
  } catch (e) {
    entry.outcome = 'ERROR';
    await Ledger.add(entry);
    log.warn(`request ${path} failed: ${JSON.stringify(e)}`);
    return new NetResult(false, 0, '');
  } finally {
    req.destroy();
  }
}
