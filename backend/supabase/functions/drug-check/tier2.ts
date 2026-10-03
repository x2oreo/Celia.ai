// Tier 2 of /drug-check: a name the curated list does not know → RxNav ingredients → curated list again (brand
// names RxNav knows, e.g. "Zithromax" → azithromycin) → openFDA label QT rule. Deterministic, cited, no AI.
// Dependencies are injected so the decision logic is tested without network (tier2.test.ts).

import { type LabelRisk, worstLabel, type FdaLabel } from '../_shared/labelRisk.ts';

export type Risk = LabelRisk | 'UNKNOWN_DRUG';
export type Method = 'LIST' | 'FDA_LABEL' | 'NONE';

export interface CuratedRow { ingredient: string; risk: string; drug_class: string }
export interface CachedLabel { risk: LabelRisk | 'NO_LABEL'; section: string; snippet: string; set_id: string }

export interface Tier2Deps {
  normalise(name: string): Promise<string[]>;
  curated(ingredient: string): Promise<CuratedRow | null>;
  cacheGet(ingredient: string): Promise<CachedLabel | null>;
  cachePut(ingredient: string, v: CachedLabel): Promise<void>;
  labels(ingredient: string): Promise<FdaLabel[] | null>;   // null = upstream error (do not cache)
}

export interface Finding {
  ingredient: string;
  risk: Risk;
  method: Method;
  reason: string;
  snippet: string;
  setId: string;
  named?: boolean;   // RxNav knew the name, even if no verdict could be formed (no FDA label)
}

export const SEVERITY: Record<Risk, number> = {
  KNOWN_RISK: 4, POSSIBLE_RISK: 3, CONDITIONAL_RISK: 2, UNKNOWN_DRUG: 1, NOT_LISTED: 0,
};

const SECTION_NAMES: Record<string, string> = {
  boxed_warning: 'boxed warning', warnings_and_cautions: 'warnings', warnings: 'warnings', precautions: 'precautions',
  contraindications: 'contraindications', adverse_reactions: 'side effects', drug_interactions: 'interactions',
  overdosage: 'overdose section',
};

function unknown(token: string): Finding {
  return { ingredient: token, risk: 'UNKNOWN_DRUG', method: 'NONE', reason: 'Not recognised', snippet: '', setId: '' };
}

async function labelFinding(ingredient: string, deps: Tier2Deps): Promise<Finding> {
  let v = await deps.cacheGet(ingredient);
  if (v === null) {
    const labels = await deps.labels(ingredient);
    if (labels === null) {
      return { ...unknown(ingredient), named: true };
    }
    if (labels.length === 0) {
      v = { risk: 'NO_LABEL', section: '', snippet: '', set_id: '' };
    } else {
      const w = worstLabel(labels);
      v = { risk: w.risk, section: w.section, snippet: w.snippet, set_id: w.setId };
    }
    await deps.cachePut(ingredient, v);
  }
  if (v.risk === 'NO_LABEL') {
    return { ...unknown(ingredient), named: true };
  }
  const reason = v.risk === 'NOT_LISTED'
    ? 'Not in our QT list and the FDA label has no QT warning — still ask your pharmacist'
    : `The FDA label mentions QT prolongation in its ${SECTION_NAMES[v.section] ?? v.section}`;
  return { ingredient, risk: v.risk, method: 'FDA_LABEL', reason, snippet: v.snippet, setId: v.set_id };
}

// Worst finding across every ingredient the name maps to (a combination brand is as risky as its worst part).
export async function checkByLabel(token: string, deps: Tier2Deps): Promise<Finding> {
  const ingredients = await deps.normalise(token);
  if (ingredients.length === 0) {
    return unknown(token);
  }
  const findings = await Promise.all(ingredients.map(async (ing): Promise<Finding> => {
    const row = await deps.curated(ing);
    if (row) {
      return { ingredient: row.ingredient, risk: row.risk as Risk, method: 'LIST', reason: row.drug_class,
        snippet: '', setId: '' };
    }
    return labelFinding(ing, deps);
  }));
  // Any part we cannot judge makes the whole product unknown, unless another part is already worse.
  return findings.reduce((a, b) => SEVERITY[b.risk] > SEVERITY[a.risk] ? b : a);
}

// ---- Whole query → findings ----

const NOISE = new Set(['mg', 'g', 'mcg', 'ml', 'tablet', 'tablets', 'tabletki', 'capsules', 'forte', 'film',
  'coated', 'syrup', 'drops', 'mite', 'retard', 'and', 'with', 'plus', 'мг', 'таблетки']);

function words(phrase: string): string[] {
  return phrase.toLowerCase().split(/[^a-zÀ-ɏЀ-ӿ]+/).filter((t) => t.length > 1 && !NOISE.has(t));
}

// "aspirin + ascorbic acid" → phrases ["aspirin", "ascorbic acid"]. Each phrase: curated list per word; if any
// word is unknown, the whole phrase goes to RxNav first ("ascorbic acid", "Nurofen Cold and Flu" → all its
// ingredients), and only then word by word — a lone "acid" must never be fuzzy-matched to some product.
export async function checkQuery(query: string, tier1: (word: string) => Promise<Finding | null>,
  deps: Tier2Deps): Promise<Finding[]> {
  const phrases = query.split(/\+|,|;|\s(?:and|with|i|и)\s/i).map(words).filter((w) => w.length > 0).slice(0, 6);
  const perPhrase = await Promise.all(phrases.map(async (ws): Promise<Finding[]> => {
    const listed = await Promise.all(ws.map(tier1));
    if (listed.every((f) => f !== null)) {
      return listed as Finding[];
    }
    const whole = ws.length > 1 ? await checkByLabel(ws.join(' '), deps) : null;
    // RxNav knows the phrase: its answer stands even when it is UNKNOWN (no label) — splitting "sodium valproate"
    // into "sodium" + "valproate" would check the wrong thing.
    if (whole && (whole.risk !== 'UNKNOWN_DRUG' || whole.named)) {
      return [...listed.filter((f): f is Finding => f !== null), whole];
    }
    return Promise.all(ws.map(async (w, i) => listed[i] ?? checkByLabel(w, deps)));
  }));
  return perPhrase.flat();
}
