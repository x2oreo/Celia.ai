// Pure parts of the `share` function: request validation, ids, tokens and expiry. Unit tested in logic.test.ts.
//
// The app encrypts the emergency card / doctor report on the phone (AES-256-GCM) and uploads only the ciphertext.
// The key stays in the link's #fragment, which browsers never send to a server - so this function, the Storage
// bucket and the viewer host can never read what is shared.

export type ShareKind = 'card' | 'report';

export interface CreateRequest {
  kind: ShareKind;
  ciphertext: string; // base64url(iv | ciphertext | tag)
}

export interface StoredShare {
  v: 1;
  kind: ShareKind;
  ciphertext: string;
  createdAt: string;
  expiresAt: string | null; // null = until revoked (emergency card)
  revokeHash: string; // sha256 hex of the revoke token; the token itself is only on the phone
}

export const MAX_CIPHERTEXT = 200_000;
export const REPORT_TTL_MS = 48 * 60 * 60 * 1000;
const B64URL = /^[A-Za-z0-9_-]+$/;
const ID = /^[A-Za-z0-9]{16}$/;
const ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

function isObj(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

/** Validates a create request. Returns the request or an error message for a 400. */
export function parseCreate(body: unknown): CreateRequest | string {
  if (!isObj(body)) {
    return 'body must be an object';
  }
  if (body.kind !== 'card' && body.kind !== 'report') {
    return 'kind must be "card" or "report"';
  }
  const ct = body.ciphertext;
  // 12-byte IV + 16-byte tag is the smallest possible payload: 28 bytes → 38 base64url chars.
  if (typeof ct !== 'string' || ct.length < 38 || ct.length > MAX_CIPHERTEXT || !B64URL.test(ct)) {
    return 'ciphertext must be base64url, 38..200000 chars';
  }
  return { kind: body.kind, ciphertext: ct };
}

export function isShareId(id: string | null): id is string {
  return id !== null && ID.test(id);
}

/** Expiry is decided by the server per kind; the app cannot ask for longer. */
export function expiryFor(kind: ShareKind, now: number, reportTtlMs: number = REPORT_TTL_MS): string | null {
  return kind === 'report' ? new Date(now + reportTtlMs).toISOString() : null;
}

export function isExpired(s: StoredShare, now: number): boolean {
  return s.expiresAt !== null && Date.parse(s.expiresAt) <= now;
}

export function newShareId(rand: (n: number) => Uint8Array): string {
  // 62^16 ≈ 4.7e28 - unguessable; rejection sampling keeps the alphabet uniform.
  let out = '';
  while (out.length < 16) {
    for (const b of rand(32)) {
      if (b < 248 && out.length < 16) {
        out += ALPHABET[b % 62];
      }
    }
  }
  return out;
}

export function base64url(bytes: Uint8Array): string {
  let bin = '';
  for (const b of bytes) {
    bin += String.fromCharCode(b);
  }
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export async function sha256Hex(text: string): Promise<string> {
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text)));
  return Array.from(digest).map((b) => b.toString(16).padStart(2, '0')).join('');
}

/** Constant-time comparison of two hex digests. */
export function sameHash(a: string, b: string): boolean {
  if (a.length !== b.length) {
    return false;
  }
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

/** Storage path of a share. Kind folders let the sweeper find expired reports without reading them. */
export function objectPath(kind: ShareKind, id: string): string {
  return `${kind}/${id}.json`;
}

/**
 * Write access (create/revoke) needs one of the project's public client keys - the app sends it. Reading stays
 * open: the unguessable id plus the key in the link's # are the access control for viewers.
 * Empty `allowed` (local dev without keys configured) allows everything.
 */
export function isAllowedKey(presented: string[], allowed: string[]): boolean {
  if (allowed.length === 0) {
    return true;
  }
  for (const p of presented) {
    for (const a of allowed) {
      if (p.length > 0 && sameHash(p, a)) {
        return true;
      }
    }
  }
  return false;
}

export interface StoredObject {
  name: string;
  created_at: string;
}

/** Report objects older than the report lifetime (they would answer 410 anyway). */
export function staleReports(items: StoredObject[], now: number, reportTtlMs: number = REPORT_TTL_MS): string[] {
  return items
    .filter((o) => o.name.endsWith('.json') && Date.parse(o.created_at) + reportTtlMs <= now)
    .map((o) => `report/${o.name}`);
}

export { clientIp } from '../_shared/clientIp.ts';

// Fixed-window counter per key. In-memory, so it limits per isolate - a speed bump against scripted uploads, not a
// quota. Pure apart from the Map it owns; `now` is passed in for tests.
export class RateLimiter {
  private hits = new Map<string, { start: number; count: number }>();
  constructor(private max: number, private windowMs: number) {}

  allow(key: string, now: number): boolean {
    const h = this.hits.get(key);
    if (h === undefined || now - h.start >= this.windowMs) {
      if (this.hits.size > 10_000) this.hits.clear();   // bounded memory
      this.hits.set(key, { start: now, count: 1 });
      return true;
    }
    h.count++;
    return h.count <= this.max;
  }
}
