// What a doctor visit is probably about, and which medicines the doctor should not reach for (doctor visits
// redesign). Fixed rules only, no AI: the reason the user typed is matched against keyword lists, each purpose maps
// to drug classes, and the medicines come from the bundled QT dataset with their risk level. Pure, unit tested.

import { DRUGS, DrugEntry } from '../drugs/DrugDataset';
import { RiskLevel } from '../model/DrugVerdict';
import { fullDate } from '../common/Format';
import { BriefSection, briefText, Specialty, specialtyName } from './DoctorPrep';

export type VisitPurpose = 'INFECTION' | 'PAIN' | 'NAUSEA' | 'PROCEDURE' | 'ALLERGY' | 'COLD' | 'MOOD' | 'SLEEP' |
  'STOMACH' | 'FUNGAL' | 'BREATHING' | 'HEART' | 'CHECKUP';

interface PurposeDef {
  purpose: VisitPurpose;
  title: string;        // "Infection"
  likely: string;       // what the doctor will probably reach for
  keywords: string[];   // lower case, matched at the start of a word
  classes: string[];    // lower-case parts of DrugEntry.drugClass
}

function def(purpose: VisitPurpose, title: string, likely: string, keywords: string[], classes: string[]): PurposeDef {
  const p: PurposeDef = { purpose: purpose, title: title, likely: likely, keywords: keywords, classes: classes };
  return p;
}

const PURPOSES: PurposeDef[] = [
  def('INFECTION', 'Infection', 'An antibiotic is likely.',
    ['infection', 'infected', 'antibiotic', 'fever', 'sinus', 'throat', 'tonsil', 'urinary', 'uti', 'bladder',
      'pneumonia', 'bronchitis', 'abscess', 'swollen', 'swelling', 'pus', 'ear'],
    ['antibiotic']),
  def('PAIN', 'Pain', 'A painkiller is likely.',
    ['pain', 'ache', 'aching', 'hurt', 'sore', 'headache', 'migraine', 'toothache', 'injury', 'sprain'],
    ['painkiller', 'opioid', 'muscle relaxant']),
  def('NAUSEA', 'Nausea or stomach bug', 'An anti-nausea medicine is likely.',
    ['nausea', 'nauseous', 'vomit', 'throwing up', 'diarrhoea', 'diarrhea', 'stomach bug', 'gastro',
      'food poisoning'],
    ['antiemetic', 'antidiarrhoeal']),
  def('PROCEDURE', 'Procedure or anaesthesia', 'An anaesthetic and an anti-nausea medicine are likely.',
    ['surgery', 'operation', 'procedure', 'anaesth', 'anesth', 'sedation', 'extraction', 'root canal', 'filling',
      'implant', 'tooth', 'teeth', 'wisdom', 'gum', 'dental', 'biopsy', 'endoscopy', 'colonoscopy'],
    ['anaesthetic', 'adrenaline', 'antiemetic']),
  def('ALLERGY', 'Allergy', 'An antihistamine is likely.',
    ['allergy', 'allergic', 'hay fever', 'hayfever', 'rash', 'itch', 'hives'],
    ['antihistamine']),
  def('COLD', 'Cold or flu', 'A decongestant is likely.',
    ['cold', 'flu', 'blocked nose', 'stuffy', 'congestion', 'runny nose', 'cough'],
    ['decongestant']),
  def('MOOD', 'Mood or anxiety', 'An antidepressant or a calming medicine is likely.',
    ['depress', 'anxiety', 'anxious', 'panic', 'low mood', 'mood', 'feeling down', 'stress', 'psychosis'],
    ['antidepressant', 'antipsychotic', 'mood stabiliser', 'anxiolytic']),
  def('SLEEP', 'Sleep', 'A sleep aid is likely.',
    ['sleep', 'insomnia', 'awake at night'],
    ['sleep aid', 'anxiolytic']),
  def('STOMACH', 'Heartburn or reflux', 'An acid reducer is likely.',
    ['heartburn', 'reflux', 'acid', 'ulcer', 'indigestion'],
    ['proton pump', 'h2 blocker', 'prokinetic']),
  def('FUNGAL', 'Fungal infection', 'An antifungal is likely.',
    ['fungal', 'fungus', 'thrush', 'yeast', 'candida'],
    ['antifungal']),
  def('BREATHING', 'Asthma or breathing', 'An inhaler is likely.',
    ['asthma', 'wheez', 'inhaler', 'short of breath', 'breathless'],
    ['asthma', 'inhaled steroid']),
  def('HEART', 'Heart review', 'A rhythm or blood-pressure medicine may come up.',
    ['palpitation', 'faint', 'blackout', 'passed out', 'dizzy', 'dizziness', 'ecg', 'holter', 'heart', 'chest pain',
      'rhythm', 'racing', 'blood pressure'],
    ['antiarrhythmic', 'diuretic', 'beta blocker', 'heart-rate', 'antianginal']),
  def('CHECKUP', 'Check-up', '',
    ['check-up', 'checkup', 'check up', 'routine', 'follow-up', 'follow up', 'screening'],
    [])
];

const MAX_PURPOSES: number = 4;

// One-tap starters under the reason field. Each is plain text the user could have typed.
export const REASON_STARTERS: string[] = ['Sore throat and fever', 'Toothache', 'Nausea', 'Allergy', 'Low mood',
  'Trouble sleeping', 'A procedure', 'Check-up'];

export const PURPOSE_ORDER: VisitPurpose[] = PURPOSES.map((p: PurposeDef) => p.purpose);

function defOf(purpose: VisitPurpose): PurposeDef {
  const d: PurposeDef | undefined = PURPOSES.find((p: PurposeDef) => p.purpose === purpose);
  return d === undefined ? PURPOSES[PURPOSES.length - 1] : d;
}

export function purposeTitle(purpose: VisitPurpose): string {
  return defOf(purpose).title;
}

function hasWord(text: string, keyword: string): boolean {
  return new RegExp(`(^|[^a-z])${keyword}`).test(text);
}

// Purposes named by the user's own words, in table order. Empty when nothing matches.
export function guessPurposes(reason: string): VisitPurpose[] {
  const text: string = reason.toLowerCase();
  const out: VisitPurpose[] = [];
  for (const p of PURPOSES) {
    if (p.keywords.some((k: string) => hasWord(text, k))) {
      out.push(p.purpose);
    }
  }
  return out.slice(0, MAX_PURPOSES);
}

// What this kind of doctor usually prescribes for, used when the reason says little.
export function usualPurposes(s: Specialty): VisitPurpose[] {
  switch (s) {
    case 'CARDIOLOGIST':
      return ['HEART'];
    case 'DENTIST':
      return ['PROCEDURE', 'INFECTION', 'PAIN'];
    case 'SURGEON':
    case 'ANESTHESIOLOGIST':
      return ['PROCEDURE', 'PAIN', 'NAUSEA'];
    case 'PSYCHIATRIST':
      return ['MOOD', 'SLEEP'];
    case 'EMERGENCY':
      return ['NAUSEA', 'INFECTION', 'PAIN'];
    default:
      return ['INFECTION', 'PAIN', 'NAUSEA'];
  }
}

export interface AvoidDrug {
  name: string;         // capitalised ingredient
  risk: RiskLevel;      // from the dataset, never NOT_LISTED here
  drugClass: string;
}

export interface PlanGroup {
  purpose: VisitPurpose;
  title: string;
  likely: string;
  fromReason: boolean;  // true = matched in the user's words, false = usual for this doctor
  avoid: AvoidDrug[];   // worst risk first
  options: string[];    // NOT_LISTED medicines of the same use, to ask about
}

function rank(risk: RiskLevel): number {
  return risk === 'KNOWN_RISK' ? 0 : risk === 'POSSIBLE_RISK' ? 1 : 2;
}

function cap(name: string): string {
  return name.length === 0 ? name : `${name.charAt(0).toUpperCase()}${name.slice(1)}`;
}

function groupFor(d: PurposeDef, fromReason: boolean, entries: DrugEntry[]): PlanGroup {
  const avoid: AvoidDrug[] = [];
  const options: string[] = [];
  for (const e of entries) {
    const cls: string = e.drugClass.toLowerCase();
    if (!d.classes.some((c: string) => cls.includes(c))) {
      continue;
    }
    if (e.risk !== 'NOT_LISTED') {
      const a: AvoidDrug = { name: cap(e.ingredient), risk: e.risk, drugClass: e.drugClass };
      avoid.push(a);
    } else if (!e.avoidCongenital) {
      options.push(cap(e.ingredient));
    }
  }
  avoid.sort((a: AvoidDrug, b: AvoidDrug) => rank(a.risk) - rank(b.risk));
  const g: PlanGroup = {
    purpose: d.purpose, title: d.title, likely: d.likely, fromReason: fromReason, avoid: avoid, options: options
  };
  return g;
}

// The plan for one visit: the purposes found in the reason first, then what this doctor usually prescribes for.
export function visitPlan(reason: string, s: Specialty, entries: DrugEntry[] = DRUGS): PlanGroup[] {
  const guessed: VisitPurpose[] = guessPurposes(reason);
  const all: VisitPurpose[] = guessed.slice();
  for (const u of usualPurposes(s)) {
    if (!all.includes(u)) {
      all.push(u);
    }
  }
  return all.slice(0, MAX_PURPOSES)
    .map((p: VisitPurpose) => groupFor(defOf(p), guessed.includes(p), entries));
}

function distinct(groups: PlanGroup[], known: boolean): string[] {
  const out: string[] = [];
  for (const g of groups) {
    for (const a of g.avoid) {
      if ((a.risk === 'KNOWN_RISK') === known && !out.includes(a.name)) {
        out.push(a.name);
      }
    }
  }
  return out;
}

// Known-risk medicines across the plan, each once.
export function knownNames(groups: PlanGroup[]): string[] {
  return distinct(groups, true);
}

// Possible- and conditional-risk medicines across the plan, each once.
export function cautionNames(groups: PlanGroup[]): string[] {
  return distinct(groups, false);
}

// Plain-text version of a visit page (share as text, copy).
export function visitText(s: Specialty, doctor: string, reason: string, groups: PlanGroup[],
  sections: BriefSection[], now: number): string {
  const parts: string[] = [`Long QT safety brief for ${specialtyName(s)}${doctor.length > 0 ? ` (${doctor})` : ''}` +
    ` — ${fullDate(now)}`];
  if (reason.trim().length > 0) {
    parts.push('');
    parts.push('REASON FOR THE VISIT');
    parts.push(reason.trim());
  }
  const known: string[] = knownNames(groups);
  if (known.length > 0) {
    parts.push('');
    parts.push('PLEASE DO NOT PRESCRIBE (KNOWN QT RISK)');
    for (const g of groups) {
      const names: string[] = g.avoid.filter((a: AvoidDrug) => a.risk === 'KNOWN_RISK')
        .map((a: AvoidDrug) => a.name);
      if (names.length > 0) {
        parts.push(`• ${g.title}: ${names.join(', ')}`);
      }
    }
  }
  const caution: string[] = cautionNames(groups);
  if (caution.length > 0) {
    parts.push('');
    parts.push('CHECK FIRST (POSSIBLE OR CONDITIONAL QT RISK)');
    parts.push(`• ${caution.join(', ')}`);
  }
  const body: string[] = briefText(sections, s, now).split('\n');
  return parts.concat(body.slice(1)).join('\n');
}
