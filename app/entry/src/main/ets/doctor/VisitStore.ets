// Doctor visits: one saved page per doctor the user has seen or is about to see. Kept on this phone only, as one
// JSON setting in LocalStore. parseVisits is pure and unit tested; anything malformed is dropped.

import { LocalStore } from '../data/LocalStore';
import { Specialty, SPECIALTIES } from './DoctorPrep';

const KEY: string = 'doctor.visits';
const MAX_VISITS: number = 40;
export const REASON_MAX_CHARS: number = 280;
export const DOCTOR_MAX_CHARS: number = 40;

export interface DoctorVisit {
  id: number;           // creation time in ms, unique on this phone
  specialty: Specialty;
  doctor: string;       // optional name, '' when not given
  reason: string;       // the user's own words, '' when not given
  createdAt: number;
  summary: string;      // checked AI summary, '' when none
  sharedAt: number;     // last time a link or the text was shared, 0 = never
}

function text(v: Object | undefined, max: number): string {
  return typeof v === 'string' ? (v as string).slice(0, max) : '';
}

function num(v: Object | undefined): number {
  return typeof v === 'number' && isFinite(v as number) ? v as number : 0;
}

// Stored JSON → visits, newest first.
export function parseVisits(raw: string): DoctorVisit[] {
  let list: Record<string, Object>[] = [];
  try {
    const parsed: Object = JSON.parse(raw) as Object;
    if (!Array.isArray(parsed)) {
      return [];
    }
    list = parsed as Record<string, Object>[];
  } catch (e) {
    return [];
  }
  const out: DoctorVisit[] = [];
  for (const r of list) {
    if (r === null || typeof r !== 'object') {
      continue;
    }
    const s: Specialty | undefined = SPECIALTIES.find((x: Specialty) => x === r['specialty']);
    const id: number = num(r['id']);
    if (s === undefined || id <= 0 || out.some((v: DoctorVisit) => v.id === id)) {
      continue;
    }
    const v: DoctorVisit = {
      id: id,
      specialty: s,
      doctor: text(r['doctor'], DOCTOR_MAX_CHARS),
      reason: text(r['reason'], REASON_MAX_CHARS),
      createdAt: num(r['createdAt']),
      summary: text(r['summary'], 600),
      sharedAt: num(r['sharedAt'])
    };
    out.push(v);
  }
  out.sort((a: DoctorVisit, b: DoctorVisit) => b.createdAt - a.createdAt);
  return out;
}

export class VisitStore {
  static async list(): Promise<DoctorVisit[]> {
    return parseVisits(await LocalStore.get().getSetting(KEY, '[]'));
  }

  static async get(id: number): Promise<DoctorVisit | undefined> {
    return (await VisitStore.list()).find((v: DoctorVisit) => v.id === id);
  }

  private static async save(visits: DoctorVisit[]): Promise<void> {
    await LocalStore.get().setSetting(KEY, JSON.stringify(visits.slice(0, MAX_VISITS)));
  }

  static async add(specialty: Specialty, doctor: string, reason: string, now: number): Promise<DoctorVisit> {
    const visits: DoctorVisit[] = await VisitStore.list();
    let id: number = now;
    while (visits.some((x: DoctorVisit) => x.id === id)) {
      id++;
    }
    const v: DoctorVisit = {
      id: id,
      specialty: specialty,
      doctor: doctor.trim().slice(0, DOCTOR_MAX_CHARS),
      reason: reason.trim().slice(0, REASON_MAX_CHARS),
      createdAt: now,
      summary: '',
      sharedAt: 0
    };
    await VisitStore.save([v].concat(visits));
    return v;
  }

  static async update(v: DoctorVisit): Promise<void> {
    const visits: DoctorVisit[] = await VisitStore.list();
    const i: number = visits.findIndex((x: DoctorVisit) => x.id === v.id);
    if (i < 0) {
      return;
    }
    visits[i] = v;
    await VisitStore.save(visits);
  }

  static async remove(id: number): Promise<void> {
    await VisitStore.save((await VisitStore.list()).filter((v: DoctorVisit) => v.id !== id));
  }
}
