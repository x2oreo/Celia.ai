// Shareable links for the emergency card and the doctor report (Supabase `share` function + Vercel viewer pages).
//
//   JSON ─► ShareCrypto.seal (random AES key) ─► POST /share {kind, ciphertext} ─► {id, revokeToken, expiresAt}
//   link = SHARE_VIEWER_URL + kind + '/#' + id + '.' + key        (the key after # never reaches a server)
//
// The link and its revoke token are kept on this phone only (LocalStore settings). Report links expire after 48 h
// (server rule); the card link lives until it is replaced or revoked.

import { Config } from '../common/Config';
import { Logger } from '../common/Logger';
import { deleteJson, getJson, NetResult, postJson, shareTarget } from '../common/Net';
import { LocalStore } from '../data/LocalStore';
import { Sealed, ShareCrypto } from './ShareCrypto';

const log: Logger = new Logger('ShareService');
const FN: string = '/functions/v1/share';
const TIMEOUT_MS: number = 10000;
const PENDING_KEY: string = 'share.pendingRevoke';   // links whose revoke hasn't been confirmed by the server yet

export type ShareKind = 'card' | 'report';

// What the phone remembers about its current link of each kind.
export interface ShareRecord {
  kind: ShareKind;
  id: string;
  key: string;
  revokeToken: string;
  expiresAt: string;     // ISO time, '' = until revoked
  contentHash: string;   // the card is re-uploaded only when its content changes
  createdAt: number;
}

interface CreateResponse {
  id: string;
  revokeToken: string;
  expiresAt: string | null;
}

interface FetchResponse {
  kind: string;
  ciphertext: string;
  expiresAt: string | null;
}

// Short, stable fingerprint of the shared JSON (not security relevant: it only avoids needless re-uploads).
export function contentHash(text: string): string {
  let h1: number = 0x811c9dc5;
  let h2: number = 0x01000193;
  for (let i = 0; i < text.length; i++) {
    const c: number = text.charCodeAt(i);
    h1 = Math.imul(h1 ^ c, 16777619) >>> 0;
    h2 = Math.imul(h2 ^ c, 2246822507) >>> 0;
  }
  return `${h1.toString(16)}${h2.toString(16)}`;
}

export function viewerUrl(kind: ShareKind, id: string, key: string): string {
  return `${Config.SHARE_VIEWER_URL}${kind}/#${id}.${key}`;
}

// A link this app made: '<viewer>/<kind>/#<id>.<key>' → [kind, id, key]; undefined for anything else.
export function parseShareLink(raw: string): string[] | undefined {
  const m: RegExpMatchArray | null = raw.trim().match(/\/(card|report)\/?#([A-Za-z0-9]{16})\.([A-Za-z0-9_-]{43})$/);
  return m === null ? undefined : [m[1], m[2], m[3]];
}

export class ShareService {
  static available(): boolean {
    return Config.SHARE_BACKEND_URL.length > 0 && Config.SHARE_ANON_KEY.length > 0 &&
      Config.SHARE_VIEWER_URL.length > 0;
  }

  static async current(kind: ShareKind): Promise<ShareRecord | undefined> {
    const raw: string = await LocalStore.get().getSetting(`share.${kind}`, '');
    if (raw === '') {
      return undefined;
    }
    try {
      const r: ShareRecord = JSON.parse(raw) as ShareRecord;
      return r.expiresAt !== '' && Date.parse(r.expiresAt) <= Date.now() ? undefined : r;
    } catch (e) {
      return undefined;
    }
  }

  static url(r: ShareRecord): string {
    return viewerUrl(r.kind, r.id, r.key);
  }

  // Uploads a new encrypted share. For the card, an unchanged card reuses its link (and a changed card replaces it).
  static async share(kind: ShareKind, json: string): Promise<ShareRecord | undefined> {
    if (!ShareService.available()) {
      return undefined;
    }
    await ShareService.retryPending();
    const hash: string = contentHash(json);
    const existing: ShareRecord | undefined = await ShareService.current(kind);
    if (kind === 'card' && existing !== undefined && existing.contentHash === hash) {
      return existing;
    }
    try {
      const sealed: Sealed = await ShareCrypto.seal(json);
      const fields: Record<string, string> = { 'kind': kind, 'ciphertext': sealed.ciphertext };
      const res: NetResult = await postJson(FN, fields, TIMEOUT_MS, shareTarget());
      if (!res.ok) {
        log.warn(`share ${kind} failed: HTTP ${res.status}`);
        return undefined;
      }
      const body: CreateResponse = JSON.parse(res.body) as CreateResponse;
      const record: ShareRecord = {
        kind: kind, id: body.id, key: sealed.key, revokeToken: body.revokeToken, expiresAt: body.expiresAt ?? '',
        contentHash: hash, createdAt: Date.now()
      };
      await LocalStore.get().setSetting(`share.${kind}`, JSON.stringify(record));
      if (existing !== undefined && !(await ShareService.revokeRecord(existing))) {
        await ShareService.addPending(existing);   // the old link must stop working: retried until confirmed
      }
      return record;
    } catch (e) {
      log.warn(`share ${kind} failed: ${JSON.stringify(e)}`);
      return undefined;
    }
  }

  // Stops the current link of this kind. The record (and its revoke token) is kept until the server confirms, so an
  // offline attempt is retried later instead of leaving the link live forever.
  static async revoke(kind: ShareKind): Promise<boolean> {
    await ShareService.retryPending();
    const raw: string = await LocalStore.get().getSetting(`share.${kind}`, '');
    if (raw === '') {
      return true;
    }
    const record: ShareRecord = JSON.parse(raw) as ShareRecord;
    await LocalStore.get().setSetting(`share.${kind}`, '');
    if (await ShareService.revokeRecord(record)) {
      return true;
    }
    await ShareService.addPending(record);
    return false;
  }

  private static async pending(): Promise<ShareRecord[]> {
    try {
      return JSON.parse(await LocalStore.get().getSetting(PENDING_KEY, '[]')) as ShareRecord[];
    } catch (e) {
      return [];
    }
  }

  private static async addPending(r: ShareRecord): Promise<void> {
    const list: ShareRecord[] = (await ShareService.pending()).filter((p: ShareRecord) => p.id !== r.id);
    list.push(r);
    await LocalStore.get().setSetting(PENDING_KEY, JSON.stringify(list));
  }

  // Retries revokes that failed earlier (offline). Expired reports need no revoke: the server drops them.
  static async retryPending(): Promise<void> {
    const list: ShareRecord[] = await ShareService.pending();
    if (list.length === 0) {
      return;
    }
    const left: ShareRecord[] = [];
    for (const r of list) {
      const expired: boolean = r.expiresAt !== '' && Date.parse(r.expiresAt) <= Date.now();
      if (!expired && !(await ShareService.revokeRecord(r))) {
        left.push(r);
      }
    }
    await LocalStore.get().setSetting(PENDING_KEY, JSON.stringify(left));
  }

  // Revoke with POST {action:'revoke'}: HarmonyOS http may move a DELETE body into the URL, which would lose the
  // token (and put it in logs). Servers deployed before that path existed treat it as a bad create (400), so the
  // DELETE is kept as a fallback for them.
  private static async revokeRecord(r: ShareRecord): Promise<boolean> {
    const post: Record<string, string> = { 'action': 'revoke', 'id': r.id, 'revokeToken': r.revokeToken };
    const res: NetResult = await postJson(FN, post, TIMEOUT_MS, shareTarget());
    if (res.ok || res.status === 403) {
      return res.ok;   // 403 = wrong token: retrying never helps
    }
    const fields: Record<string, string> = { 'id': r.id, 'revokeToken': r.revokeToken };
    const old: NetResult = await deleteJson(FN, fields, TIMEOUT_MS, shareTarget());
    return old.ok;
  }

  // Celia's own scanner: download and decrypt a shared link (undefined if gone, expired or tampered with).
  static async fetchShared(id: string, key: string): Promise<string | undefined> {
    const res: NetResult = await getJson(`${FN}?id=${id}`, TIMEOUT_MS, true, shareTarget());
    if (!res.ok) {
      return undefined;
    }
    const body: FetchResponse = JSON.parse(res.body) as FetchResponse;
    return await ShareCrypto.open(body.ciphertext, key);
  }
}
