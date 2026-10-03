// Unit tests for the share function's pure logic. Run: deno test backend/supabase/functions/share/
import { assert, assertEquals } from 'jsr:@std/assert@1';
import {
  clientIp, RateLimiter,
  base64url, expiryFor, isAllowedKey, isExpired, isShareId, newShareId, objectPath, parseCreate, REPORT_TTL_MS,
  sameHash, sha256Hex, staleReports, type StoredShare,
} from './logic.ts';

const CT = 'A'.repeat(60);

Deno.test('parseCreate: accepts card and report with base64url ciphertext', () => {
  assertEquals(parseCreate({ kind: 'card', ciphertext: CT }), { kind: 'card', ciphertext: CT });
  assertEquals(parseCreate({ kind: 'report', ciphertext: CT, extra: 1 }), { kind: 'report', ciphertext: CT });
});

Deno.test('parseCreate: rejects bad kind, short, oversized or non-base64url ciphertext', () => {
  assertEquals(typeof parseCreate(null), 'string');
  assertEquals(typeof parseCreate({ kind: 'note', ciphertext: CT }), 'string');
  assertEquals(typeof parseCreate({ kind: 'card', ciphertext: 'abc' }), 'string');
  assertEquals(typeof parseCreate({ kind: 'card', ciphertext: 'A'.repeat(200_001) }), 'string');
  assertEquals(typeof parseCreate({ kind: 'card', ciphertext: CT + '+/=' }), 'string');
});

Deno.test('expiry: report expires after 48 h, card never', () => {
  const now = Date.UTC(2026, 9, 3, 12);
  assertEquals(expiryFor('card', now), null);
  assertEquals(Date.parse(expiryFor('report', now)!), now + REPORT_TTL_MS);
  const s: StoredShare = {
    v: 1, kind: 'report', ciphertext: CT, createdAt: '', expiresAt: expiryFor('report', now), revokeHash: '',
  };
  assert(!isExpired(s, now + REPORT_TTL_MS - 1));
  assert(isExpired(s, now + REPORT_TTL_MS));
  assert(!isExpired({ ...s, expiresAt: null }, now + 10 * REPORT_TTL_MS));
});

Deno.test('ids: 16 base62 chars, validated strictly', () => {
  const id = newShareId((n) => crypto.getRandomValues(new Uint8Array(n)));
  assert(isShareId(id));
  assert(!isShareId(null));
  assert(!isShareId('../etc/passwd....'));
  assert(!isShareId(id + 'x'));
});

Deno.test('tokens: base64url has no padding, hashes compare in constant time', async () => {
  assertEquals(base64url(new Uint8Array([251, 255])), '-_8');
  const h = await sha256Hex('token');
  assertEquals(h.length, 64);
  assert(sameHash(h, await sha256Hex('token')));
  assert(!sameHash(h, await sha256Hex('other')));
});

Deno.test('write access: only the project client keys, empty list = dev', () => {
  assert(isAllowedKey(['abc'], ['xyz', 'abc']));
  assert(!isAllowedKey(['abd'], ['abc']));
  assert(!isAllowedKey([''], ['abc']));
  assert(isAllowedKey([], []));
});

Deno.test('paths and sweeper: report objects older than 48 h only', () => {
  assertEquals(objectPath('card', 'AAAAAAAAAAAAAAAA'), 'card/AAAAAAAAAAAAAAAA.json');
  const now = Date.UTC(2026, 9, 3, 12);
  const old = new Date(now - REPORT_TTL_MS - 1).toISOString();
  const fresh = new Date(now - 1000).toISOString();
  assertEquals(staleReports([{ name: 'a.json', created_at: old }, { name: 'b.json', created_at: fresh },
    { name: '.emptyFolderPlaceholder', created_at: old }], now), ['report/a.json']);
});

Deno.test('clientIp: edge header first, else the last forwarded hop, never fails open', () => {
  assertEquals(clientIp(new Headers({ 'cf-connecting-ip': '1.2.3.4', 'x-forwarded-for': '9.9.9.9' })), '1.2.3.4');
  assertEquals(clientIp(new Headers({ 'x-forwarded-for': '6.6.6.6, 10.0.0.1, 5.5.5.5' })), '5.5.5.5');
  assertEquals(clientIp(new Headers()), 'unknown');
});

Deno.test('RateLimiter: allows max per window, then blocks until the window resets', () => {
  const r = new RateLimiter(2, 1000);
  assert(r.allow('a', 0));
  assert(r.allow('a', 10));
  assert(!r.allow('a', 20));
  assert(r.allow('b', 20));
  assert(r.allow('a', 1000));
});
