// Symptom log entries (F-44). Written by the manual Symptom log page and by the agent's log_symptom tool (T27).
// Deterministic: which symptoms are red flags and which heart-rate window is attached never depend on a model.

import { VitalsSample } from './Vitals';

export type Symptom = 'DIZZINESS' | 'PALPITATIONS' | 'FAINTING' | 'CHEST_PAIN' | 'SHORTNESS_OF_BREATH' | 'OTHER';
export const SYMPTOMS: Symptom[] =
  ['DIZZINESS', 'PALPITATIONS', 'FAINTING', 'CHEST_PAIN', 'SHORTNESS_OF_BREATH', 'OTHER'];
export const ACTIVITIES: string[] = ['resting', 'sleeping', 'exercise', 'swimming', 'sudden noise / stress', 'other'];
export const HR_WINDOW_MS: number = 10 * 60 * 1000;   // heart rate attached from ±10 min around the symptom
export const NOTE_MAX: number = 120;

export interface SymptomEntry {
  symptom: Symptom;
  severity: number;     // 1..5
  activity: string;     // one of ACTIVITIES
  note: string;
  hrMin: number;        // -1 when no reading in the window
  hrMax: number;
}

export function isRedFlag(s: Symptom, severity: number): boolean {
  return s === 'FAINTING' || s === 'CHEST_PAIN' || (s === 'SHORTNESS_OF_BREATH' && severity >= 4);
}

export function symptomLabel(s: Symptom): string {
  const t: string = s.toLowerCase().replace(/_/g, ' ');
  return t.charAt(0).toUpperCase() + t.substring(1);
}

export function parseSymptom(v: string): Symptom | undefined {
  const s: string = v.trim().toUpperCase().replace(/[\s-]+/g, '_');
  return SYMPTOMS.find((x: Symptom) => x === s);
}

// Builds the stored entry: clamps severity, normalises activity, attaches the heart-rate range of samples within
// ±10 min of `at`.
export function buildSymptomEntry(symptom: Symptom, severity: number, activity: string, note: string,
  samples: VitalsSample[], at: number): SymptomEntry {
  const hrs: number[] = samples.filter((s: VitalsSample) => Math.abs(s.ts - at) <= HR_WINDOW_MS && s.hr > 0)
    .map((s: VitalsSample) => s.hr);
  const act: string = activity.trim().toLowerCase();
  const entry: SymptomEntry = {
    symptom: symptom,
    severity: Math.max(1, Math.min(5, Math.round(severity))),
    activity: ACTIVITIES.includes(act) ? act : 'other',
    note: note.trim().slice(0, NOTE_MAX),
    hrMin: hrs.length === 0 ? -1 : Math.min(...hrs),
    hrMax: hrs.length === 0 ? -1 : Math.max(...hrs)
  };
  return entry;
}
