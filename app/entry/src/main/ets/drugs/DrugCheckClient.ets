// Online path of the drug check (Supabase /drug-check). Only used when the bundled dataset does not recognise a
// medicine and a backend is configured (LocalConfig.ets). Sends only the typed medicine name; timeout 5 s;
// any failure → the offline verdict stands. Every call appears in the privacy ledger (common/Net.ets).

import { DrugVerdict, LookupStep } from '../model/DrugVerdict';
import { Config } from '../common/Config';
import { NetResult, postJson } from '../common/Net';

const VALID_RISKS: string[] = ['KNOWN_RISK', 'POSSIBLE_RISK', 'CONDITIONAL_RISK', 'NOT_LISTED', 'UNKNOWN_DRUG'];

export async function checkOnline(query: string, offline: DrugVerdict): Promise<DrugVerdict> {
  if (!Config.hasBackend()) {
    return offline;
  }
  const fields: Record<string, string> = { 'query': query };
  const res: NetResult = await postJson('/functions/v1/drug-check', fields, Config.DRUG_CHECK_TIMEOUT_MS);
  if (!res.ok) {
    return offline;
  }
  try {
    const v: DrugVerdict = JSON.parse(res.body) as DrugVerdict;
    // Validate before trusting anything from the network.
    if (!VALID_RISKS.includes(v.risk) || typeof v.ingredient !== 'string' || v.risk === 'UNKNOWN_DRUG') {
      return offline;
    }
    const step: LookupStep = { kind: 'ONLINE', token: query, detail: `${query} → ${v.ingredient} (online list)` };
    const result: DrugVerdict = {
      query: query,
      ingredient: v.ingredient,
      risk: v.risk,
      reason: `${v.reason}. Found in the online list.`,
      source: v.source,
      confidence: 0.9,
      trace: (offline.trace ?? []).concat([step]),
      alternatives: []
    };
    return result;
  } catch (e) {
    return offline;
  }
}
