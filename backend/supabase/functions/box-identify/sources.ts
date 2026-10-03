// Deterministic barcode → product sources for /box-identify. No AI. Each source has its own short timeout and
// returns null on a miss or error; index.ts runs them in parallel. Parsers are pure and tested (sources.test.ts).

import { spanishCn } from '../_shared/gtin.ts';

export type HitMethod = 'REGISTRY' | 'PRODUCT_DB';

export interface RawHit {
  brand: string;
  ingredients: string[];       // as printed by the source (any language); '' entries removed
  english: boolean;            // ingredient names are English/US INNs (RxNav can resolve them directly)
  strength: string;
  form: string;
  method: HitMethod;
  source: string;              // human-readable source name
  sourceUrl: string;
  rank: number;                // lower = more trusted
}

const TIMEOUT_MS = 2500;

async function getJson<T>(url: string): Promise<T | null> {
  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT_MS) });
    return res.ok ? (await res.json()) as T : null;
  } catch {
    return null;
  }
}

const STRENGTH = /\d+(?:[.,]\d+)?\s?(?:mg|g|mcg|µg|ug|ml|%|iu|ui|j\.m\.)(?:\s?\/\s?\d*\s?\w+)?/i;

export function strengthOf(text: string): string {
  return STRENGTH.exec(text)?.[0].replace(/\s+/g, ' ').trim() ?? '';
}

// "ACETAMINOPHEN 500mg, Caffeine 65 mg" → ["ACETAMINOPHEN", "Caffeine"]
export function splitIngredients(text: string): string[] {
  return text.split(/,|;|\s\+\s|\sand\s|\sy\s|\/|\sи\s/i)
    .map((s) => s.replace(/\(.*?\)/g, '').replace(/\d.*$/, '').trim())
    .filter((s) => s.length > 2)
    .slice(0, 6);
}

// ---- openFDA drug label by barcode (US products; the label lists the barcode under openfda.upc) ----

interface FdaLabelHit {
  results?: Array<{ set_id?: string; openfda?: { brand_name?: string[]; substance_name?: string[];
    generic_name?: string[]; route?: string[] } }>;
}

export function parseFdaUpc(body: FdaLabelHit | null): RawHit | null {
  const r = body?.results?.[0];
  const o = r?.openfda;
  const brand = o?.brand_name?.[0] ?? '';
  const ingredients = o?.substance_name ?? splitIngredients(o?.generic_name?.[0] ?? '');
  if (!brand || ingredients.length === 0) {
    return null;
  }
  return {
    brand, ingredients, english: true, strength: '', form: (o?.route?.[0] ?? '').toLowerCase(), method: 'REGISTRY',
    source: 'FDA drug label (openFDA)', sourceUrl: `https://dailymed.nlm.nih.gov/dailymed/lookup.cfm?setid=${r?.set_id ?? ''}`,
    rank: 1,
  };
}

export async function fdaByUpc(gtin13: string): Promise<RawHit | null> {
  // openFDA stores US barcodes as 13 digits with the leading 0.
  if (!gtin13.startsWith('0')) {
    return null;
  }
  const q = encodeURIComponent(`openfda.upc:"${gtin13}"`);
  return parseFdaUpc(await getJson<FdaLabelHit>(`https://api.fda.gov/drug/label.json?search=${q}&limit=1`));
}

// ---- Spain: AEMPS CIMA register (Código Nacional inside 847000… codes) ----

interface CimaHit { resultados?: Array<{ nregistro?: string; nombre?: string; pactivos?: string }> }

export function parseCima(body: CimaHit | null): RawHit | null {
  const r = body?.resultados?.[0];
  if (!r?.nombre || !r.pactivos) {
    return null;
  }
  return {
    brand: r.nombre.split(/\s\d|,/)[0].trim(),
    ingredients: splitIngredients(r.pactivos),
    english: false,
    strength: strengthOf(r.nombre),
    form: '',
    method: 'REGISTRY',
    source: 'AEMPS CIMA (Spanish medicines register)',
    sourceUrl: `https://cima.aemps.es/cima/publico/detalle.html?nregistro=${r.nregistro ?? ''}`,
    rank: 1,
  };
}

export async function cima(gtin13: string): Promise<RawHit | null> {
  const cn = spanishCn(gtin13);
  return cn ? parseCima(await getJson<CimaHit>(`https://cima.aemps.es/cima/rest/presentaciones?cn=${cn}`)) : null;
}

// ---- UPCitemdb (free trial, global retail; strong for US/CA OTC medicines) ----

interface UpcItemHit {
  items?: Array<{ title?: string; brand?: string; description?: string; category?: string }>;
}

export function parseUpcItem(body: UpcItemHit | null, gtin13: string): RawHit | null {
  const it = body?.items?.[0];
  if (!it?.title || !/medic|drug|pharm|health/i.test(it.category ?? '')) {
    return null;   // not a medicine (or unknown): do not guess
  }
  const active = /active ingredients?:\s*([^.\n]+)/i.exec(it.description ?? '')?.[1] ?? '';
  const parts = it.title.split('/').map((s) => s.trim());
  const ingredients = splitIngredients(active || (parts.length > 1 ? parts[1] : ''));
  return {
    brand: it.brand || parts[0], ingredients, english: true, strength: strengthOf(active || it.title),
    form: parts.length > 2 ? parts[2].toLowerCase() : '', method: 'PRODUCT_DB', source: 'UPCitemdb',
    sourceUrl: `https://www.upcitemdb.com/upc/${gtin13}`, rank: 2,
  };
}

export async function upcItemDb(gtin13: string): Promise<RawHit | null> {
  return parseUpcItem(await getJson<UpcItemHit>(`https://api.upcitemdb.com/prod/trial/lookup?upc=${gtin13}`), gtin13);
}

// ---- Open Food / Products / Beauty Facts (ODbL; medicines are filed under any of the three) ----

interface OffHit { status?: number; product?: { product_name?: string; generic_name?: string; brands?: string } }

export function parseOff(body: OffHit | null, host: string, gtin13: string): RawHit | null {
  const p = body?.status === 1 ? body.product : undefined;
  const name = (p?.product_name || p?.generic_name || '').trim();
  if (!name) {
    return null;
  }
  return {
    brand: name.slice(0, 80), ingredients: [], english: false, strength: strengthOf(name), form: '',
    method: 'PRODUCT_DB', source: 'Open Food Facts', sourceUrl: `https://${host}/product/${gtin13}`, rank: 3,
  };
}

export async function openFacts(gtin13: string): Promise<RawHit | null> {
  const hosts = ['world.openfoodfacts.org', 'world.openproductsfacts.org', 'world.openbeautyfacts.org'];
  const hits = await Promise.all(hosts.map(async (h) =>
    parseOff(await getJson<OffHit>(`https://${h}/api/v2/product/${gtin13}.json?fields=product_name,generic_name,brands`),
      h, gtin13)));
  return hits.find((h) => h !== null) ?? null;
}

// Sorted by rank (most trusted first): /box-identify awaits them in this order.
export const SOURCES: Array<(gtin13: string) => Promise<RawHit | null>> = [fdaByUpc, cima, upcItemDb, openFacts];
