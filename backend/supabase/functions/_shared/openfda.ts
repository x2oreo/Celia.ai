// openFDA drug labels (api.fda.gov, public domain, no key needed below 240 req/min). No AI.
// Returns up to 5 labels for one ingredient; labelRisk.ts decides the QT risk from their text.

import type { FdaLabel } from './labelRisk.ts';

const TIMEOUT_MS = 5000;   // full labels are large; 5 of them take ~1-2 s

export async function labelsFor(ingredient: string): Promise<FdaLabel[] | null> {
  const key = Deno.env.get('OPENFDA_API_KEY');
  const q = `openfda.generic_name:"${ingredient.replace(/"/g, '')}"`;
  const url = `https://api.fda.gov/drug/label.json?search=${encodeURIComponent(q)}&limit=5` +
    (key ? `&api_key=${key}` : '');
  try {
    let res = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT_MS) });
    if (res.status === 429) {
      // Burst limit without an API key: one short retry, then give up (the caller stays UNKNOWN, nothing cached).
      await new Promise((r) => setTimeout(r, 600));
      res = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT_MS) });
    }
    if (res.status === 404) {
      return [];   // openFDA answers 404 when nothing matches
    }
    if (!res.ok) {
      return null;   // outage / rate limit: caller must not cache this
    }
    const body = await res.json() as { results?: FdaLabel[] };
    return body.results ?? [];
  } catch {
    return null;
  }
}
