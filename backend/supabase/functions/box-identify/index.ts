// POST /functions/v1/box-identify - barcode of a box the app does not know → brand + English ingredients.
// Never a safety verdict: the app runs the normal deterministic check on the ingredients after the user confirms.
//   { gtin, stage: 'fast' }  cache → every deterministic source in parallel (openFDA, CIMA, UPCitemdb, Open Facts)
//   { gtin, stage: 'deep', hint? }  AI web search (only after a fast miss; skipped without OPENAI_API_KEY)
//   { gtin, action: 'confirm', brand, ingredients[], strength }  the user said "yes, this is my box"
// → { found, candidate?, hint?, ms }. No personal data: only the barcode is sent.

import { createClient, type SupabaseClient } from 'jsr:@supabase/supabase-js@2';
import { json } from '../_shared/openai.ts';
import { gtinCountry, normaliseGtin } from '../_shared/gtin.ts';
import { normaliseToIngredients } from '../_shared/rxnav.ts';
import { type RawHit, SOURCES } from './sources.ts';
import { type Candidate, type ResolveDeps, resolveHit } from './resolve.ts';
import { AI_PROMPT_VERSION, hasAi, translateInn, webIdentify } from './ai.ts';
import { aiWrite, cleanHint, servable } from './cache.ts';
import { clientIp } from '../_shared/clientIp.ts';
import { aiRateLimit } from '../_shared/rateLimit.ts';

interface Row {
  gtin: string; brand: string; ingredients: string[]; unresolved: string[]; strength: string; form: string;
  country: string; method: Candidate['method']; source: string; source_url: string; confirmations: number;
  updated_at?: string;
}

function fromRow(r: Row, cached: boolean): Candidate {
  return { gtin: r.gtin, brand: r.brand, ingredients: r.ingredients, unresolved: r.unresolved, strength: r.strength,
    form: r.form, country: r.country, method: cached ? 'CACHE' : r.method, source: r.source, sourceUrl: r.source_url,
    confirmations: r.confirmations };
}

function toRow(c: Candidate, confirmations: number): Row {
  return { gtin: c.gtin, brand: c.brand, ingredients: c.ingredients, unresolved: c.unresolved, strength: c.strength,
    form: c.form, country: c.country, method: c.method, source: c.source, source_url: c.sourceUrl, confirmations,
    updated_at: new Date().toISOString() };
}

// Writes that must not delay the answer: Supabase keeps the worker alive for them via EdgeRuntime.waitUntil.
declare const EdgeRuntime: { waitUntil(p: Promise<unknown>): void } | undefined;
function background(p: PromiseLike<unknown>): void {
  const done = Promise.resolve(p).catch((e) => console.error(JSON.stringify({ fn: 'box-identify', bg: String(e) })));
  if (typeof EdgeRuntime !== 'undefined') EdgeRuntime.waitUntil(done);
}

const deps: ResolveDeps = { normalise: normaliseToIngredients, translate: hasAi() ? translateInn : null };

async function cached(db: SupabaseClient, gtin: string): Promise<Row | null> {
  const r = await db.from('box_cache').select('*').eq('gtin', gtin).maybeSingle();
  return (r.data as Row | null) ?? null;
}

async function fast(db: SupabaseClient, gtin: string, country: string): Promise<Response> {
  const row = await cached(db, gtin);
  if (row && servable(row, Date.now())) {
    return json(200, { found: true, candidate: fromRow(row, true) });
  }
  // Every source starts at once (each has its own 2.5 s timeout). They are awaited in trust order (SOURCES is
  // sorted by rank), so a registry hit answers as soon as it arrives instead of waiting for the slowest source.
  const pending = SOURCES.map((s) => s(gtin));
  let hint = '';
  for (const p of pending) {
    const hit: RawHit | null = await p;
    if (!hit) continue;
    hint = hint || hit.brand;
    const c = await resolveHit(hit, gtin, country, deps);
    if (c) {
      background(db.from('box_cache').upsert(toRow(c, 0)));   // deterministic source: safe to serve to everyone
      return json(200, { found: true, candidate: c });
    }
  }
  return json(200, { found: false, hint });
}

async function deep(db: SupabaseClient, gtin: string, country: string, hint: string): Promise<Response> {
  if (!hasAi()) {
    return json(200, { found: false, reason: 'NO_AI' });
  }
  const hit = await webIdentify(gtin, country, hint);
  const c = hit ? await resolveHit(hit, gtin, country, deps) : null;
  if (!c) {
    return json(200, { found: false });
  }
  const candidate: Candidate = { ...c, method: 'AI_WEB' };
  const row = await cached(db, gtin);
  const w = aiWrite(row, candidate, Date.now());
  if (w.write) {
    if (row !== null && w.confirmations === 0) {
      await db.from('box_confirmations').delete().eq('gtin', gtin);   // a different answer starts from zero votes
    }
    await db.from('box_cache').upsert(toRow(candidate, w.confirmations));   // shared only once confirmed
  }
  return json(200, { found: true, candidate, promptVersion: AI_PROMPT_VERSION });
}

// One vote per device for a proposed box. There is no user identity, so a device is a salted hash of its address:
// nothing personal is stored in clear, and one caller confirming many times still counts once.
async function voterHash(req: Request, gtin: string): Promise<string> {
  const salt = Deno.env.get('BOX_VOTE_SALT') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  const bytes = new TextEncoder().encode(`${salt}|${gtin}|${clientIp(req.headers)}`);
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', bytes));
  return Array.from(digest, (b) => b.toString(16).padStart(2, '0')).join('');
}

async function confirm(db: SupabaseClient, req: Request, gtin: string, body: Record<string, unknown>): Promise<Response> {
  const row = await cached(db, gtin);
  if (!row) {
    return json(404, { error: 'unknown box' });   // only boxes this function proposed can be confirmed
  }
  const brand = String(body.brand ?? '').trim().slice(0, 80);
  if (brand.toLowerCase() !== row.brand.toLowerCase()) {
    return json(409, { error: 'box changed' });
  }
  await db.from('box_confirmations').upsert({ gtin, voter_hash: await voterHash(req, gtin) },
    { onConflict: 'gtin,voter_hash', ignoreDuplicates: true });
  const votes = await db.from('box_confirmations').select('voter_hash', { count: 'exact', head: true }).eq('gtin', gtin);
  await db.from('box_cache').update({ confirmations: votes.count ?? row.confirmations }).eq('gtin', gtin);
  return json(200, { ok: true });
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== 'POST') return json(405, { error: 'POST only' });
  const started = Date.now();
  let body: Record<string, unknown>;
  try {
    body = await req.json() as Record<string, unknown>;
  } catch {
    return json(400, { error: 'bad json' });
  }
  const gtin = normaliseGtin(String(body.gtin ?? ''));
  if (!gtin) {
    return json(400, { error: 'invalid gtin' });
  }
  const country = gtinCountry(gtin);
  // Hosted functions get SUPABASE_SERVICE_ROLE_KEY injected; the local dev backend's .env names it SUPABASE_SECRET_KEY.
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SECRET_KEY') ?? '';
  const db = createClient(Deno.env.get('SUPABASE_URL')!, key);
  const stage = body.action === 'confirm' ? 'confirm' : body.stage === 'deep' ? 'deep' : 'fast';
  if (stage === 'deep' && hasAi()) {
    const limited = await aiRateLimit(req, { fn: 'box-deep', perCaller: 20, windowSec: 600 });
    if (limited) return limited;
  }
  const res = stage === 'confirm' ? await confirm(db, req, gtin, body)
    : stage === 'deep' ? await deep(db, gtin, country, cleanHint(body.hint))
    : await fast(db, gtin, country);
  const out = await res.json() as Record<string, unknown>;
  console.log(JSON.stringify({ fn: 'box-identify', stage, found: out.found ?? out.ok, ms: Date.now() - started }));
  return json(res.status, { ...out, ms: Date.now() - started });
});
