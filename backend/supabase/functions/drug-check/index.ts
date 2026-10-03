// POST /functions/v1/drug-check  { "query": "Klacid 500 mg" } → DrugVerdict (docs/ARCHITECTURE.md).
// Deterministic: exact ingredient or alias lookup in the curated tables. No AI, no personal data, no logging of
// queries. The app falls back to its bundled copy on any error or timeout.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const SOURCE = 'CredibleMeds QTdrugs categories (crediblemeds.org), curated demo subset';
const NOISE = new Set(['mg', 'g', 'mcg', 'ml', 'tablet', 'tablets', 'tabletki', 'capsules', 'forte', 'film',
  'coated', 'syrup', 'drops', 'mite', 'retard', 'and', 'with', 'plus', 'мг', 'таблетки']);
const SEVERITY: Record<string, number> = {
  KNOWN_RISK: 4, POSSIBLE_RISK: 3, CONDITIONAL_RISK: 2, UNKNOWN_DRUG: 1, NOT_LISTED: 0,
};

interface DrugRow { ingredient: string; risk: string; drug_class: string; avoid_congenital: boolean }

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
  const tokens = query.toLowerCase().split(/[^a-zÀ-ɏЀ-ӿ]+/)
    .filter((t) => t.length > 1 && !NOISE.has(t));

  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!);
  let worst: DrugRow | null = null;
  let anyUnknown = tokens.length === 0;
  for (const token of tokens) {
    let ingredient = token;
    const alias = await supabase.from('drug_aliases').select('ingredient').eq('alias', token).maybeSingle();
    if (alias.data) {
      ingredient = alias.data.ingredient;
    }
    const row = await supabase.from('drugs').select('*').eq('ingredient', ingredient).maybeSingle();
    if (!row.data) {
      anyUnknown = true;
      continue;
    }
    if (!worst || SEVERITY[row.data.risk] > SEVERITY[worst.risk]) {
      worst = row.data as DrugRow;
    }
  }

  const unknown = !worst || (anyUnknown && SEVERITY[worst.risk] < SEVERITY.UNKNOWN_DRUG);
  const verdict = unknown
    ? { query, ingredient: '', risk: 'UNKNOWN_DRUG', reason: 'Not recognised. Ask your pharmacist.', source: SOURCE }
    : { query, ingredient: worst!.ingredient, risk: worst!.risk, reason: worst!.drug_class, source: SOURCE };
  return new Response(JSON.stringify(verdict), { headers: { 'Content-Type': 'application/json' } });
});
