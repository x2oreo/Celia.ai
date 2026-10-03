// POST /functions/v1/drug-check  { "query": "Klacid 500 mg" } → DrugVerdict (docs/ARCHITECTURE.md).
// Deterministic, no AI, no personal data, no logging of queries. The app falls back to its bundled copy on any error.
//   Tier 1: exact ingredient or alias in the curated tables (CredibleMeds categories).
//   Tier 2: names tier 1 does not know → RxNav ingredients → curated list again → openFDA label QT rule (tier2.ts).
//   Multi-word names ("ascorbic acid", "Nurofen Cold & Flu") go to RxNav as one phrase before word by word.

import { createClient, type SupabaseClient } from 'jsr:@supabase/supabase-js@2';
import { normaliseToIngredients } from '../_shared/rxnav.ts';
import { labelsFor } from '../_shared/openfda.ts';
import { type CachedLabel, checkQuery, type CuratedRow, type Finding, SEVERITY, type Tier2Deps } from './tier2.ts';

const LIST_SOURCE = 'CredibleMeds QTdrugs categories (crediblemeds.org), curated demo subset';
const LABEL_SOURCE = 'FDA drug label (openFDA)';
const CACHE_DAYS = 30;
// The app waits 5 s (Config.DRUG_CHECK_TIMEOUT_MS). Past this budget we answer UNKNOWN in time and let the lookup
// finish in the background, so its label_cache row makes the next check of that name fast.
const BUDGET_MS = 4300;
declare const EdgeRuntime: { waitUntil(p: Promise<unknown>): void } | undefined;

function tier2Deps(read: SupabaseClient, write: SupabaseClient): Tier2Deps {
  return {
    normalise: normaliseToIngredients,
    curated: (ingredient) => lookupCurated(read, ingredient),
    cacheGet: async (ingredient) => {
      const since = new Date(Date.now() - CACHE_DAYS * 86_400_000).toISOString();
      const row = await read.from('label_cache').select('risk, section, snippet, set_id')
        .eq('ingredient', ingredient).gte('fetched_at', since).maybeSingle();
      return (row.data as CachedLabel | null) ?? null;
    },
    cachePut: async (ingredient, v) => {
      await write.from('label_cache').upsert({ ingredient, ...v, fetched_at: new Date().toISOString() });
    },
    labels: labelsFor,
  };
}

// Curated row for a name, via the alias table first. Also used by tier 2, because RxNav returns US names
// ("acetaminophen", "albuterol") that the list stores as aliases of paracetamol / salbutamol.
async function lookupCurated(read: SupabaseClient, name: string): Promise<CuratedRow | null> {
  const alias = await read.from('drug_aliases').select('ingredient').eq('alias', name).maybeSingle();
  const ingredient = alias.data ? alias.data.ingredient as string : name;
  const row = await read.from('drugs').select('ingredient, risk, drug_class').eq('ingredient', ingredient)
    .maybeSingle();
  return (row.data as CuratedRow | null) ?? null;
}

async function tier1(read: SupabaseClient, token: string): Promise<Finding | null> {
  const row = await lookupCurated(read, token);
  return row
    ? { ingredient: row.ingredient, risk: row.risk as Finding['risk'], method: 'LIST', reason: row.drug_class,
      snippet: '', setId: '' }
    : null;
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }
  let query = '';
  try {
    const body = await req.json();
    query = String(body.query ?? '').slice(0, 200);
  } catch {
    return new Response('Bad request', { status: 400 });
  }
  const url = Deno.env.get('SUPABASE_URL')!;
  // Hosted functions get SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY injected; the local dev backend's .env names
  // them SUPABASE_PUBLISHABLE_KEY / SUPABASE_SECRET_KEY.
  const read = createClient(url, Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ?? '');
  const write = createClient(url,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SECRET_KEY') ?? '');
  const deps = tier2Deps(read, write);

  const work = checkQuery(query, (word) => tier1(read, word), deps);
  const budget = new Promise<null>((resolve) => setTimeout(() => resolve(null), BUDGET_MS));
  const findings = (await Promise.race([work, budget])) ?? [];
  if (findings.length === 0 && typeof EdgeRuntime !== 'undefined') {
    EdgeRuntime.waitUntil(work.catch(() => undefined));
  }
  const known = findings.filter((f) => f.risk !== 'UNKNOWN_DRUG');
  const worst = known.reduce<Finding | null>((a, b) => !a || SEVERITY[b.risk] > SEVERITY[a.risk] ? b : a, null);
  // Same rule as the app: an unrecognised word wins over anything milder than "unknown".
  const unknown = !worst || (known.length < findings.length && SEVERITY[worst.risk] < SEVERITY.UNKNOWN_DRUG);

  const verdict = unknown
    ? { query, ingredient: '', risk: 'UNKNOWN_DRUG', reason: 'Not recognised. Ask your pharmacist.',
      source: LIST_SOURCE, method: 'NONE', confidence: 0, snippet: '' }
    : {
      query,
      ingredient: worst!.ingredient,
      risk: worst!.risk,
      reason: worst!.reason,
      source: worst!.method === 'FDA_LABEL' ? `${LABEL_SOURCE}, set_id ${worst!.setId}` : LIST_SOURCE,
      method: worst!.method,
      // Curated list = 1.0; a label warning = 0.8; "label has no QT warning" = 0.6 (absence is weak evidence).
      confidence: worst!.method === 'LIST' ? 1 : worst!.risk === 'NOT_LISTED' ? 0.6 : 0.8,
      snippet: worst!.snippet,
    };
  return new Response(JSON.stringify(verdict), { headers: { 'Content-Type': 'application/json' } });
});
