// Online identification of a box the phone does not know (Supabase /box-identify, any country). Only the barcode
// leaves the phone (privacy ledger via common/Net.ets). The answer only names the product and its ingredients —
// never a verdict: after the user confirms, CheckService runs the usual deterministic check on the ingredients.
// Two stages so the screen never waits on AI: 'fast' (registries and product databases, ~0.3-4 s) and, only on
// a miss, 'deep' (AI web search, up to ~25 s).

import { Config } from '../common/Config';
import { NetResult, postJson } from '../common/Net';

export type IdentifyStage = 'fast' | 'deep';

const FAST_TIMEOUT_MS: number = 6000;
const DEEP_TIMEOUT_MS: number = 28000;
const METHODS: string[] = ['CACHE', 'REGISTRY', 'PRODUCT_DB', 'AI_WEB'];

export interface BoxCandidate {
  gtin: string;
  brand: string;
  ingredients: string[];   // English INNs; names the server could not confirm are kept as printed
  unresolved: string[];
  strength: string;
  form: string;
  country: string;
  method: string;          // CACHE | REGISTRY | PRODUCT_DB | AI_WEB
  source: string;
  sourceUrl: string;
  confirmations: number;
}

export class IdentifyReply {
  candidate: BoxCandidate | undefined;
  hint: string;            // product name a database knew without ingredients — helps the web search

  constructor(candidate: BoxCandidate | undefined, hint: string) {
    this.candidate = candidate;
    this.hint = hint;
  }
}

interface WireCandidate {
  gtin?: string;
  brand?: string;
  ingredients?: string[];
  unresolved?: string[];
  strength?: string;
  form?: string;
  country?: string;
  method?: string;
  source?: string;
  sourceUrl?: string;
  confirmations?: number;
}

interface WireReply {
  found?: boolean;
  candidate?: WireCandidate;
  hint?: string;
}

function str(v: string | undefined, max: number): string {
  return typeof v === 'string' ? v.trim().slice(0, max) : '';
}

function names(v: string[] | undefined): string[] {
  if (!Array.isArray(v)) {
    return [];
  }
  return v.filter((s: string) => typeof s === 'string' && s.trim().length > 1).slice(0, 6)
    .map((s: string) => s.trim().slice(0, 60));
}

// Pure: server body → reply. Anything malformed, or a box for another barcode, counts as "not found".
export function parseIdentify(body: string, gtin: string): IdentifyReply {
  let w: WireReply;
  try {
    w = JSON.parse(body) as WireReply;
  } catch (e) {
    return new IdentifyReply(undefined, '');
  }
  const hint: string = str(w.hint, 80);
  const c: WireCandidate | undefined = w.candidate;
  if (w.found !== true || c === undefined) {
    return new IdentifyReply(undefined, hint);
  }
  const brand: string = str(c.brand, 80);
  const ingredients: string[] = names(c.ingredients);
  const method: string = str(c.method, 12);
  if (str(c.gtin, 14) !== gtin || brand.length === 0 || ingredients.length === 0 || !METHODS.includes(method)) {
    return new IdentifyReply(undefined, hint);
  }
  const unresolved: string[] = names(c.unresolved).filter((u: string) => ingredients.includes(u));
  const url: string = str(c.sourceUrl, 300);
  const candidate: BoxCandidate = {
    gtin: gtin,
    brand: brand,
    ingredients: ingredients,
    unresolved: unresolved,
    strength: str(c.strength, 30),
    form: str(c.form, 40),
    country: str(c.country, 2),
    method: method,
    source: str(c.source, 80),
    sourceUrl: url.startsWith('https://') ? url : '',
    confirmations: typeof c.confirmations === 'number' && c.confirmations >= 0 ? Math.floor(c.confirmations) : 0
  };
  return new IdentifyReply(candidate, hint);
}

export async function identifyBox(gtin: string, stage: IdentifyStage, hint: string): Promise<IdentifyReply> {
  if (!Config.hasBackend()) {
    return new IdentifyReply(undefined, '');
  }
  const fields: Record<string, string> = { 'gtin': gtin, 'stage': stage };
  if (hint.length > 0) {
    fields['hint'] = hint;
  }
  const res: NetResult = await postJson('/functions/v1/box-identify', fields,
    stage === 'fast' ? FAST_TIMEOUT_MS : DEEP_TIMEOUT_MS);
  return res.ok ? parseIdentify(res.body, gtin) : new IdentifyReply(undefined, '');
}

// "Yes, this is my box": lets the next person with this box skip the web search. Fire and forget.
export async function confirmBox(c: BoxCandidate): Promise<void> {
  if (!Config.hasBackend() || c.method === 'CACHE' || c.method === 'REGISTRY') {
    return;   // nothing to confirm: already trusted
  }
  const fields: Record<string, string> = { 'gtin': c.gtin, 'action': 'confirm', 'brand': c.brand };
  await postJson('/functions/v1/box-identify', fields, FAST_TIMEOUT_MS);
}
