// Diary and symptom counts per calendar day (B15), for Workstream A's Trends chart. Pure: events in, one row per
// day out, oldest first, today last. Days without entries are zero rows so the chart can align them with its days.

import { AppEvent } from '../model/AppEvent';
import { dayKey } from '../reminders/DoseSchedule';
import { FeelingEntry, isLowMood, parseFeeling } from './Diary';

const DAY_MS: number = 24 * 60 * 60 * 1000;

export interface DiaryDay {
  day: string;           // YYYY-MM-DD, local time (same key as vitals/Trends TrendDay.day)
  feelings: number;      // diary entries that day
  lowFeelings: number;   // of those, mood LOW or UNWELL
  symptoms: number;      // symptom log entries that day
}

export function dailyCounts(events: AppEvent[], now: number, days: number): DiaryDay[] {
  const span: number = Math.max(0, Math.floor(days));
  const out: DiaryDay[] = [];
  for (let i = span - 1; i >= 0; i--) {
    const row: DiaryDay = { day: dayKey(now - i * DAY_MS), feelings: 0, lowFeelings: 0, symptoms: 0 };
    out.push(row);
  }
  for (const e of events) {
    if (e.ts > now || (e.kind !== 'FEELING' && e.kind !== 'SYMPTOM')) {
      continue;
    }
    const row: DiaryDay | undefined = out.find((d: DiaryDay) => d.day === dayKey(e.ts));
    if (row === undefined) {
      continue;
    }
    if (e.kind === 'SYMPTOM') {
      row.symptoms++;
    } else {
      const f: FeelingEntry | undefined = parseFeeling(e.detail);
      if (f !== undefined) {
        row.feelings++;
        if (isLowMood(f.mood)) {
          row.lowFeelings++;
        }
      }
    }
  }
  return out;
}
