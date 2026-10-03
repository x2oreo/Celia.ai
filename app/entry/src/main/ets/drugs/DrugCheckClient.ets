// Online path of the drug check (Supabase /drug-check). Only used when the bundled dataset does not recognise a
// medicine and a backend is configured (LocalConfig.ets). Sends only the typed medicine name; any failure → the
// offline verdict stands. Every call appears in the privacy ledger (common/Net.ets).
// The server answers from the curated list ('LIST') or, for medicines outside it, from the FDA drug label QT rule
// ('FDA_LABEL', with the quoted label sentence). Both are deterministic; nothing here comes from an LLM.

import { DrugVerdict, LookupStep, RiskLevel } from '../model/DrugVerdict';
import { Config } from '../common/Config';
import { NetResult, postJson } from '../common/Net';

const VALID_RISKS: string[] = ['KNOWN_RISK', 'POSSIBLE_RISK', 'CONDITIONAL_RISK', 'NOT_LISTED', 'UNKNOWN_DRUG'];
const SNIPPET_MAX: number = 260;

// Wire shape of /drug-check (docs/ARCHITECTURE.md). method/confidence/snippet are absent on older servers.
interface OnlineVerdict {
  ingredient?: string;
  risk?: string;
  reason?: string;
  source?: string;
  method?: string;
  confidence?: number;
  snippet?: string;
}

function str(v: string | undefined, max: number): string {
  return typeof v === 'string' ? v.slice(0, max) : '';
}

// Pure: server body → verdict, or the offline verdict when anything is missing or out of range.
export function parseOnlineVerdict(body: string, query: string, offline: DrugVerdict): DrugVerdict {
  let v: OnlineVerdict;
  try {
    v = JSON.parse(body) as OnlineVerdict;
  } catch (e) {
    return offline;
  }
  const risk: string = typeof v.risk === 'string' ? v.risk : '';
  const ingredient: string = str(v.ingredient, 80);
  if (!VALID_RISKS.includes(risk) || risk === 'UNKNOWN_DRUG' || ingredient.length === 0) {
    return offline;
  }
  const fromLabel: boolean = v.method === 'FDA_LABEL';
  const steps: LookupStep[] = [{
    kind: fromLabel ? 'LABEL' : 'ONLINE',
    token: query,
    detail: fromLabel ? `${query} → ${ingredient} (FDA drug label)` : `${query} → ${ingredient} (online list)`
  }];
  const snippet: string = str(v.snippet, SNIPPET_MAX);
  if (fromLabel && snippet.length > 0) {
    steps.push({ kind: 'LABEL', token: ingredient, detail: `Label says: “${snippet}”` });
  }
  const conf: number = typeof v.confidence === 'number' && v.confidence >= 0 && v.confidence <= 1 ?
    v.confidence : 0.9;
  const result: DrugVerdict = {
    query: query,
    ingredient: ingredient,
    risk: risk as RiskLevel,
    reason: fromLabel ? `${str(v.reason, 200)}.` : `${str(v.reason, 200)}. Found in the online list.`,
    source: str(v.source, 200),
    // Never more certain than the curated offline list, which is 1.0 for exact names.
    confidence: Math.min(conf, 0.9),
    trace: (offline.trace ?? []).concat(steps),
    alternatives: []
  };
  return result;
}

export async function checkOnline(query: string, offline: DrugVerdict): Promise<DrugVerdict> {
  if (!Config.hasBackend()) {
    return offline;
  }
  const fields: Record<string, string> = { 'query': query };
  const res: NetResult = await postJson('/functions/v1/drug-check', fields, Config.DRUG_CHECK_TIMEOUT_MS);
  return res.ok ? parseOnlineVerdict(res.body, query, offline) : offline;
}
