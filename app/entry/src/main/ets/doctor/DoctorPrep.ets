// Doctor visit prep (F-14, F-31): a safety brief for a specific specialist, built only from on-device data and a
// curated table - no AI. Pure functions, unit tested. Watch-outs follow standard long-QT guidance (avoid QT drugs,
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
import { FeelingEntry, Mood, MOODS, moodLabel, parseFeeling } from '../diary/Diary';

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

export const WATCH_OUTS_ALL: string[] = [
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
        'Pain and anxiety are triggers - plan good pain control.'];
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

// The patient's own answers for one visit (B6, doctor/Visit.ets DoctorVisit extends this).
export interface VisitAnswers {
  date: string;      // YYYY-MM-DD
  reason: string;
  worries: string;
}

function textLines(t: string): string[] {
  return t.split('\n').map((l: string) => l.trim()).filter((l: string) => l.length > 0);
}

// 'YYYY-MM-DD' → '20 Oct 2026' (the date part of common/Format fullDate).
export function visitDay(ymd: string): string {
  const when: number = new Date(`${ymd}T12:00:00`).getTime();
  return isNaN(when) ? ymd : fullDate(when).split(',')[0];
}

// "Date" + reason, then the worries as their own section. Shown first, after the patient line.
export function visitSections(v: VisitAnswers): BriefSection[] {
  const out: BriefSection[] = [];
  const lines: string[] = [`Date: ${visitDay(v.date)}.`];
  textLines(v.reason).forEach((l: string, i: number) => {
    lines.push(i === 0 ? `Reason: ${l}` : l);
  });
  out.push(new BriefSection('This visit', lines));
  const worries: string[] = textLines(v.worries);
  if (worries.length > 0) {
    out.push(new BriefSection('What worries me', worries));
  }
  return out;
}

// Diary moods in the window as counts only ("12 entries: 5 good, 4 okay, 3 low"); notes stay out of the brief.
export function diaryLine(events: AppEvent[], since: number): string {
  const counts: number[] = MOODS.map((m: Mood) => 0);
  let total: number = 0;
  for (const e of events) {
    if (e.ts >= since && e.kind === 'FEELING') {
      const f: FeelingEntry | undefined = parseFeeling(e.detail);
      if (f !== undefined) {
        counts[MOODS.indexOf(f.mood)]++;
        total++;
      }
    }
  }
  if (total === 0) {
    return '';
  }
  const parts: string[] = [];
  MOODS.forEach((m: Mood, i: number) => {
    if (counts[i] > 0) {
      parts.push(`${counts[i]} ${moodLabel(m).toLowerCase()}`);
    }
  });
  return `${total} ${total === 1 ? 'entry' : 'entries'}: ${parts.join(', ')}.`;
}

function isRiskyScan(s: ScanRecord): boolean {
  return s.risk === 'KNOWN_RISK' || s.risk === 'POSSIBLE_RISK' || s.risk === 'CONDITIONAL_RISK' ||
    s.combo !== 'NONE';
}

export function buildBrief(p: Profile, meds: Medication[], scans: ScanRecord[], events: AppEvent[],
  s: Specialty, now: number, visit?: VisitAnswers): BriefSection[] {
  const out: BriefSection[] = [];
  const since: number = now - 90 * 86400000;

  const gt: string = p.genotype === 'UNKNOWN' ? 'genotype unknown' : p.genotype;
  out.push(new BriefSection('Patient', [
    `${p.name !== undefined && p.name.length > 0 ? `${p.name}: ` : ''}long QT syndrome (${gt}).`,
    `Implanted defibrillator (ICD): ${p.hasIcd ? 'yes' : 'no'}.`
  ].concat(p.notes.length > 0 ? [`Notes: ${p.notes}`] : [])));
  if (visit !== undefined) {
    visitSections(visit).forEach((sec: BriefSection) => {
      out.push(sec);
    });
  }

  const medLines: string[] = meds.map((m: Medication) => {
    const v: DrugVerdict = DrugChecker.get().checkSync(m.ingredient !== '' ? m.ingredient : m.name);
    return `${m.name}${m.dose === '' ? '' : ` ${m.dose}`} - ${RiskUi.plain(v.risk)}`;
  });
  out.push(new BriefSection('Current medicines', medLines.length === 0 ? ['None recorded.'] : medLines));

  const combos: ComboVerdict[] = medsInteractions(meds);
  if (combos.length > 0) {
    out.push(new BriefSection('Interactions between current medicines',
      combos.map((c: ComboVerdict) => c.reason)));
  }

  const flagged: string[] = flaggedChecks(scans, since).map((f: ReportItem) => `${fullDate(f.ts)}: ${f.text}`);
  if (flagged.length > 0) {
    out.push(new BriefSection('Medicines I was offered and flagged (last 90 days)', flagged.slice(0, 10)));
  }

  const heart: string[] = heartEvents(events, since).map((h: ReportItem) => `${fullDate(h.ts)}: ${h.text}`);
  const symptoms: string[] = symptomEvents(events, since).map((h: ReportItem) => `${fullDate(h.ts)}: ${h.text}`);
  if (heart.length > 0) {
    out.push(new BriefSection('Heart alerts and SOS (watch data - simulated on the emulator)',
      heart.slice(-10)));
  }
  if (symptoms.length > 0) {
    out.push(new BriefSection('Symptoms I logged', symptoms.slice(-10)));
  }
  const diary: string = diaryLine(events, since);
  if (diary !== '') {
    out.push(new BriefSection('How I felt (diary, last 90 days)', [diary]));
  }

  out.push(new BriefSection(`For the ${specialtyName(s).toLowerCase()}`, watchOuts(s).concat(WATCH_OUTS_ALL)));
  out.push(new BriefSection('Questions I want to ask', questions(s, flagged.length > 0)));
  return out;
}

// One dated line of the report (a flagged check, a heart alert, an SOS or a symptom).
export interface ReportItem {
  ts: number;
  text: string;
  level: string;   // RiskLevel for checks; 'CRITICAL' | 'WARN' | 'SOS' for heart; 'SYMPTOM'
}

// Medicines checked in the window that were risky alone or with the current medicines, newest first, deduplicated.
export function flaggedChecks(scans: ScanRecord[], since: number): ReportItem[] {
  const out: ReportItem[] = [];
  const seen: string[] = [];
  for (const sc of scans) {
    if (sc.ts >= since && isRiskyScan(sc)) {
      const name: string = sc.ingredient === '' ? sc.query : sc.ingredient;
      const text: string = `${name} - ${RiskUi.plain(sc.risk)}` +
        `${sc.combo !== 'NONE' ? ', interaction with current medicines' : ''}`;
      const key: string = `${fullDate(sc.ts)}|${text}`;
      if (!seen.includes(key)) {
        seen.push(key);
        const item: ReportItem = { ts: sc.ts, text: text, level: sc.risk };
        out.push(item);
      }
    }
  }
  return out.slice(0, 10);
}

// Out-of-range heart alerts and SOS events in the window, oldest first (last 10).
export function heartEvents(events: AppEvent[], since: number): ReportItem[] {
  const out: ReportItem[] = [];
  for (const e of events) {
    if (e.ts < since) {
      continue;
    }
    if (e.kind === 'VITALS_ALERT') {
      const a: VitalsAlert = JSON.parse(e.detail) as VitalsAlert;
      if (a.severity === 'CRITICAL' || a.severity === 'WARN') {
        const item: ReportItem = {
          ts: e.ts, text: `${a.kind.toLowerCase().replace(/_/g, ' ')}${a.hr > 0 ? `, ${a.hr} bpm` : ''}`,
          level: a.severity
        };
        out.push(item);
      }
    } else if (e.kind === 'SOS') {
      const item: ReportItem = { ts: e.ts, text: `SOS (${sosOutcome(e.detail)})`, level: 'SOS' };
      out.push(item);
    }
  }
  return out.slice(-10);
}

export function symptomEvents(events: AppEvent[], since: number): ReportItem[] {
  const out: ReportItem[] = [];
  for (const e of events) {
    if (e.ts >= since && e.kind === 'SYMPTOM') {
      const item: ReportItem = { ts: e.ts, text: symptomLine(e.detail), level: 'SYMPTOM' };
      out.push(item);
    }
  }
  return out.slice(-10);
}

export function questions(s: Specialty, flagged: boolean): string[] {
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
      q.push('Can you add "long QT - avoid QT-prolonging drugs" to my record?');
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
  return d.outcome === 'ACKED' ? 'cancelled - I was OK' : 'sent to contacts';
}

export function briefText(sections: BriefSection[], s: Specialty, now: number): string {
  const parts: string[] = [`Long QT safety brief for ${specialtyName(s)} - ${fullDate(now)}`];
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
