// Daily resting heart rate history for RestingTrend: the `watch_resting_daily` view over the watch's `vitals` rows
// (Supabase). The watch's Simulate page can fill it with labelled simulated days. Without a backend configured, a
// built-in demo history so the emulator can still show the missed-dose question; every demo day is `simulated`.

import { Config } from '../common/Config';
import { getJson, NetResult, NetTarget } from '../common/Net';
import { WatchSource } from './WatchSource';
import { Logger } from '../common/Logger';
import { dayKey } from '../reminders/DoseSchedule';
import { DailyResting } from './RestingTrend';

const log: Logger = new Logger('RestingHistory');

const DAYS_TO_LOAD: number = 21;
const DAY_MS: number = 24 * 3600 * 1000;

interface RestingRow {
  day: string;
  resting_bpm: number;
  rest_minutes: number;
  simulated: boolean;
}

function toDaily(raw: string): DailyResting[] {
  const rows: RestingRow[] = JSON.parse(raw) as RestingRow[];
  if (!Array.isArray(rows)) {
    return [];
  }
  const out: DailyResting[] = [];
  for (const r of rows) {
    if (typeof r.day === 'string' && typeof r.resting_bpm === 'number' && typeof r.rest_minutes === 'number') {
      const d: DailyResting = {
        day: r.day, bpm: r.resting_bpm, restMinutes: r.rest_minutes, simulated: r.simulated === true
      };
      out.push(d);
    }
  }
  return out;
}

// 14 steady days around 58 bpm (on a beta-blocker), then the last two days around 70 bpm.
const DEMO_BASELINE: number[] = [58, 57, 59, 58, 56, 58, 60, 57, 58, 59, 57, 58, 56, 59];
const DEMO_RAISED: number[] = [71, 69];

export function demoHistory(now: number): DailyResting[] {
  const out: DailyResting[] = [];
  const all: number[] = DEMO_RAISED.concat(DEMO_BASELINE);
  for (let i = 0; i < all.length; i++) {
    const d: DailyResting = { day: dayKey(now - (i + 1) * DAY_MS), bpm: all[i], restMinutes: 420, simulated: true };
    out.push(d);
  }
  return out;
}

export async function loadRestingHistory(now: number): Promise<DailyResting[]> {
  const target: NetTarget | undefined = WatchSource.activeTarget();
  if (target !== undefined) {
    const path: string = `/rest/v1/watch_resting_daily?device_id=eq.${Config.WATCH_DEVICE_ID}` +
      `&select=day,resting_bpm,rest_minutes,simulated&order=day.desc&limit=${DAYS_TO_LOAD}`;
    const res: NetResult = await getJson(path, Config.DRUG_CHECK_TIMEOUT_MS, true, target);
    if (!res.ok) {
      return [];
    }
    try {
      return toDaily(res.body);
    } catch (e) {
      log.warn(`bad watch_resting_daily response: ${JSON.stringify(e)}`);
      return [];
    }
  }
  log.info('no watch source — using built-in demo history (SIMULATED)');
  return demoHistory(now);
}
