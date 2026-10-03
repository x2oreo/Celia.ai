// Doctor visit prep (F-14, F-31): a safety brief for a specific specialist, built only from on-device data and a
// curated table — no AI. Pure functions, unit tested. Watch-outs follow standard long-QT guidance (avoid QT drugs,
// keep potassium/magnesium normal, beta-blocker continuity, ICD management, avoid adrenergic triggers).

import { Profile } from '../model/Profile';
import { Medication } from '../model/Medication';
import { ScanRecord } from '../model/ScanRecord';
import { AppEvent } from '../model/AppEvent';
import { ComboVerdict, DrugVerdict } from '../model/DrugVerdict';
import { VitalsAlert } from '../model/Vitals';
import { DrugChecker } from '../drugs/DrugChecker';
import { medsInteractions } from '../drugs/MedsReview';
import { RiskUi } from '../common/RiskUi';
import { fullDate } from '../common/Format';

export type Specialty = 'GP' | 'CARDIOLOGIST' | 'DENTIST' | 'SURGEON' | 'ANESTHESIOLOGIST' | 'PSYCHIATRIST' |
  'EMERGENCY';

export const SPECIALTIES: Specialty[] = ['GP', 'CARDIOLOGIST', 'DENTIST', 'SURGEON', 'ANESTHESIOLOGIST',
  'PSYCHIATRIST', 'EMERGENCY'];

export function specialtyName(s: Specialty): string {
  switch (s) {
    case 'CARDIOLOGIST':
      return 'Cardiologist';
    case 'DENTIST':
      return 'Dentist';
    case 'SURGEON':
      return 'Surgeon';
    case 'ANESTHESIOLOGIST':
      return 'Anaesthetist';
    case 'PSYCHIATRIST':
      return 'Psychiatrist';
    case 'EMERGENCY':
      return 'Emergency doctor';
    default:
      return 'GP / family doctor';
  }
}

const WATCH_OUTS_ALL: string[] = [
  'Avoid QT-prolonging drugs; check each new drug at crediblemeds.org.',
  'Keep potassium and magnesium in the normal range (vomiting, diarrhoea and diuretics lower them).',
  'Do not stop the beta-blocker without a cardiologist.'
];

export function watchOuts(s: Specialty): string[] {
  switch (s) {
    case 'CARDIOLOGIST':
      return ['Review the ECG / QTc trend and beta-blocker dose and adherence.',
        'Review every medicine below for QT risk and interactions.',
        'Check potassium and magnesium.'];
    case 'DENTIST':
      return ['Local anaesthetic with adrenaline (epinephrine): discuss the lowest dose or an adrenaline-free option.',
        'Antibiotics: avoid macrolides (azithromycin, clarithromycin, erythromycin) and quinolones; amoxicillin ' +
          'is not on the QT lists.',
        'Pain and anxiety are triggers — plan good pain control.'];
    case 'SURGEON':
      return ['Plan anaesthesia with the anaesthetist; many antiemetics prolong QT (ondansetron, droperidol).',
        'Keep potassium and magnesium normal before and after surgery; continue the beta-blocker.',
        'If an ICD is present: arrange ICD programming around surgery (electrocautery).'];
    case 'ANESTHESIOLOGIST':
      return ['Choose agents and antiemetics not on the QT lists (sevoflurane, propofol, ondansetron and droperidol ' +
        'are listed).', 'Defibrillator ready; correct potassium and magnesium; continue the beta-blocker.',
        'Avoid sudden loud noise at induction and wake-up (LQT2 trigger); ICD reprogramming if present.'];
    case 'PSYCHIATRIST':
      return ['Many antidepressants and antipsychotics prolong QT (citalopram, escitalopram, haloperidol, ' +
        'quetiapine…).', 'Prefer options not on the QT lists; ECG before and after starting.',
        'Watch for interactions with medicines below (CYP2D6 / CYP3A4).'];
    case 'EMERGENCY':
      return ['Torsades: IV magnesium sulfate; cardiac arrest: CPR and defibrillation.',
        'Avoid QT-prolonging drugs (e.g. ondansetron, haloperidol, macrolides, quinolones).',
        'Check potassium and magnesium; ECG with QTc.'];
    default:
      return ['Check every new prescription for QT risk before starting it.',
        'During vomiting / diarrhoea: check and correct electrolytes.',
        'If a QT drug is unavoidable: ECG before and after starting.'];
  }
}

export class BriefSection {
  title: string;
  lines: string[];

  constructor(title: string, lines: string[]) {
    this.title = title;
    this.lines = lines;
  }
}

function isRiskyScan(s: ScanRecord): boolean {
  return s.risk === 'KNOWN_RISK' || s.risk === 'POSSIBLE_RISK' || s.risk === 'CONDITIONAL_RISK' ||
    s.combo !== 'NONE';
}

export function buildBrief(p: Profile, meds: Medication[], scans: ScanRecord[], events: AppEvent[],
  s: Specialty, now: number): BriefSection[] {
  const out: BriefSection[] = [];
  const since: number = now - 90 * 86400000;

  const gt: string = p.genotype === 'UNKNOWN' ? 'genotype unknown' : p.genotype;
  out.push(new BriefSection('Patient', [
    `${p.name !== undefined && p.name.length > 0 ? `${p.name}: ` : ''}long QT syndrome (${gt}).`,
    `Implanted defibrillator (ICD): ${p.hasIcd ? 'yes' : 'no'}.`
  ].concat(p.notes.length > 0 ? [`Notes: ${p.notes}`] : [])));

  const medLines: string[] = meds.map((m: Medication) => {
    const v: DrugVerdict = DrugChecker.get().checkSync(m.ingredient !== '' ? m.ingredient : m.name);
    return `${m.name}${m.dose === '' ? '' : ` ${m.dose}`} — ${RiskUi.plain(v.risk)}`;
  });
  out.push(new BriefSection('Current medicines', medLines.length === 0 ? ['None recorded.'] : medLines));

  const combos: ComboVerdict[] = medsInteractions(meds);
  if (combos.length > 0) {
    out.push(new BriefSection('Interactions between current medicines',
      combos.map((c: ComboVerdict) => c.reason)));
  }

  const flagged: string[] = [];
  for (const sc of scans) {
    if (sc.ts >= since && isRiskyScan(sc)) {
      const name: string = sc.ingredient === '' ? sc.query : sc.ingredient;
      const line: string = `${fullDate(sc.ts)}: ${name} — ${RiskUi.plain(sc.risk)}` +
        `${sc.combo !== 'NONE' ? ', interaction with current medicines' : ''}`;
      if (!flagged.includes(line)) {
        flagged.push(line);
      }
    }
  }
  if (flagged.length > 0) {
    out.push(new BriefSection('Medicines I was offered and flagged (last 90 days)', flagged.slice(0, 10)));
  }

  const heart: string[] = [];
  const symptoms: string[] = [];
  for (const e of events) {
    if (e.ts < since) {
      continue;
    }
    if (e.kind === 'VITALS_ALERT') {
      const a: VitalsAlert = JSON.parse(e.detail) as VitalsAlert;
      if (a.severity === 'CRITICAL' || a.severity === 'WARN') {
        heart.push(`${fullDate(e.ts)}: ${a.kind.toLowerCase().replace(/_/g, ' ')}${a.hr > 0 ? `, ${a.hr} bpm` : ''}`);
      }
    } else if (e.kind === 'SYMPTOM') {
      symptoms.push(`${fullDate(e.ts)}: ${symptomLine(e.detail)}`);
    } else if (e.kind === 'SOS') {
      heart.push(`${fullDate(e.ts)}: SOS (${sosOutcome(e.detail)})`);
    }
  }
  if (heart.length > 0) {
    out.push(new BriefSection('Heart alerts and SOS (watch data — simulated on the emulator)',
      heart.slice(-10)));
  }
  if (symptoms.length > 0) {
    out.push(new BriefSection('Symptoms I logged', symptoms.slice(-10)));
  }

  out.push(new BriefSection(`For the ${specialtyName(s).toLowerCase()}`, watchOuts(s).concat(WATCH_OUTS_ALL)));
  out.push(new BriefSection('Questions I want to ask', questions(s, flagged.length > 0)));
  return out;
}

function questions(s: Specialty, flagged: boolean): string[] {
  const q: string[] = [];
  if (flagged) {
    q.push('Are the flagged medicines above safe for me, or is there an alternative?');
  }
  switch (s) {
    case 'CARDIOLOGIST':
      q.push('Is my beta-blocker dose still right? When is my next ECG / Holter?');
      q.push('Should my family members be screened?');
      break;
    case 'DENTIST':
      q.push('Which anaesthetic will you use, and how much adrenaline does it contain?');
      break;
    case 'SURGEON':
    case 'ANESTHESIOLOGIST':
      q.push('Which anaesthetic and anti-nausea medicines will you use?');
      q.push('Who will manage my ICD / beta-blocker around the operation?');
      break;
    case 'PSYCHIATRIST':
      q.push('Is this medicine on the QT lists? Do I need an ECG before starting?');
      break;
    default:
      q.push('Can you add "long QT — avoid QT-prolonging drugs" to my record?');
      break;
  }
  return q;
}

interface SymptomDetail {
  symptom: string;
  severity: number;
  activity: string;
}

interface SosDetail {
  outcome: string;
}

function symptomLine(detail: string): string {
  const d: SymptomDetail = JSON.parse(detail) as SymptomDetail;
  return `${d.symptom.toLowerCase().replace(/_/g, ' ')}, severity ${d.severity}/5` +
    `${d.activity.length > 0 ? `, during ${d.activity}` : ''}`;
}

function sosOutcome(detail: string): string {
  const d: SosDetail = JSON.parse(detail) as SosDetail;
  return d.outcome === 'ACKED' ? 'cancelled — I was OK' : 'sent to contacts';
}

export function briefText(sections: BriefSection[], s: Specialty, now: number): string {
  const parts: string[] = [`Long QT safety brief for ${specialtyName(s)} — ${fullDate(now)}`];
  for (const sec of sections) {
    parts.push('');
    parts.push(sec.title.toUpperCase());
    for (const l of sec.lines) {
      parts.push(`• ${l}`);
    }
  }
  parts.push('');
  parts.push('Prepared with Celia.ai from my own records. Not a medical device.');
  return parts.join('\n');
}
