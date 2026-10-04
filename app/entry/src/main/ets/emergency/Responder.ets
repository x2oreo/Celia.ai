// First-responder view content (Workstream B5): what not to give, what to use instead, and immediate care notes.
// Pure and deterministic - built only from the bundled drug dataset (drugs/DrugDataset.ets, CredibleMeds QTdrugs
// categories) and the emergency facts of the lqts-domain skill (.claude/skills/lqts-domain/SKILL.md, "Emergency
// facts" and "Genotypes"; ERC/ESC guidance as cited there). No LLM text and no network on this path.

import { DRUGS, DrugEntry } from '../drugs/DrugDataset';
import { DrugChecker } from '../drugs/DrugChecker';
import { IntakeRecord, WATCH_WINDOW_MS } from '../drugs/DrugIntake';
import { RiskLevel } from '../model/DrugVerdict';
import { Medication } from '../model/Medication';
import { Profile } from '../model/Profile';
import { medLine } from './CardContent';

// Drugs to avoid, one group per drug class (or the congenital-LQTS stimulant group).
export interface AvoidGroup {
  title: string;
  drugs: string[];   // INN, lower case, dataset order
  note: string;      // '' or a qualifier the responder must see with the group
}

// Alternatives to ask about, grouped by what they replace.
export interface InsteadGroup {
  replaces: string[];   // INN of the risky drugs these options replace
  classes: string[];    // their drug classes, deduplicated, e.g. ['Macrolide antibiotic', 'Fluoroquinolone antibiotic']
  options: string[];    // NOT_LISTED alternatives from the dataset
}

export interface MedRow {
  line: string;          // as on the emergency card, e.g. 'Concor (bisoprolol) 5 mg'
  risk: RiskLevel;       // from the dataset; UNKNOWN_DRUG when the medicine isn't in it
  avoidCongenital: boolean;
}

// lqts-domain "Avoid in congenital LQTS": stimulants and catecholamines; the emergency card text adds
// "unless life-saving".
export const STIMULANT_GROUP_TITLE: string = 'Stimulants and catecholamines';
export const STIMULANT_GROUP_NOTE: string = 'Avoid in congenital long QT unless life-saving.';

function isAntiemetic(e: DrugEntry): boolean {
  return e.drugClass.toLowerCase().includes('antiemetic');
}

/**
 * "Do not give" for congenital LQTS: every Known-risk drug (by class) and the avoid-in-congenital list. Antiemetics
 * come first and the stimulant group second, because those are what an ambulance crew reaches for (lqts-domain
 * card text: "Avoid QT-prolonging antiemetics … and catecholamines unless life-saving"); the rest keep dataset order.
 */
export function doNotGive(entries: DrugEntry[] = DRUGS): AvoidGroup[] {
  const byClass: Map<string, AvoidGroup> = new Map<string, AvoidGroup>();
  const order: string[] = [];
  const stimulants: AvoidGroup = { title: STIMULANT_GROUP_TITLE, drugs: [], note: STIMULANT_GROUP_NOTE };
  for (const e of entries) {
    if (e.avoidCongenital) {
      stimulants.drugs.push(e.ingredient);
      continue;
    }
    if (e.risk !== 'KNOWN_RISK') {
      continue;
    }
    const key: string = isAntiemetic(e) ? 'Antiemetics' : e.drugClass;
    let g: AvoidGroup | undefined = byClass.get(key);
    if (g === undefined) {
      g = { title: key, drugs: [], note: '' };
      byClass.set(key, g);
      order.push(key);
    }
    g.drugs.push(e.ingredient);
  }
  const out: AvoidGroup[] = [];
  const antiemetics: AvoidGroup | undefined = byClass.get('Antiemetics');
  if (antiemetics !== undefined) {
    out.push(antiemetics);
  }
  if (stimulants.drugs.length > 0) {
    out.push(stimulants);
  }
  for (const k of order) {
    if (k !== 'Antiemetics') {
      out.push(byClass.get(k) as AvoidGroup);
    }
  }
  return out;
}

/**
 * "Use instead": the dataset's alternatives[] for every QT-risk drug (Known, Possible or Conditional), grouped by
 * the option set so one row says e.g. "Instead of macrolide and fluoroquinolone antibiotics: amoxicillin, …".
 * Options are NOT_LISTED in the dataset (checked by test/DrugData) - still only a doctor can choose.
 */
export function useInstead(entries: DrugEntry[] = DRUGS): InsteadGroup[] {
  const groups: Map<string, InsteadGroup> = new Map<string, InsteadGroup>();
  const order: string[] = [];
  for (const e of entries) {
    if (e.risk === 'NOT_LISTED' || e.alternatives.length === 0) {
      continue;
    }
    const key: string = e.alternatives.join(',');
    let g: InsteadGroup | undefined = groups.get(key);
    if (g === undefined) {
      g = { replaces: [], classes: [], options: e.alternatives.slice() };
      groups.set(key, g);
      order.push(key);
    }
    g.replaces.push(e.ingredient);
    if (!g.classes.includes(e.drugClass)) {
      g.classes.push(e.drugClass);
    }
  }
  return order.map((k: string) => groups.get(k) as InsteadGroup);
}

/** Full years between an ISO 'YYYY-MM-DD' birth date and now; undefined when missing, malformed or in the future. */
export function ageYears(dateOfBirth: string | undefined, now: number): number | undefined {
  if (dateOfBirth === undefined) {
    return undefined;
  }
  const m: RegExpMatchArray | null = dateOfBirth.trim().match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (m === null) {
    return undefined;
  }
  const y: number = Number(m[1]);
  const mo: number = Number(m[2]);
  const d: number = Number(m[3]);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) {
    return undefined;
  }
  const today: Date = new Date(now);
  let age: number = today.getFullYear() - y;
  if (today.getMonth() + 1 < mo || (today.getMonth() + 1 === mo && today.getDate() < d)) {
    age -= 1;
  }
  return age >= 0 && age < 130 ? age : undefined;
}

function entryFor(m: Medication): DrugEntry | undefined {
  const checker: DrugChecker = DrugChecker.get();
  return (m.ingredient !== '' ? checker.entry(m.ingredient) : undefined) ?? checker.resolve(m.name);
}

/** The patient's medicines with the dataset risk of each, in the order the user added them. */
export function medRows(meds: Medication[]): MedRow[] {
  return meds.map((m: Medication): MedRow => {
    const e: DrugEntry | undefined = entryFor(m);
    const row: MedRow = {
      line: medLine(m),
      risk: e === undefined ? 'UNKNOWN_DRUG' : e.risk,
      avoidCongenital: e !== undefined && e.avoidCongenital
    };
    return row;
  });
}

function genotypeTrigger(p: Profile): string {
  // lqts-domain "Genotypes" table, typical trigger column.
  switch (p.genotype) {
    case 'LQT1':
      return 'Typical trigger (LQT1): exercise, especially swimming, and adrenaline.';
    case 'LQT2':
      return 'Typical trigger (LQT2): sudden loud noise, emotional stress, the period after giving birth.';
    case 'LQT3':
      return 'Typical trigger (LQT3): rest and sleep, slow heart rate.';
    default:
      return '';
  }
}

/**
 * Immediate care notes, in order of urgency. Source: lqts-domain "Emergency facts" (bystander steps; card text for
 * clinicians) and "Genotypes". `emergencyNumber` is the local ambulance number (common/EmergencyNumbers.ets).
 */
export function careNotes(p: Profile, meds: Medication[], emergencyNumber: string): string[] {
  const notes: string[] = [
    `Unresponsive and not breathing normally: call ${emergencyNumber}, start CPR and use an AED as soon as possible.`,
    'Torsades de pointes is treated with IV magnesium sulfate. Unstable patients are defibrillated.',
    'Keep potassium and magnesium high-normal.',
    'Avoid QT-prolonging antiemetics (ondansetron, droperidol, domperidone) and catecholamines unless life-saving.'
  ];
  if (p.hasIcd) {
    const model: string = (p.icdModel ?? '').trim();
    notes.push(model.length > 0 ? `Has an implanted defibrillator (ICD): ${model}.` :
      'Has an implanted defibrillator (ICD).');
  }
  const betaBlockers: string[] = meds.filter((m: Medication) => {
    const e: DrugEntry | undefined = entryFor(m);
    return e !== undefined && e.drugClass.toLowerCase().includes('beta blocker');
  }).map((m: Medication) => medLine(m));
  if (betaBlockers.length > 0) {
    notes.push(`Beta-blocker: ${betaBlockers.join(', ')}.`);
  }
  const trigger: string = genotypeTrigger(p);
  if (trigger.length > 0) {
    notes.push(trigger);
  }
  return notes;
}

/** The last logged risky medicine (DrugIntake 'riskyIntakeLast'), if it was taken inside the 72 h watch window. */
export function recentRiskyIntake(raw: string, now: number): IntakeRecord | undefined {
  try {
    const rec: IntakeRecord = JSON.parse(raw) as IntakeRecord;
    if (rec !== null && typeof rec.name === 'string' && rec.name !== '' && typeof rec.ts === 'number' &&
      rec.ts <= now && now - rec.ts < WATCH_WINDOW_MS) {
      return rec;
    }
  } catch (e) {
    return undefined;
  }
  return undefined;
}
