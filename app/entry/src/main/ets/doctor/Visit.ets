// A saved doctor visit (B6): which doctor, when, why, and what worries the patient. Stored as one JSON list under
// the LocalStore setting `doctor_visits` (doctor/VisitStore.ets). Pure helpers, unit-tested. The optional AI summary
// is kept with the visit so reopening it shows the text that was checked when it arrived.

import { Specialty, SPECIALTIES, VisitAnswers } from './DoctorPrep';

export const VISIT_TEXT_MAX: number = 300;

export interface DoctorVisit extends VisitAnswers {
  id: number;
  specialty: Specialty;
  createdAt: number;
  summary: string;     // '' until an AI summary passed the checks in doctor/DoctorSummary.ets
  summaryAt: number;   // 0 when there is no summary
}

function clip(s: string): string {
  return s.trim().replace(/[ \t]+/g, ' ').replace(/\n{3,}/g, '\n\n').slice(0, VISIT_TEXT_MAX);
}

export function isVisitDate(s: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) {
    return false;
  }
  const d: Date = new Date(`${s}T12:00:00`);
  return !isNaN(d.getTime()) && d.getDate() === Number(s.substring(8, 10));
}

export function newVisit(id: number, specialty: Specialty, date: string, reason: string, worries: string,
  now: number): DoctorVisit {
  const v: DoctorVisit = {
    id: id, specialty: specialty, date: date, reason: clip(reason), worries: clip(worries), createdAt: now,
    summary: '', summaryAt: 0
  };
  return v;
}

export function nextVisitId(list: DoctorVisit[]): number {
  let max: number = 0;
  for (const v of list) {
    max = Math.max(max, v.id);
  }
  return max + 1;
}

// Replaces the visit with the same id, or adds it.
export function upsertVisit(list: DoctorVisit[], v: DoctorVisit): DoctorVisit[] {
  const out: DoctorVisit[] = list.filter((x: DoctorVisit) => x.id !== v.id);
  out.push(v);
  return out;
}

export function removeVisit(list: DoctorVisit[], id: number): DoctorVisit[] {
  return list.filter((x: DoctorVisit) => x.id !== id);
}

// Upcoming visits first (soonest first), then past ones (most recent first).
export function sortVisits(list: DoctorVisit[], today: string): DoctorVisit[] {
  const upcoming: DoctorVisit[] = list.filter((v: DoctorVisit) => v.date >= today)
    .sort((a: DoctorVisit, b: DoctorVisit) => a.date === b.date ? a.id - b.id : (a.date < b.date ? -1 : 1));
  const past: DoctorVisit[] = list.filter((v: DoctorVisit) => v.date < today)
    .sort((a: DoctorVisit, b: DoctorVisit) => a.date === b.date ? b.id - a.id : (a.date < b.date ? 1 : -1));
  return upcoming.concat(past);
}

interface RawVisit {
  id?: number;
  specialty?: string;
  date?: string;
  reason?: string;
  worries?: string;
  createdAt?: number;
  summary?: string;
  summaryAt?: number;
}

function str(v: string | undefined): string {
  return typeof v === 'string' ? v : '';
}

function num(v: number | undefined): number {
  return typeof v === 'number' && isFinite(v) ? v : 0;
}

// Stored JSON → visits. Broken entries are skipped instead of losing the whole list.
export function parseVisits(raw: string): DoctorVisit[] {
  let items: RawVisit[];
  try {
    items = JSON.parse(raw) as RawVisit[];
  } catch (e) {
    return [];
  }
  if (!Array.isArray(items)) {
    return [];
  }
  const out: DoctorVisit[] = [];
  for (const r of items) {
    if (r === null || typeof r !== 'object' || typeof r.id !== 'number' || !isVisitDate(str(r.date))) {
      continue;
    }
    const s: Specialty | undefined = SPECIALTIES.find((x: Specialty) => x === r.specialty);
    const v: DoctorVisit = newVisit(r.id, s === undefined ? 'GP' : s, str(r.date), str(r.reason), str(r.worries),
      num(r.createdAt));
    v.summary = str(r.summary);
    v.summaryAt = v.summary === '' ? 0 : num(r.summaryAt);
    out.push(v);
  }
  return out;
}
