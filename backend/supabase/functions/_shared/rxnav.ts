// Name → active ingredient(s) via NLM RxNav (rxnav.nlm.nih.gov, free, no key). No AI.
// Brand or generic in, lower-case ingredient names out ("Lexapro" → ["escitalopram"]). Exact normalised match
// first; the fuzzy endpoint is only trusted when its top name starts with what was typed, because RxNav happily
// fuzzy-matches junk ("table" → "Table sugar").

const BASE = 'https://rxnav.nlm.nih.gov/REST';
const TIMEOUT_MS = 3000;

interface IdGroup { idGroup?: { rxnormId?: string[] } }
interface Approx { approximateGroup?: { candidate?: Array<{ rxcui: string; name?: string }> } }
// historystatus also covers brands RxNorm marked obsolete (e.g. "Zofran"), where related.json comes back empty.
interface History {
  rxcuiStatusHistory?: {
    attributes?: { name?: string; tty?: string };
    derivedConcepts?: { ingredientConcept?: Array<{ ingredientName: string }> };
  };
}

async function getJson<T>(url: string): Promise<T | null> {
  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT_MS) });
    return res.ok ? (await res.json()) as T : null;
  } catch {
    return null;
  }
}

async function exactRxcui(name: string): Promise<string | null> {
  const r = await getJson<IdGroup>(`${BASE}/rxcui.json?name=${encodeURIComponent(name)}&search=2`);
  return r?.idGroup?.rxnormId?.[0] ?? null;
}

async function fuzzyRxcui(name: string): Promise<string | null> {
  const r = await getJson<Approx>(`${BASE}/approximateTerm.json?term=${encodeURIComponent(name)}&maxEntries=5`);
  const hit = (r?.approximateGroup?.candidate ?? [])
    .find((c) => (c.name ?? '').toLowerCase().startsWith(name.toLowerCase()));
  return hit?.rxcui ?? null;
}

async function ingredientsOf(rxcui: string): Promise<string[]> {
  const r = await getJson<History>(`${BASE}/rxcui/${rxcui}/historystatus.json`);
  const h = r?.rxcuiStatusHistory;
  // An ingredient concept (tty IN) is its own answer. A salt (PIN, "sodium valproate") maps to its base ingredient
  // ("valproate"), which is what the curated list and the FDA labels use.
  if (h?.attributes?.tty === 'IN' && h.attributes.name) {
    return [h.attributes.name.toLowerCase()];
  }
  const names = (h?.derivedConcepts?.ingredientConcept ?? []).map((c) => c.ingredientName.toLowerCase());
  if (names.length === 0 && h?.attributes?.tty === 'PIN' && h.attributes.name) {
    return [h.attributes.name.toLowerCase()];
  }
  return [...new Set(names)];
}

// Per-instance memo: a warm Edge Function answers repeat names without any RxNav round trip. Only answers that
// came back from RxNav are kept (misses are not, so a network blip is retried next time).
const memo = new Map<string, string[]>();

// [] when RxNav does not know the name (or is unreachable) - the caller then stays UNKNOWN_DRUG.
export async function normaliseToIngredients(name: string): Promise<string[]> {
  const clean = name.trim().slice(0, 80);
  if (clean.length < 3) {
    return [];
  }
  const key = clean.toLowerCase();
  const hit = memo.get(key);
  if (hit) {
    return hit;
  }
  const rxcui = (await exactRxcui(clean)) ?? (await fuzzyRxcui(clean));
  const names = rxcui ? await ingredientsOf(rxcui) : [];
  if (names.length > 0) {
    if (memo.size > 2000) memo.clear();
    memo.set(key, names);
  }
  return names;
}
