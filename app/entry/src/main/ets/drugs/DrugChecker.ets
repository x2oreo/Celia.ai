// Deterministic QT-risk lookup over the bundled dataset (drugs/DrugDataset.ets). Works fully offline.
// Contract: docs/ARCHITECTURE.md. Unknown input must return UNKNOWN_DRUG, never "safe".
// Safety rules:
//   - every token is resolved; the worst risk found wins (a risky drug is never hidden by a harmless one);
//   - NOT_LISTED only when every drug token is recognised - any unrecognised token makes it UNKNOWN_DRUG;
//   - typo matching only for long words and only when exactly one ingredient is that close.

import { ComboVerdict, DrugVerdict, LookupStep, LookupStepKind, RiskLevel } from '../model/DrugVerdict';
import { Medication } from '../model/Medication';
import { DATA_SOURCE, DRUGS, DrugEntry } from './DrugDataset';

// Dose, packaging, salt and filler words that are not drug names ("Klacid 500 mg film-coated tablets").
const NOISE_TOKENS: string[] = [
  'mg', 'g', 'mcg', 'ug', 'ml', 'iu', 'j', 'x', 'tab', 'tabs', 'tablet', 'tablets', 'capsule', 'capsules', 'caps',
  'film', 'coated', 'syrup', 'drops', 'oral', 'solution', 'suspension', 'injection', 'cream', 'gel', 'spray',
  'inhaler', 'powder', 'sachet', 'forte', 'mite', 'retard', 'max', 'junior', 'plus', 'duo', 'rapid', 'express',
  'sr', 'xr', 'xl', 'er', 'cr', 'mr', 'od', 'and', 'with', 'or', 'the', 'of', 'for', 'juice', 'acid', 'hydrochloride', 'hcl',
  'sodium', 'calcium', 'maleate', 'succinate', 'tartrate', 'mesylate', 'besylate', 'fumarate', 'citrate', 'sulfate',
  'sulphate', 'phosphate', 'hydrobromide', 'dihydrate', 'monohydrate', 'trihydrate',
  // Polish
  'tabletki', 'tabletka', 'tabl', 'powlekane', 'kapsułki', 'kaps', 'syrop', 'krople', 'zawiesina', 'roztwór',
  'kwas', 'chlorowodorek', 'i', 'z', 'oraz',
  // Bulgarian
  'мг', 'мл', 'таблетки', 'таблетка', 'филмирани', 'капсули', 'сироп', 'капки', 'разтвор', 'суспензия', 'и', 'с'
];

const SEVERITY_KNOWN: number = 4;

// Higher = worse. UNKNOWN_DRUG ranks above NOT_LISTED so an unknown token can never be reported as not listed.
export function severity(risk: RiskLevel): number {
  switch (risk) {
    case 'KNOWN_RISK':
      return SEVERITY_KNOWN;
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

export function tokenize(query: string): string[] {
  return query.toLowerCase()
    .split(/[^a-zÀ-ɏЀ-ӿ]+/)
    .filter((t: string) => t.length > 1 && !NOISE_TOKENS.includes(t));
}

// Classic two-row Levenshtein distance; stops early when the distance exceeds `max`.
export function editDistance(a: string, b: string, max: number): number {
  if (Math.abs(a.length - b.length) > max) {
    return max + 1;
  }
  let prev: number[] = [];
  for (let j = 0; j <= b.length; j++) {
    prev.push(j);
  }
  for (let i = 1; i <= a.length; i++) {
    const cur: number[] = [i];
    let rowMin: number = i;
    for (let j = 1; j <= b.length; j++) {
      const cost: number = a.charAt(i - 1) === b.charAt(j - 1) ? 0 : 1;
      const v: number = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost);
      cur.push(v);
      rowMin = Math.min(rowMin, v);
    }
    if (rowMin > max) {
      return max + 1;
    }
    prev = cur;
  }
  return prev[b.length];
}

function typoBudget(token: string): number {
  if (token.length >= 9) {
    return 2;
  }
  return token.length >= 6 ? 1 : 0;
}

// QT-prolonging per the QT lists. Drugs that are only on the "avoid in congenital LQTS" list are not counted.
export function isQtDrug(e: DrugEntry): boolean {
  if (e.risk === 'NOT_LISTED') {
    return false;
  }
  return !(e.avoidCongenital && e.risk === 'CONDITIONAL_RISK');
}

export function reasonFor(e: DrugEntry): string {
  let base: string;
  if (e.avoidCongenital && e.risk === 'CONDITIONAL_RISK') {
    base = `${e.drugClass}. Not a QT-prolonging drug, but on the list of drugs to avoid in congenital long QT ` +
      `(adrenergic stimulant - can trigger arrhythmias).`;
    return base;
  }
  switch (e.risk) {
    case 'KNOWN_RISK':
      base = `${e.drugClass}. Prolongs the QT interval with a known risk of torsades de pointes.`;
      break;
    case 'POSSIBLE_RISK':
      base = `${e.drugClass}. Can prolong the QT interval; risk of torsades not established.`;
      break;
    case 'CONDITIONAL_RISK':
      base = `${e.drugClass}. Risk of torsades under certain conditions - high dose, low potassium or ` +
        `magnesium, or together with other QT drugs.`;
      break;
    default:
      base = `${e.drugClass}. Not on the QT-risk lists.`;
      break;
  }
  if (e.avoidCongenital) {
    base += ' Also on the list of drugs to avoid in congenital long QT.';
  }
  return base;
}

class Match {
  entry: DrugEntry | undefined;
  kind: LookupStepKind;
  confidence: number;
  detail: string;

  constructor(entry: DrugEntry | undefined, kind: LookupStepKind, confidence: number, detail: string) {
    this.entry = entry;
    this.kind = kind;
    this.confidence = confidence;
    this.detail = detail;
  }
}

export class DrugChecker {
  private static instance: DrugChecker | undefined = undefined;

  private byIngredient: Map<string, DrugEntry> = new Map<string, DrugEntry>();
  private byAlias: Map<string, DrugEntry> = new Map<string, DrugEntry>();
  private allKeys: string[] = [];

  static get(): DrugChecker {
    if (DrugChecker.instance === undefined) {
      DrugChecker.instance = new DrugChecker(DRUGS);
    }
    return DrugChecker.instance;
  }

  constructor(entries: DrugEntry[]) {
    for (const e of entries) {
      this.byIngredient.set(e.ingredient, e);
      this.allKeys.push(e.ingredient);
      for (const a of e.aliases) {
        this.byAlias.set(a, e);
        this.allKeys.push(a);
      }
    }
  }

  entry(ingredient: string): DrugEntry | undefined {
    return this.byIngredient.get(ingredient.toLowerCase());
  }

  // Resolve a single name (generic, brand, other language, small typo) to a dataset entry.
  resolve(name: string): DrugEntry | undefined {
    const tokens: string[] = tokenize(name);
    for (const t of tokens) {
      const m: Match = this.matchToken(t);
      if (m.entry !== undefined) {
        return m.entry;
      }
    }
    return undefined;
  }

  // Autocomplete for "add a medicine": ingredients and brands starting with the prefix.
  suggest(prefix: string, limit: number): DrugEntry[] {
    const p: string = prefix.trim().toLowerCase();
    const out: DrugEntry[] = [];
    if (p.length < 2) {
      return out;
    }
    for (const key of this.allKeys) {
      if (key.startsWith(p)) {
        const e: DrugEntry | undefined = this.byIngredient.get(key) ?? this.byAlias.get(key);
        if (e !== undefined && !out.includes(e)) {
          out.push(e);
          if (out.length >= limit) {
            break;
          }
        }
      }
    }
    return out;
  }

  async check(query: string): Promise<DrugVerdict> {
    return this.checkSync(query);
  }

  checkSync(query: string): DrugVerdict {
    const tokens: string[] = tokenize(query);
    const trace: LookupStep[] = [];
    let worst: DrugEntry | undefined = undefined;
    let anyUnknown: boolean = false;
    let confidence: number = 1;
    const seen: string[] = [];

    for (const token of tokens) {
      const m: Match = this.matchToken(token);
      const step: LookupStep = { kind: m.kind, token: token, detail: m.detail };
      trace.push(step);
      if (m.entry === undefined) {
        anyUnknown = true;
        continue;
      }
      confidence = Math.min(confidence, m.confidence);
      if (seen.includes(m.entry.ingredient)) {
        continue;
      }
      seen.push(m.entry.ingredient);
      if (worst === undefined || severity(m.entry.risk) > severity(worst.risk)) {
        worst = m.entry;
      }
    }

    if (worst === undefined || (anyUnknown && severity(worst.risk) < severity('UNKNOWN_DRUG'))) {
      const reason: string = worst === undefined
        ? 'We could not recognise this medicine. Treat it as unchecked and ask your pharmacist.'
        : 'Part of this medicine was not recognised, so we cannot say it is safe. Ask your pharmacist.';
      const unknown: DrugVerdict = {
        query: query,
        ingredient: '',
        risk: 'UNKNOWN_DRUG',
        reason: reason,
        source: DATA_SOURCE,
        confidence: 0,
        trace: trace,
        alternatives: []
      };
      return unknown;
    }

    const v: DrugVerdict = {
      query: query,
      ingredient: worst.ingredient,
      risk: worst.risk,
      reason: reasonFor(worst),
      source: DATA_SOURCE,
      confidence: confidence,
      trace: trace,
      alternatives: worst.risk === 'NOT_LISTED' ? [] : worst.alternatives.slice()
    };
    return v;
  }

  // Every interaction of the checked medicine with the user's current medicines (F-19). Deterministic.
  // At most one finding per current medicine, enzyme interactions first.
  checkCombos(verdict: DrugVerdict, meds: Medication[]): ComboVerdict[] {
    if (verdict.ingredient === '') {
      return [];
    }
    const checked: DrugEntry | undefined = this.entry(verdict.ingredient);
    // A medicine resolved online is not in the dataset: no enzyme data, but its QT category still adds up.
    const checkedQt: boolean = checked !== undefined ? isQtDrug(checked) :
      (verdict.risk === 'KNOWN_RISK' || verdict.risk === 'POSSIBLE_RISK' || verdict.risk === 'CONDITIONAL_RISK');
    const cyp: ComboVerdict[] = [];
    const additive: ComboVerdict[] = [];
    const seen: string[] = [];
    for (const med of meds) {
      const other: DrugEntry | undefined = this.entry(med.ingredient) ?? this.resolve(med.name);
      if (other === undefined || other.ingredient === verdict.ingredient || seen.includes(other.ingredient)) {
        continue;
      }
      seen.push(other.ingredient);
      const enzyme: ComboVerdict | undefined = checked !== undefined ? this.cypInteraction(checked, other) : undefined;
      if (enzyme !== undefined) {
        cyp.push(enzyme);
      } else if (checkedQt && isQtDrug(other)) {
        const combo: ComboVerdict = {
          kind: 'ADDITIVE_QT',
          drugs: [verdict.ingredient, other.ingredient],
          enzyme: '',
          reason: `You already take ${other.ingredient}, which also affects the QT interval. ` +
            `Two QT drugs together add up the risk.`
        };
        additive.push(combo);
      }
    }
    return cyp.concat(additive);
  }

  // The most important interaction (an enzyme one if there is any), or NONE.
  checkCombo(verdict: DrugVerdict, meds: Medication[]): ComboVerdict {
    const all: ComboVerdict[] = this.checkCombos(verdict, meds);
    if (all.length > 0) {
      return all[0];
    }
    const none: ComboVerdict = { kind: 'NONE', drugs: [], enzyme: '', reason: '' };
    return none;
  }

  private cypInteraction(a: DrugEntry, b: DrugEntry): ComboVerdict | undefined {
    // a blocks the enzyme that clears QT drug b, or the other way round.
    const pairs: DrugEntry[][] = [[a, b], [b, a]];
    for (const pair of pairs) {
      const inhibitor: DrugEntry = pair[0];
      const substrate: DrugEntry = pair[1];
      if (!isQtDrug(substrate)) {
        continue;
      }
      for (const enzyme of inhibitor.cypInhibitor) {
        if (substrate.cypSubstrate.includes(enzyme)) {
          const combo: ComboVerdict = {
            kind: 'CYP_INTERACTION',
            drugs: [a.ingredient, b.ingredient],
            enzyme: enzyme,
            reason: `${inhibitor.ingredient} slows down how your body clears ${substrate.ingredient} ` +
              `(${enzyme}). Its level - and the QT risk - can rise.`
          };
          return combo;
        }
      }
    }
    return undefined;
  }

  private matchToken(token: string): Match {
    const exact: DrugEntry | undefined = this.byIngredient.get(token);
    if (exact !== undefined) {
      return new Match(exact, 'EXACT', 1, `${token} - generic name`);
    }
    const alias: DrugEntry | undefined = this.byAlias.get(token);
    if (alias !== undefined) {
      return new Match(alias, 'ALIAS', 0.95, `${token} → ${alias.ingredient}`);
    }
    const budget: number = typoBudget(token);
    if (budget > 0) {
      let best: DrugEntry | undefined = undefined;
      let bestDist: number = budget + 1;
      let ambiguous: boolean = false;
      for (const key of this.allKeys) {
        const dist: number = editDistance(token, key, budget);
        if (dist > budget) {
          continue;
        }
        const e: DrugEntry | undefined = this.byIngredient.get(key) ?? this.byAlias.get(key);
        if (e === undefined) {
          continue;
        }
        if (dist < bestDist) {
          best = e;
          bestDist = dist;
          ambiguous = false;
        } else if (dist === bestDist && best !== undefined && best.ingredient !== e.ingredient) {
          ambiguous = true;
        }
      }
      if (best !== undefined && !ambiguous) {
        return new Match(best, 'TYPO', bestDist === 1 ? 0.75 : 0.6,
          `${token} looks like ${best.ingredient} (spelling corrected)`);
      }
    }
    return new Match(undefined, 'NOT_FOUND', 0, `${token} - not in our list`);
  }
}
