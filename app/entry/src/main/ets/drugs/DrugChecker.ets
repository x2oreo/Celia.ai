// OWNER: Mark — STUB. Replace with the real lookup over rawfile/drugs.json (offline) + /drug-check (online).
// Contract: docs/ARCHITECTURE.md. Unknown input must return UNKNOWN_DRUG, never "safe".
// Safety rules the real implementation must keep:
//   - every token is resolved; the worst risk found wins (a risky drug is never hidden by a harmless one);
//   - NOT_LISTED only when every drug token is recognised — any unrecognised token makes it UNKNOWN_DRUG.

import { DrugVerdict, RiskLevel } from '../model/DrugVerdict';

const STUB_SOURCE: string = 'Stub data — not medical advice';

interface StubEntry {
  ingredient: string;
  risk: RiskLevel;
  reason: string;
}

const STUB_ENTRIES: StubEntry[] = [
  { ingredient: 'clarithromycin', risk: 'KNOWN_RISK', reason: 'Stub: macrolide antibiotic, known risk of torsades.' },
  { ingredient: 'paracetamol', risk: 'NOT_LISTED', reason: 'Stub: not on the QT-risk list.' }
];

// Dose and packaging words that are not drug names ("Klacid 500 mg tablets").
const NOISE_TOKENS: string[] = ['mg', 'g', 'mcg', 'ml', 'iu', 'tab', 'tabs', 'tablet', 'tablets', 'capsule',
  'capsules', 'and', 'with', 'plus'];

// Higher = worse. UNKNOWN_DRUG ranks above NOT_LISTED so an unknown token can never be reported as not listed.
function severity(risk: RiskLevel): number {
  switch (risk) {
    case 'KNOWN_RISK':
      return 4;
    case 'POSSIBLE_RISK':
      return 3;
    case 'CONDITIONAL_RISK':
      return 2;
    case 'UNKNOWN_DRUG':
      return 1;
    default:
      return 0;
  }
}

function verdict(query: string, ingredient: string, risk: RiskLevel, reason: string): DrugVerdict {
  const v: DrugVerdict = {
    query: query,
    ingredient: ingredient,
    risk: risk,
    reason: reason,
    source: STUB_SOURCE
  };
  return v;
}

function drugTokens(query: string): string[] {
  return query.toLowerCase()
    .split(/[^a-z]+/)
    .filter((t: string) => t.length > 0 && !NOISE_TOKENS.includes(t));
}

export class DrugChecker {
  private static instance: DrugChecker | undefined = undefined;

  static get(): DrugChecker {
    if (DrugChecker.instance === undefined) {
      DrugChecker.instance = new DrugChecker();
    }
    return DrugChecker.instance;
  }

  async check(query: string): Promise<DrugVerdict> {
    const tokens: string[] = drugTokens(query);
    let worst: DrugVerdict | undefined = undefined;
    for (const token of tokens) {
      const entry: StubEntry | undefined = STUB_ENTRIES.find((e: StubEntry) => e.ingredient === token);
      const current: DrugVerdict = entry === undefined
        ? verdict(query, '', 'UNKNOWN_DRUG', 'Stub: drug not recognised.')
        : verdict(query, entry.ingredient, entry.risk, entry.reason);
      if (worst === undefined || severity(current.risk) > severity(worst.risk)) {
        worst = current;
      }
    }
    return worst ?? verdict(query, '', 'UNKNOWN_DRUG', 'Stub: drug not recognised.');
  }
}
