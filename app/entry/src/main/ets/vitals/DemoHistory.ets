// The built-in demo history (no watch project to read from): 60 days of SIMULATED watch data ending today, generated
// by data/demo_history.py into DemoHistoryData.ets. The backend serves the same numbers for the demo watch
// (migration 20261004120000_demo_history.sql), so both paths tell one story. Pure, so tests can pin `now`.

import { WatchVitalsDay } from '../model/WatchData';
import { dayKey } from '../reminders/DoseSchedule';
import { DailyResting } from './RestingTrend';
import { TrendDay } from './Trends';
import {
  COL_ALERTS, COL_AVG_BPM, COL_BREATHING_RATE, COL_DOSES, COL_HRV_MS, COL_MAX_BPM, COL_MIN_BPM, COL_REST_MINUTES,
  COL_RESTING_BPM, COL_SLEEP_MINUTES, COL_SPO2_X10, COL_STEPS, COL_STRESS_MINUTES, COL_SYMPTOMS, DEMO_DAYS, DEMO_HISTORY
} from './DemoHistoryData';

const DAY_MS: number = 24 * 60 * 60 * 1000;

export { DEMO_DAYS };

interface DemoRow {
  day: string;
  cells: number[];
}

/** The worn days, newest first (today first). Weekly habits follow the real weekday of `now`. */
function demoRows(now: number): DemoRow[] {
  const variant: number[][] = DEMO_HISTORY[new Date(now).getDay()];
  const out: DemoRow[] = [];
  for (let ago = 0; ago < variant.length; ago++) {
    if (variant[ago].length > 0) {
      const r: DemoRow = { day: dayKey(now - ago * DAY_MS), cells: variant[ago] };
      out.push(r);
    }
  }
  return out;
}

/** Daily vitals for the Health tab, newest first. */
export function demoVitalsDays(now: number): WatchVitalsDay[] {
  return demoRows(now).map((r: DemoRow) => {
    const c: number[] = r.cells;
    const d: WatchVitalsDay = {
      day: r.day,
      avgBpm: c[COL_AVG_BPM],
      minBpm: c[COL_MIN_BPM],
      maxBpm: c[COL_MAX_BPM],
      hrvMs: c[COL_HRV_MS],
      spo2: c[COL_SPO2_X10] / 10,
      breathingRate: c[COL_BREATHING_RATE],
      sleepMinutes: c[COL_SLEEP_MINUTES],
      stressMinutes: c[COL_STRESS_MINUTES],
      steps: c[COL_STEPS],
      simulated: true
    };
    return d;
  });
}

/** Resting heart rate per day for the missed beta-blocker check and the doctor report, newest first. */
export function demoRestingDays(now: number): DailyResting[] {
  return demoRows(now).map((r: DemoRow) => {
    const d: DailyResting = {
      day: r.day, bpm: r.cells[COL_RESTING_BPM], restMinutes: r.cells[COL_REST_MINUTES], simulated: true
    };
    return d;
  });
}

/** Trends days (resting heart rate, doses, symptoms, alerts), newest first. */
export function demoTrendDays(now: number): TrendDay[] {
  return demoRows(now).map((r: DemoRow) => {
    const d: TrendDay = {
      day: r.day, restingBpm: r.cells[COL_RESTING_BPM], doses: r.cells[COL_DOSES], symptoms: r.cells[COL_SYMPTOMS],
      alerts: r.cells[COL_ALERTS]
    };
    return d;
  });
}
