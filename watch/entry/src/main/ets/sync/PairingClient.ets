import { Logger } from '../common/Logger';
import { RestClient } from './RestClient';

export type PairStatus = 'PENDING' | 'PAIRED' | 'EXPIRED' | 'NONE';

interface DeviceArgs {
  p_device_id: string;
}

interface StartResponse {
  code: string;
  expires_at: string;
}

interface StatusResponse {
  status: string;
}

export interface PairingCode {
  code: string;
  expiresAtMs: number;
}

/** `ok` false → `error` explains (shown as a toast). 404 means the pairing migration isn't applied. */
export interface RpcResult<T> {
  ok: boolean;
  value: T | undefined;
  error: string;
}

function fail<T>(error: string): RpcResult<T> {
  const r: RpcResult<T> = { ok: false, value: undefined, error: error };
  return r;
}

function ok<T>(value: T): RpcResult<T> {
  const r: RpcResult<T> = { ok: true, value: value, error: '' };
  return r;
}

/** The two pairing RPCs; `PairingClient` on the watch, a fake in tests. */
export interface PairingApi {
  start(deviceId: string): Promise<RpcResult<PairingCode>>;

  status(deviceId: string): Promise<RpcResult<PairStatus>>;
}

/** Watch ↔ phone pairing via Supabase RPCs (migration 20261003260000_watch_pairing.sql). */
export class PairingClient implements PairingApi {
  private client: RestClient;

  constructor(client: RestClient) {
    this.client = client;
  }

  /** Creates a fresh 6-digit code for this watch. */
  async start(deviceId: string): Promise<RpcResult<PairingCode>> {
    const res = await this.call('pairing_start', deviceId);
    if (!res.ok || res.value === undefined) {
      return fail<PairingCode>(res.error);
    }
    try {
      const body = JSON.parse(res.value) as StartResponse;
      const expires = Date.parse(body.expires_at);
      if (typeof body.code !== 'string' || body.code.length === 0 || isNaN(expires)) {
        return fail<PairingCode>('Unexpected pairing response');
      }
      const c: PairingCode = { code: body.code, expiresAtMs: expires };
      return ok<PairingCode>(c);
    } catch (e) {
      return fail<PairingCode>('Unexpected pairing response');
    }
  }

  async status(deviceId: string): Promise<RpcResult<PairStatus>> {
    const res = await this.call('pairing_status', deviceId);
    if (!res.ok || res.value === undefined) {
      return fail<PairStatus>(res.error);
    }
    try {
      const s = (JSON.parse(res.value) as StatusResponse).status;
      if (s === 'PENDING' || s === 'PAIRED' || s === 'EXPIRED' || s === 'NONE') {
        return ok<PairStatus>(s);
      }
      return fail<PairStatus>('Unexpected pairing status');
    } catch (e) {
      return fail<PairStatus>('Unexpected pairing status');
    }
  }

  private async call(fn: string, deviceId: string): Promise<RpcResult<string>> {
    const body: DeviceArgs = { p_device_id: deviceId };
    const resp = await this.client.post(`/rest/v1/rpc/${fn}`, JSON.stringify(body), '');
    if (resp.status === 0) {
      Logger.warn(`${fn} failed: ${resp.body}`);
      return fail<string>('No connection');
    }
    if (resp.status >= 200 && resp.status < 300) {
      return ok<string>(resp.body);
    }
    Logger.warn(`${fn} HTTP ${resp.status}: ${resp.body.slice(0, 160)}`);
    return fail<string>(resp.status === 404 ? 'Pairing not set up on the server yet' : `Server error ${resp.status}`);
  }
}

/** "482913" → "482 913". */
export function formatPairCode(code: string): string {
  return code.length === 6 ? `${code.slice(0, 3)} ${code.slice(3)}` : code;
}
