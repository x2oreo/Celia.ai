// Loads the Health tab's metric history: the daily summary (resting heart rate, doses, symptoms, findings) plus the
// watch's daily vitals. Same routing as Trends (WatchSource): the watch's Supabase project, otherwise a built-in demo
// history that is always labelled SIMULATED. A watch that has no rows yet gets empty days, never demo data.

import { WatchDataClient } from '../data/WatchDataClient';
import { WatchVitalsDay } from '../model/WatchData';
import { dayKey } from '../reminders/DoseSchedule';
import { buildSeries, MetricSeries } from './Metrics';
import { loadTrends, TrendData } from './Trends';

const DAY_MS: number = 24 * 60 * 60 * 1000;
const DEMO_DAYS: number = 16;

export interface MetricsData {
  series: MetricSeries[];
  trend: TrendData;
}

// Deterministic wobble so the demo looks lived-in and tests stay stable.
function wave(i: number, amp: number): number {
  return Math.sin(i * 1.7) * amp + Math.sin(i * 0.6 + 1) * amp * 0.5;
}

/**
 * Demo vitals for the same 16 days as RestingHistory.demoHistory (newest first, yesterday backwards): steady days,
 * then the last two with a raised heart rate, lower HRV, a short night and more stress time. The same story the
 * resting heart rate tells, so the charts agree with each other.
 */
export function demoVitals(now: number): WatchVitalsDay[] {
  const out: WatchVitalsDay[] = [];
  for (let i = 0; i < DEMO_DAYS; i++) {
    const raised: boolean = i < 2;
    const avg: number = Math.round((raised ? 82 : 71) + wave(i, 3));
    const d: WatchVitalsDay = {
      day: dayKey(now - (i + 1) * DAY_MS),
      avgBpm: avg,
      minBpm: Math.round((raised ? 66 : 54) + wave(i + 3, 2)),
      maxBpm: Math.round((raised ? 138 : 118) + wave(i + 5, 9)),
      hrvMs: Math.round((raised ? 31 : 48) + wave(i + 2, 4)),
      spo2: Math.round((97.2 + wave(i + 1, 0.6)) * 10) / 10,
      breathingRate: Math.round((raised ? 16 : 14) + wave(i + 4, 0.8)),
      sleepMinutes: Math.round((raised ? 340 : 445) + wave(i + 6, 30)),
      stressMinutes: Math.max(0, Math.round((raised ? 95 : 28) + wave(i + 7, 12))),
      steps: Math.max(800, Math.round((raised ? 3900 : 6400) + wave(i + 8, 1500))),
      simulated: true
    };
    out.push(d);
  }
  return out;
}

export async function loadMetrics(now: number, span: number): Promise<MetricsData> {
  const trend: TrendData = await loadTrends(now, span);
  let vitals: WatchVitalsDay[] = [];
  if (trend.source === 'DEMO') {
    vitals = demoVitals(now);
  } else if (trend.source === 'WATCH') {
    const rows: WatchVitalsDay[] | undefined = await WatchDataClient.vitalsDaily(span, false);
    vitals = rows !== undefined ? rows : [];
  }
  const data: MetricsData = { series: buildSeries(trend.days, vitals, trend.simulated), trend: trend };
  return data;
}
