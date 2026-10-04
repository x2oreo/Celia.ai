// `share` Edge Function: stores and serves end-to-end encrypted shares (emergency card, doctor report).
//
//   POST   { kind, ciphertext }      → { id, revokeToken, expiresAt }   (app key required; reports expire after 48 h)
//   GET    ?id=<id>                  → { kind, ciphertext, expiresAt }  (viewer page in any browser; CORS *)
//   POST   { action:'revoke', id, revokeToken } → { revoked: true }   (app key + revoke token required)
//   DELETE { id, revokeToken }       → same as the revoke POST (kept for older apps; HarmonyOS http may put a
//                                      DELETE body into the URL, so the app revokes with POST first)
// Creates are rate-limited per client address (per isolate): 30 per 10 minutes.
//
// Ciphertext only: the AES key is in the link's #fragment and never reaches this server. Blobs live in a private
// Storage bucket (`shares`, folders card/ and report/) that only this function can read with the service key.
// Deploy with --no-verify-jwt: the viewer is an anonymous browser, so reading is guarded by the unguessable id + the
// key in the link; writing checks the project's client key itself (isAllowedKey). Expired reports are swept on
// every create.
import {
  base64url, clientIp, expiryFor, isAllowedKey, RateLimiter, isExpired, isShareId, newShareId, objectPath, parseCreate, REPORT_TTL_MS,
  sameHash, sha256Hex, type ShareKind, staleReports, type StoredObject, type StoredShare,
} from './logic.ts';

const BUCKET = 'shares';
const createLimit = new RateLimiter(30, 10 * 60 * 1000);
const CORS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  });
}

function env(name: string): string {
  return Deno.env.get(name) ?? '';
}

// Platform: SUPABASE_SERVICE_ROLE_KEY (or the new SUPABASE_SECRET_KEYS). Local dev: SUPABASE_SECRET_KEY from .env.
function serviceKey(): string {
  const direct = env('SUPABASE_SECRET_KEY') || env('SUPABASE_SERVICE_ROLE_KEY');
  if (direct !== '') {
    return direct;
  }
  try {
    return (JSON.parse(env('SUPABASE_SECRET_KEYS')) as Record<string, string>)['default'] ?? '';
  } catch {
    return '';
  }
}

function storageHeaders(contentType?: string): Record<string, string> {
  const key = serviceKey();
  const h: Record<string, string> = { apikey: key };
  if (!key.startsWith('sb_')) {
    h['Authorization'] = `Bearer ${key}`; // legacy JWT keys also need the bearer header
  }
  if (contentType) {
    h['Content-Type'] = contentType;
  }
  return h;
}

function objectUrl(path: string): string {
  return `${env('SUPABASE_URL')}/storage/v1/object/${BUCKET}/${path}`;
}

// The project's public client keys (legacy anon JWT + publishable keys). Platform env, or .env in local dev.
function allowedKeys(): string[] {
  const keys: string[] = [env('SUPABASE_ANON_KEY'), env('SUPABASE_PUBLISHABLE_KEY')];
  try {
    for (const v of Object.values(JSON.parse(env('SUPABASE_PUBLISHABLE_KEYS') || '{}') as Record<string, string>)) {
      keys.push(v);
    }
  } catch {
    // not set
  }
  return keys.filter((k) => k !== '');
}

function presentedKeys(req: Request): string[] {
  const bearer = (req.headers.get('authorization') ?? '').replace(/^Bearer\s+/i, '');
  return [req.headers.get('apikey') ?? '', bearer];
}

// Fails closed: without configured client keys nobody may write.
function writeDenied(req: Request): Response | undefined {
  const allowed = allowedKeys();
  if (allowed.length === 0) {
    return json(503, { error: 'keys not configured' });
  }
  return isAllowedKey(presentedKeys(req), allowed) ? undefined : json(401, { error: 'app key required' });
}

function reportTtlMs(): number {
  const ttlMinutes = Number(env('SHARE_REPORT_TTL_MINUTES')); // dev/test override only
  return ttlMinutes > 0 ? ttlMinutes * 60_000 : REPORT_TTL_MS;
}

let bucketReady = false;

async function ensureBucket(): Promise<void> {
  if (bucketReady) {
    return;
  }
  const res = await fetch(`${env('SUPABASE_URL')}/storage/v1/bucket`, {
    method: 'POST',
    headers: storageHeaders('application/json'),
    body: JSON.stringify({ id: BUCKET, name: BUCKET, public: false, file_size_limit: 262144 }),
  });
  await res.body?.cancel();
  // 200 created; 400/409 "already exists" are fine too.
  bucketReady = res.ok || res.status === 400 || res.status === 409;
}

const KINDS: ShareKind[] = ['card', 'report'];

async function readShare(id: string): Promise<StoredShare | undefined> {
  for (const kind of KINDS) {
    const res = await fetch(objectUrl(objectPath(kind, id)), { headers: storageHeaders() });
    if (res.ok) {
      return await res.json() as StoredShare;
    }
    await res.body?.cancel();
  }
  return undefined;
}

async function deletePaths(paths: string[]): Promise<void> {
  if (paths.length === 0) {
    return;
  }
  const res = await fetch(`${env('SUPABASE_URL')}/storage/v1/object/${BUCKET}`, {
    method: 'DELETE',
    headers: storageHeaders('application/json'),
    body: JSON.stringify({ prefixes: paths }),
  });
  await res.body?.cancel();
}

async function deleteShare(share: StoredShare, id: string): Promise<void> {
  await deletePaths([objectPath(share.kind, id)]);
}

// Deletes report blobs past their lifetime, oldest first, at most 100 per call.
async function sweepExpiredReports(now: number): Promise<void> {
  const res = await fetch(`${env('SUPABASE_URL')}/storage/v1/object/list/${BUCKET}`, {
    method: 'POST',
    headers: storageHeaders('application/json'),
    body: JSON.stringify({ prefix: 'report/', limit: 100, sortBy: { column: 'created_at', order: 'asc' } }),
  });
  if (!res.ok) {
    await res.body?.cancel();
    return;
  }
  const stale = staleReports(await res.json() as StoredObject[], now, reportTtlMs());
  await deletePaths(stale);
  if (stale.length > 0) {
    log({ op: 'sweep', deleted: stale.length });
  }
}

function log(event: Record<string, unknown>): void {
  // Never log ids together with timing that could link a viewer to a patient, and never the ciphertext.
  console.log(JSON.stringify({ fn: 'share', ...event }));
}

async function post(req: Request): Promise<Response> {
  const denied = writeDenied(req);
  if (denied) {
    return denied;
  }
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: 'invalid JSON' });
  }
  if (typeof body === 'object' && body !== null && (body as Record<string, unknown>).action === 'revoke') {
    return await revokeBody(body as Record<string, unknown>);
  }
  if (!createLimit.allow(clientIp(req.headers), Date.now())) {
    log({ op: 'create', limited: true });
    return json(429, { error: 'too many shares, try again later' });
  }
  return await create(body);
}

async function create(body: unknown): Promise<Response> {
  const parsed = parseCreate(body);
  if (typeof parsed === 'string') {
    return json(400, { error: parsed });
  }
  await ensureBucket();
  const now = Date.now();
  const id = newShareId((n) => crypto.getRandomValues(new Uint8Array(n)));
  const revokeToken = base64url(crypto.getRandomValues(new Uint8Array(32)));
  const share: StoredShare = {
    v: 1,
    kind: parsed.kind,
    ciphertext: parsed.ciphertext,
    createdAt: new Date(now).toISOString(),
    expiresAt: expiryFor(parsed.kind, now, reportTtlMs()),
    revokeHash: await sha256Hex(revokeToken),
  };
  const res = await fetch(objectUrl(objectPath(share.kind, id)), {
    method: 'POST',
    headers: { ...storageHeaders('application/json'), 'x-upsert': 'false' },
    body: JSON.stringify(share),
  });
  if (!res.ok) {
    log({ op: 'create', status: res.status });
    await res.body?.cancel();
    return json(502, { error: 'storage unavailable' });
  }
  await res.body?.cancel();
  log({ op: 'create', kind: share.kind, bytes: share.ciphertext.length });
  try {
    await sweepExpiredReports(now);
  } catch {
    // housekeeping only - never fail the create
  }
  return json(200, { id, revokeToken, expiresAt: share.expiresAt });
}

async function fetchShare(url: URL): Promise<Response> {
  const id = url.searchParams.get('id');
  if (!isShareId(id)) {
    return json(400, { error: 'invalid id' });
  }
  const share = await readShare(id);
  if (share === undefined) {
    return json(404, { error: 'not found' });
  }
  if (isExpired(share, Date.now())) {
    await deleteShare(share, id);
    return json(410, { error: 'expired' });
  }
  return json(200, { kind: share.kind, ciphertext: share.ciphertext, expiresAt: share.expiresAt });
}

async function revoke(req: Request): Promise<Response> {
  const denied = writeDenied(req);
  if (denied) {
    return denied;
  }
  let body: Record<string, unknown>;
  try {
    body = await req.json() as Record<string, unknown>;
  } catch {
    return json(400, { error: 'invalid JSON' });
  }
  return await revokeBody(body);
}

async function revokeBody(body: Record<string, unknown>): Promise<Response> {
  const id = typeof body.id === 'string' ? body.id : null;
  const token = typeof body.revokeToken === 'string' ? body.revokeToken : '';
  if (!isShareId(id) || token.length < 20) {
    return json(400, { error: 'invalid id or token' });
  }
  const share = await readShare(id);
  if (share === undefined) {
    return json(200, { revoked: true }); // already gone
  }
  if (!sameHash(await sha256Hex(token), share.revokeHash)) {
    return json(403, { error: 'wrong token' });
  }
  await deleteShare(share, id);
  log({ op: 'revoke', kind: share.kind });
  return json(200, { revoked: true });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS });
  }
  if (env('SUPABASE_URL') === '' || serviceKey() === '') {
    return json(503, { error: 'storage not configured' });
  }
  try {
    if (req.method === 'GET') {
      return await fetchShare(new URL(req.url));
    }
    if (req.method === 'POST') {
      return await post(req);
    }
    if (req.method === 'DELETE') {
      return await revoke(req);
    }
    return json(405, { error: 'method not allowed' });
  } catch (e) {
    log({ op: 'error', message: e instanceof Error ? e.name : 'unknown' });
    return json(502, { error: 'unavailable' });
  }
});
