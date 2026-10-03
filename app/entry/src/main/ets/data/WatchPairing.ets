// Watch ↔ phone pairing through a 6-digit code (backend/supabase/migrations/*_watch_pairing.sql). The watch shows
// the code, the user types it here, and the server returns the watch's device id plus a secret token. The device id
// replaces Config.WATCH_DEVICE_ID for every watch query, so a teammate's watch never shows up on this phone.
// Unpaired, the app keeps the shared demo id (Config.DEFAULT_WATCH_DEVICE_ID).

import { Config } from '../common/Config';
import { NetResult, postJson } from '../common/Net';
import { Logger } from '../common/Logger';
import { LocalStore, StoreTopic } from './LocalStore';
import { Profile } from '../model/Profile';
import { Listeners } from '../common/Listeners';
import { Session } from '../account/Session';

const log: Logger = new Logger('WatchPairing');

const KEY_DEVICE: string = 'watchPairDevice';
const KEY_TOKEN: string = 'watchPairToken';
const KEY_AT: string = 'watchPairAt';
const KEY_BOUND: string = 'watchPairBoundTo';   // user id the pairing is bound to on the server ('' = not bound)
const CODE_RE: RegExp = new RegExp('^\\d{6}$');
const DEVICE_RE: RegExp = new RegExp('^[A-Za-z0-9._-]{3,64}$');

export type PairOutcome = 'PAIRED' | 'INVALID_CODE' | 'RATE_LIMITED' | 'OFFLINE' | 'NO_BACKEND';

export interface PairResult {
  outcome: PairOutcome;
  deviceId: string;
}

interface ClaimRow {
  device_id?: string;
  token?: string;
  error?: string;
}

/** "482 913", "482-913" → "482913"; anything else → '' (not a code). */
export function normalizeCode(input: string): string {
  const digits: string = input.replace(new RegExp('[\\s-]', 'g'), '');
  return CODE_RE.test(digits) ? digits : '';
}

/** Parses the pairing_claim response. Pure, unit-tested. */
export function parseClaim(body: string): PairResult {
  const fail: PairResult = { outcome: 'INVALID_CODE', deviceId: '' };
  try {
    const r: ClaimRow = JSON.parse(body) as ClaimRow;
    if (r === null || typeof r !== 'object') {
      return fail;
    }
    if (r.error === 'RATE_LIMITED') {
      const limited: PairResult = { outcome: 'RATE_LIMITED', deviceId: '' };
      return limited;
    }
    if (typeof r.device_id === 'string' && DEVICE_RE.test(r.device_id) && typeof r.token === 'string' &&
      r.token.length >= 32) {
      const ok: PairResult = { outcome: 'PAIRED', deviceId: r.device_id };
      return ok;
    }
  } catch (e) {
    log.warn(`bad claim response: ${JSON.stringify(e)}`);
  }
  return fail;
}

/** Short form for the UI: first 8 characters of the device id. */
export function shortId(deviceId: string): string {
  return deviceId.length > 8 ? deviceId.substring(0, 8) : deviceId;
}

// Whether a paired watch's data can be read: since migration 20261004100200 only the signed-in owner can.
export type WatchAccess = 'DEMO' | 'OWNER' | 'SIGN_IN_NEEDED';

export function watchAccess(paired: boolean, signedIn: boolean): WatchAccess {
  if (!paired) {
    return 'DEMO';
  }
  return signedIn ? 'OWNER' : 'SIGN_IN_NEEDED';
}

export class WatchPairing {
  // Emits the watch id once the pairing is bound to the signed-in account (SOS contacts can then be sent).
  static readonly bound: Listeners<string> = new Listeners<string>();
  private static binding: boolean = false;

  /** Call once at launch, before the watch source starts: applies a saved pairing to Config. */
  static async load(): Promise<void> {
    const dev: string = await LocalStore.get().getSetting(KEY_DEVICE, '');
    Config.WATCH_DEVICE_ID = DEVICE_RE.test(dev) ? dev : Config.DEFAULT_WATCH_DEVICE_ID;
  }

  private static listening: boolean = false;

  /**
   * Keeps the paired watch's genotype equal to the profile's (watch_context via set_watch_genotype), so the watch
   * applies the same LQT-specific limits the phone shows. Call once at launch, after load().
   */
  static startGenotypeSync(): void {
    WatchPairing.syncGenotype();
    if (WatchPairing.listening) {
      return;
    }
    WatchPairing.listening = true;
    LocalStore.get().onChange((t: StoreTopic) => {
      if (t === 'profile') {
        WatchPairing.syncGenotype();
      }
    });
  }

  /** Sends the profile genotype to the paired watch. No-op when unpaired (the shared demo row isn't ours). */
  static async syncGenotype(): Promise<void> {
    if (!WatchPairing.isPaired() || !Config.hasWatchCloud()) {
      return;
    }
    const p: Profile | undefined = await LocalStore.get().getProfile();
    const fields: Record<string, string> = {
      'p_device_id': Config.WATCH_DEVICE_ID,
      'p_genotype': p?.genotype ?? 'UNKNOWN'
    };
    const res: NetResult = await postJson('/rest/v1/rpc/set_watch_genotype', fields, Config.DRUG_CHECK_TIMEOUT_MS);
    if (!res.ok) {
      log.warn(`set_watch_genotype HTTP ${res.status}`);
    }
  }

  static isPaired(): boolean {
    return Config.WATCH_DEVICE_ID !== Config.DEFAULT_WATCH_DEVICE_ID;
  }

  /** Epoch ms of the pairing, 0 if unpaired. */
  static async pairedAt(): Promise<number> {
    const at: number = Number(await LocalStore.get().getSetting(KEY_AT, '0'));
    return isNaN(at) ? 0 : at;
  }

  /** Claims a code shown on the watch. On success the new device id is active immediately. */
  static async claim(code: string): Promise<PairResult> {
    const c: string = normalizeCode(code);
    if (c === '') {
      const bad: PairResult = { outcome: 'INVALID_CODE', deviceId: '' };
      return bad;
    }
    if (!Config.hasWatchCloud()) {
      const none: PairResult = { outcome: 'NO_BACKEND', deviceId: '' };
      return none;
    }
    const fields: Record<string, string> = { 'p_code': c };
    const res: NetResult = await postJson('/rest/v1/rpc/pairing_claim', fields, Config.DRUG_CHECK_TIMEOUT_MS);
    if (!res.ok) {
      log.warn(`pairing_claim HTTP ${res.status}`);
      const offline: PairResult = { outcome: 'OFFLINE', deviceId: '' };
      return offline;
    }
    const r: PairResult = parseClaim(res.body);
    if (r.outcome === 'PAIRED') {
      const row: ClaimRow = JSON.parse(res.body) as ClaimRow;
      await LocalStore.get().setSetting(KEY_DEVICE, r.deviceId);
      await LocalStore.get().setSetting(KEY_TOKEN, row.token ?? '');
      await LocalStore.get().setSetting(KEY_AT, `${Date.now()}`);
      // Claimed with the user's JWT (common/Net.ets adds it on /rest/v1/), so the server bound it to this account.
      await LocalStore.get().setSetting(KEY_BOUND, Session.userId());
      Config.WATCH_DEVICE_ID = r.deviceId;
      log.info(`paired with watch ${shortId(r.deviceId)}`);
      await WatchPairing.syncGenotype();
      if (Session.isSignedIn()) {
        WatchPairing.bound.emit(r.deviceId);
      }
    }
    return r;
  }

  /** Forget the watch and go back to the shared demo id. */
  static async unpair(): Promise<void> {
    await LocalStore.get().setSetting(KEY_DEVICE, '');
    await LocalStore.get().setSetting(KEY_TOKEN, '');
    await LocalStore.get().setSetting(KEY_AT, '0');
    await LocalStore.get().setSetting(KEY_BOUND, '');
    Config.WATCH_DEVICE_ID = Config.DEFAULT_WATCH_DEVICE_ID;
  }

  /**
   * Keeps the pairing bound to the signed-in account (pairing_bind with the stored token): pairings made before
   * accounts or while signed out become readable once the user signs in. Call once at launch after load().
   */
  static startAccountBinding(): void {
    Session.onChange((signedIn: boolean) => {
      if (signedIn) {
        WatchPairing.bindToAccount();
      }
    });
    WatchPairing.bindToAccount();
  }

  static async bindToAccount(): Promise<boolean> {
    const uid: string = Session.userId();
    if (!WatchPairing.isPaired() || uid === '' || !Config.hasWatchCloud() || WatchPairing.binding) {
      return false;
    }
    const token: string = await LocalStore.get().getSetting(KEY_TOKEN, '');
    if (token === '' || await LocalStore.get().getSetting(KEY_BOUND, '') === uid) {
      return token !== '';
    }
    WatchPairing.binding = true;
    try {
      await Session.freshToken();
      const fields: Record<string, string> = { 'p_token': token };
      const res: NetResult = await postJson('/rest/v1/rpc/pairing_bind', fields, Config.DRUG_CHECK_TIMEOUT_MS);
      if (!res.ok) {
        log.warn(`pairing_bind HTTP ${res.status}`);
        return false;
      }
      const dev: string | null = JSON.parse(res.body) as string | null;
      if (dev !== Config.WATCH_DEVICE_ID) {
        log.warn('pairing_bind: this phone is no longer the paired phone');
        return false;
      }
      await LocalStore.get().setSetting(KEY_BOUND, uid);
      await WatchPairing.syncGenotype();
      WatchPairing.bound.emit(dev);
      return true;
    } catch (e) {
      log.warn(`pairing_bind failed: ${JSON.stringify(e)}`);
      return false;
    } finally {
      WatchPairing.binding = false;
    }
  }

  /**
   * Asks the server whether this phone is still the watch's paired phone (pairing a newer phone replaces it).
   * Returns true/false, or undefined when offline or unpaired. Doesn't change anything locally.
   */
  static async stillPaired(): Promise<boolean | undefined> {
    const token: string = await LocalStore.get().getSetting(KEY_TOKEN, '');
    if (token === '' || !Config.hasWatchCloud()) {
      return undefined;
    }
    // POST: the privacy ledger records field names only, so the token never shows up there (a GET URL would).
    const fields: Record<string, string> = { 'p_token': token };
    const res: NetResult = await postJson('/rest/v1/rpc/pairing_device', fields, Config.DRUG_CHECK_TIMEOUT_MS);
    if (!res.ok) {
      return undefined;
    }
    try {
      const dev: string | null = JSON.parse(res.body) as string | null;
      return dev === Config.WATCH_DEVICE_ID;
    } catch (e) {
      return undefined;
    }
  }
}
