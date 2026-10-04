// Daily resting heart rate history for RestingTrend: the `watch_resting_daily` view over the watch's `vitals` rows
// (Supabase). The watch's Simulate page can fill it with labelled simulated days. Without a backend configured, a
// built-in demo history so the emulator can still show the missed-dose question; every demo day is `simulated`.

import { Config } from '../common/Config';
import { getJson, NetResult, NetTarget } from '../common/Net';
import { WatchSource } from './WatchSource';
import { Logger } from '../common/Logger';
import { DailyResting } from './RestingTrend';
import { demoRestingDays } from './DemoHistory';

const log: Logger = new Logger('RestingHistory');

const DAYS_TO_LOAD: number = 21;

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

/** The built-in demo history (DemoHistory), newest first, every day labelled `simulated`. */
export function demoHistory(now: number): DailyResting[] {
  return demoRestingDays(now);
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
  log.info('no watch source - using built-in demo history (SIMULATED)');
  return demoHistory(now);
}
