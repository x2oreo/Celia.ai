// Loads the Health tab's metric history: the daily summary (resting heart rate, doses, symptoms, findings) plus the
// watch's daily vitals. Same routing as Trends (WatchSource): the watch's Supabase project, otherwise a built-in demo
// history that is always labelled SIMULATED. A watch that has no rows yet gets empty days, never demo data.

import { WatchDataClient } from '../data/WatchDataClient';
import { WatchVitalsDay } from '../model/WatchData';
import { demoVitalsDays } from './DemoHistory';
import { buildSeries, MetricSeries } from './Metrics';
import { loadTrends, TrendData } from './Trends';

export interface MetricsData {
  series: MetricSeries[];
  trend: TrendData;
}

/** The built-in demo vitals (DemoHistory): 60 days ending today, newest first, labelled SIMULATED. */
export function demoVitals(now: number): WatchVitalsDay[] {
  return demoVitalsDays(now);
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
