// Dose schedule and today's doses (F-38). Pure — unit tested.

export interface DoseReminder {
  id: number;
  medId: number;
  medName: string;
  hour: number;
  minute: number;
  reminderId: number;   // system reminder id, -1 if not published
}

export interface DoseLog {
  reminderId: number;   // DoseReminder.id
  day: string;          // YYYY-MM-DD local
  status: string;       // 'TAKEN' | 'SKIPPED'
  ts: number;
}

export type DoseStatus = 'TAKEN' | 'SKIPPED' | 'DUE' | 'UPCOMING' | 'MISSED';

export const MISSED_AFTER_MS: number = 60 * 60 * 1000;

export function dayKey(ts: number): string {
  const d: Date = new Date(ts);
  const m: number = d.getMonth() + 1;
  return `${d.getFullYear()}-${m < 10 ? '0' : ''}${m}-${d.getDate() < 10 ? '0' : ''}${d.getDate()}`;
}

export function scheduledTs(r: DoseReminder, now: number): number {
  const d: Date = new Date(now);
  d.setHours(r.hour, r.minute, 0, 0);
  return d.getTime();
}

export function doseStatus(r: DoseReminder, logs: DoseLog[], now: number): DoseStatus {
  const today: string = dayKey(now);
  const log: DoseLog | undefined = logs.find((l: DoseLog) => l.reminderId === r.id && l.day === today);
  if (log !== undefined) {
    return log.status === 'TAKEN' ? 'TAKEN' : 'SKIPPED';
  }
  const at: number = scheduledTs(r, now);
  // A reminder created after today's time starts tomorrow (its id is the creation time).
  if (now < at || r.id > at) {
    return 'UPCOMING';
  }
  return now - at > MISSED_AFTER_MS ? 'MISSED' : 'DUE';
}

export function timeLabel(r: DoseReminder): string {
  return `${r.hour < 10 ? '0' : ''}${r.hour}:${r.minute < 10 ? '0' : ''}${r.minute}`;
}
