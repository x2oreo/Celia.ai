// Doctor report as structured data for the shareable web report (site/report). Same deterministic sources as the
// text brief (DoctorPrep.ets) - no AI - plus the resting heart-rate trend and dose adherence. Pure, unit tested.
// Field names are short-ish but readable; the viewer page mirrors them (site/report/index.html).

import { Profile } from '../model/Profile';
import { Medication } from '../model/Medication';
import { ScanRecord } from '../model/ScanRecord';
import { AppEvent } from '../model/AppEvent';
import { ComboVerdict, DrugVerdict } from '../model/DrugVerdict';
import { DrugChecker } from '../drugs/DrugChecker';
import { medsInteractions } from '../drugs/MedsReview';
import { RiskUi } from '../common/RiskUi';
import { DailyResting } from '../vitals/RestingTrend';
import { DoseLog, DoseReminder, dayKey } from '../reminders/DoseSchedule';
import {
  flaggedChecks, heartEvents, questions, ReportItem, Specialty, specialtyName, symptomEvents, watchOuts,
  WATCH_OUTS_ALL
} from './DoctorPrep';
import { AvoidDrug, PlanGroup } from './VisitPlan';

export const REPORT_VERSION: number = 1;
const WINDOW_DAYS: number = 90;
const TREND_DAYS: number = 30;
const DOSE_DAYS: number = 14;
const DAY_MS: number = 86400000;

export interface ReportPatient {
  name: string;
  condition: string;
  genotype: string;     // LQT1 | LQT2 | LQT3 | UNKNOWN
  icd: boolean;
  notes: string;
}

export interface ReportMed {
  name: string;
  dose: string;
  ingredient: string;
  risk: string;         // RiskLevel (deterministic, curated list)
  riskText: string;
}

export interface ReportDay {
  day: string;          // YYYY-MM-DD
  bpm: number;
  simulated: boolean;
}

export interface ReportDoses {
  tracked: boolean;     // false = no reminders set up in the app
  days: number;
  taken: number;
  skipped: number;
  scheduled: number;    // reminders × days in the window
}

export interface ReportSummary {
  medsAtRisk: number;
  interactions: number;
  flagged: number;
  heartEvents: number;
  symptoms: number;
}

export interface ReportAvoidDrug {
  name: string;
  risk: string;         // RiskLevel (deterministic, curated list)
}

export interface ReportAvoidGroup {
  title: string;        // fixed purpose title, e.g. "Infection"
  likely: string;
  avoid: ReportAvoidDrug[];
  options: string[];    // NOT_LISTED medicines of the same use
}

// The visit this report was made for (doctor/VisitPlan.ets). Absent on reports made before visits existed.
export interface ReportVisit {
  doctor: string;
  reason: string;       // the patient's own words
  groups: ReportAvoidGroup[];
  aiSummary: string;    // checked AI summary, '' when none; shown labelled
}

export function reportVisit(doctor: string, reason: string, plan: PlanGroup[], aiSummary: string): ReportVisit {
  const v: ReportVisit = {
    doctor: doctor,
    reason: reason,
    groups: plan.filter((g: PlanGroup) => g.avoid.length > 0 || g.options.length > 0).map((g: PlanGroup) => {
      const rg: ReportAvoidGroup = {
        title: g.title,
        likely: g.likely,
        avoid: g.avoid.map((a: AvoidDrug) => {
          const d: ReportAvoidDrug = { name: a.name, risk: a.risk };
          return d;
        }),
        options: g.options
      };
      return rg;
    }),
    aiSummary: aiSummary
  };
  return v;
}

export interface ReportPayload {
  v: number;
  generatedAt: number;
  specialty: string;
  specialtyName: string;
  windowDays: number;
  patient: ReportPatient;
  summary: ReportSummary;
  meds: ReportMed[];
  interactions: string[];
  flagged: ReportItem[];
  heart: ReportItem[];
  symptoms: ReportItem[];
  resting: ReportDay[];      // oldest first, up to 30 days
  restingSimulated: boolean;
  doses: ReportDoses;
  watchOuts: string[];
  questions: string[];
  visit?: ReportVisit;
}

function isRisk(risk: string): boolean {
  return risk === 'KNOWN_RISK' || risk === 'POSSIBLE_RISK' || risk === 'CONDITIONAL_RISK';
}

export function doseAdherence(reminders: DoseReminder[], logs: DoseLog[], now: number): ReportDoses {
  const days: string[] = [];
  for (let i = 0; i < DOSE_DAYS; i++) {
    days.push(dayKey(now - i * DAY_MS));
  }
  const ids: number[] = reminders.map((r: DoseReminder) => r.id);
  const inWindow: DoseLog[] = logs.filter((l: DoseLog) => days.includes(l.day) && ids.includes(l.reminderId));
  const d: ReportDoses = {
    tracked: reminders.length > 0,
    days: DOSE_DAYS,
    taken: inWindow.filter((l: DoseLog) => l.status === 'TAKEN').length,
    skipped: inWindow.filter((l: DoseLog) => l.status === 'SKIPPED').length,
    scheduled: reminders.length * DOSE_DAYS
  };
  return d;
}

export function buildReport(p: Profile, meds: Medication[], scans: ScanRecord[], events: AppEvent[],
  s: Specialty, resting: DailyResting[], reminders: DoseReminder[], doseLogs: DoseLog[], now: number,
  visit?: ReportVisit): ReportPayload {
  const since: number = now - WINDOW_DAYS * DAY_MS;
  const reportMeds: ReportMed[] = meds.map((m: Medication) => {
    const v: DrugVerdict = DrugChecker.get().checkSync(m.ingredient !== '' ? m.ingredient : m.name);
    const r: ReportMed = {
      name: m.name, dose: m.dose, ingredient: v.ingredient, risk: v.risk, riskText: RiskUi.plain(v.risk)
    };
    return r;
  });
  const combos: string[] = medsInteractions(meds).map((c: ComboVerdict) => c.reason);
  const flagged: ReportItem[] = flaggedChecks(scans, since);
  const heart: ReportItem[] = heartEvents(events, since);
  const symptoms: ReportItem[] = symptomEvents(events, since);
  const trend: ReportDay[] = resting
    .filter((d: DailyResting) => d.bpm > 0)
    .sort((a: DailyResting, b: DailyResting) => a.day < b.day ? -1 : a.day > b.day ? 1 : 0)
    .slice(-TREND_DAYS)
    .map((d: DailyResting) => {
      const r: ReportDay = { day: d.day, bpm: Math.round(d.bpm), simulated: d.simulated };
      return r;
    });
  const payload: ReportPayload = {
    v: REPORT_VERSION,
    generatedAt: now,
    specialty: s,
    specialtyName: specialtyName(s),
    windowDays: WINDOW_DAYS,
    patient: {
      name: p.name ?? '', condition: 'Long QT syndrome', genotype: p.genotype, icd: p.hasIcd, notes: p.notes
    },
    summary: {
      medsAtRisk: reportMeds.filter((m: ReportMed) => isRisk(m.risk)).length,
      interactions: combos.length,
      flagged: flagged.length,
      heartEvents: heart.length,
      symptoms: symptoms.length
    },
    meds: reportMeds,
    interactions: combos,
    flagged: flagged,
    heart: heart,
    symptoms: symptoms,
    resting: trend,
    restingSimulated: trend.some((d: ReportDay) => d.simulated),
    doses: doseAdherence(reminders, doseLogs, now),
    watchOuts: watchOuts(s).concat(WATCH_OUTS_ALL),
    questions: questions(s, flagged.length > 0)
  };
  if (visit !== undefined) {
    payload.visit = visit;
  }
  return payload;
}
