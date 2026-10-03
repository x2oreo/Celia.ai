// Everything we know about one of my medicines, for the medicine detail sheet, the medicines grid and reminders.
// Pure and deterministic: class, risk and interactions come from DrugDataset / DrugChecker, plain-English facts
// from DrugInfo. An AI explanation (MedInfoClient) is shown next to this, never merged into it.

import { ComboVerdict, DrugVerdict, RiskLevel } from '../model/DrugVerdict';
import { Medication } from '../model/Medication';
import { DrugChecker, reasonFor } from './DrugChecker';
import { DrugEntry } from './DrugDataset';
import { DrugInfo, drugInfo } from './DrugInfo';

const BRANDS_MAX: number = 4;

export function capitalize(s: string): string {
  return s.length > 0 ? s.charAt(0).toUpperCase() + s.slice(1) : s;
}

export class MedFacts {
  name: string = '';           // as the user saved it, capitalised
  ingredient: string = '';     // resolved INN, '' if unknown
  known: boolean = false;      // found in the dataset
  dose: string = '';
  drugClass: string = '';
  usedFor: string = '';
  howItWorks: string = '';
  tips: string[] = [];
  brands: string[] = [];       // other names it is sold under, capitalised, Latin script only
  risk: RiskLevel = 'UNKNOWN_DRUG';
  reason: string = '';
  interactions: ComboVerdict[] = [];   // with my other medicines, CYP first
  alternatives: string[] = [];
}

function entryOf(m: Medication): DrugEntry | undefined {
  return DrugChecker.get().entry(m.ingredient) ?? DrugChecker.get().resolve(m.name);
}

function latinBrands(e: DrugEntry, exclude: string): string[] {
  const out: string[] = [];
  for (const a of e.aliases) {
    if (out.length >= BRANDS_MAX) {
      break;
    }
    // Skip Cyrillic spellings and the name the user already sees.
    if (/^[a-z][a-z0-9 -]*$/.test(a) && a !== exclude) {
      out.push(capitalize(a));
    }
  }
  return out;
}

export function medFacts(m: Medication, myMeds: Medication[]): MedFacts {
  const f: MedFacts = new MedFacts();
  f.name = capitalize(m.name.trim());
  f.dose = m.dose;
  const e: DrugEntry | undefined = entryOf(m);
  if (e === undefined) {
    f.ingredient = m.ingredient;
    return f;
  }
  f.known = true;
  f.ingredient = e.ingredient;
  f.drugClass = e.drugClass;
  f.risk = e.risk;
  f.reason = reasonFor(e);
  f.brands = latinBrands(e, m.name.trim().toLowerCase());
  f.alternatives = e.risk === 'NOT_LISTED' ? [] : e.alternatives.slice();
  const info: DrugInfo | undefined = drugInfo(e.ingredient);
  if (info !== undefined) {
    f.usedFor = info.usedFor;
    f.howItWorks = info.howItWorks;
    f.tips = info.tips.slice();
  }
  const verdict: DrugVerdict = DrugChecker.get().checkSync(e.ingredient);
  for (const other of myMeds) {
    if (other.id === m.id) {
      continue;
    }
    const combo: ComboVerdict = DrugChecker.get().checkCombo(verdict, [other]);
    if (combo.kind !== 'NONE') {
      f.interactions.push(combo);
    }
  }
  f.interactions.sort((a: ComboVerdict, b: ComboVerdict) =>
    (a.kind === 'CYP_INTERACTION' ? 0 : 1) - (b.kind === 'CYP_INTERACTION' ? 0 : 1));
  return f;
}

// One short line under a medicine name: what it is for, else its class, else ''.
export function medSubtitle(m: Medication): string {
  const e: DrugEntry | undefined = entryOf(m);
  if (e === undefined) {
    return '';
  }
  const info: DrugInfo | undefined = drugInfo(e.ingredient);
  return info !== undefined ? info.usedFor : e.drugClass;
}

export function medClass(m: Medication): string {
  const e: DrugEntry | undefined = entryOf(m);
  return e === undefined ? '' : e.drugClass;
}

// The first general tip, for a hint under a dose reminder.
export function medFirstTip(medId: number, meds: Medication[]): string {
  const m: Medication | undefined = meds.find((x: Medication) => x.id === medId);
  if (m === undefined) {
    return '';
  }
  const e: DrugEntry | undefined = entryOf(m);
  const info: DrugInfo | undefined = e === undefined ? undefined : drugInfo(e.ingredient);
  return info === undefined || info.tips.length === 0 ? '' : info.tips[0];
}
