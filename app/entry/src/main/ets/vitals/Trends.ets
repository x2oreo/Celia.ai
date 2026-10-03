// Trends (Heart → Trends): resting heart rate per day with dose and symptom marks, from the watch's daily summary.
// The maths is pure and unit-tested. Resting heart rate only: never QT, never a diagnosis.

import { Config } from '../common/Config';
import { dayKey } from '../reminders/DoseSchedule';
import { WatchDataClient } from '../data/WatchDataClient';
import { WatchDaySummary, WatchInsight } from '../model/WatchData';
import { DailyResting } from './RestingTrend';
import { demoHistory } from './RestingHistory';
import { NetTarget, shareTarget } from '../common/Net';

const DAY_MS: number = 24 * 60 * 60 * 1000;

export interface TrendDay {
  day: string;          // YYYY-MM-DD
  restingBpm: number;   // 0 = not enough rest data that day
  doses: number;
  symptoms: number;
  alerts: number;
}

export type TrendSource = 'WATCH' | 'DEMO' | 'OFFLINE';

export interface TrendData {
  days: TrendDay[];           // one per calendar day, oldest first
  insights: WatchInsight[];   // fixed-rule findings with fixed text
  source: TrendSource;
  simulated: boolean;         // demo history, or watch rows marked simulated
}

export interface TrendStats {
  avgResting: number;     // 0 when no day has a value
  change: number;         // last 7 days minus the days before, bpm
  hasChange: boolean;     // false when either side has fewer than 3 days
  symptomDays: number;
  doseDays: number;
  daysWithData: number;
}

export interface TrendScale {
  min: number;
  max: number;
}

export interface TrendPoint {
  index: number;   // position in days
  x: number;
  y: number;
}

/** One entry per calendar day ending today, oldest first. Days without a row are empty. */
export function fillDays(rows: TrendDay[], now: number, span: number): TrendDay[] {
  const out: TrendDay[] = [];
  for (let i = span - 1; i >= 0; i--) {
    const key: string = dayKey(now - i * DAY_MS);
    const found: TrendDay | undefined = rows.find((r: TrendDay) => r.day === key);
    const empty: TrendDay = { day: key, restingBpm: 0, doses: 0, symptoms: 0, alerts: 0 };
    out.push(found !== undefined ? found : empty);
  }
  return out;
}

function mean(values: number[]): number {
  if (values.length === 0) {
    return 0;
  }
  let sum: number = 0;
  for (const v of values) {
    sum += v;
  }
  return sum / values.length;
}

export function trendStats(days: TrendDay[]): TrendStats {
  const withBpm: TrendDay[] = days.filter((d: TrendDay) => d.restingBpm > 0);
  const recent: number[] = days.slice(-7).filter((d: TrendDay) => d.restingBpm > 0).map((d: TrendDay) => d.restingBpm);
  const before: number[] = days.slice(0, Math.max(0, days.length - 7)).filter((d: TrendDay) => d.restingBpm > 0)
    .map((d: TrendDay) => d.restingBpm);
  const hasChange: boolean = recent.length >= 3 && before.length >= 3;
  const stats: TrendStats = {
    avgResting: Math.round(mean(withBpm.map((d: TrendDay) => d.restingBpm))),
    change: hasChange ? Math.round(mean(recent) - mean(before)) : 0,
    hasChange: hasChange,
    symptomDays: days.filter((d: TrendDay) => d.symptoms > 0).length,
    doseDays: days.filter((d: TrendDay) => d.doses > 0).length,
    daysWithData: days.filter((d: TrendDay) => d.restingBpm > 0 || d.doses > 0 || d.symptoms > 0 || d.alerts > 0).length
  };
  return stats;
}

/** Y range: the data padded by 5 bpm, snapped to 10s, at least 30 bpm tall so small wobbles stay small. */
export function trendScale(days: TrendDay[]): TrendScale {
  const values: number[] = days.filter((d: TrendDay) => d.restingBpm > 0).map((d: TrendDay) => d.restingBpm);
  if (values.length === 0) {
    const none: TrendScale = { min: 40, max: 80 };
    return none;
  }
  let min: number = Math.floor((Math.min(...values) - 5) / 10) * 10;
  let max: number = Math.ceil((Math.max(...values) + 5) / 10) * 10;
  while (max - min < 30) {
    max += 5;
    min -= 5;
  }
  const scale: TrendScale = { min: min, max: max };
  return scale;
}

/** Centre x of day i when `count` days share `width`. */
export function dayX(i: number, count: number, width: number): number {
  return count <= 0 ? 0 : (i + 0.5) * width / count;
}

export function trendPoints(days: TrendDay[], width: number, height: number): TrendPoint[] {
  const scale: TrendScale = trendScale(days);
  const out: TrendPoint[] = [];
  for (let i = 0; i < days.length; i++) {
    if (days[i].restingBpm <= 0) {
      continue;
    }
    const p: TrendPoint = {
      index: i,
      x: dayX(i, days.length, width),
      y: height - (days[i].restingBpm - scale.min) / (scale.max - scale.min) * height
    };
    out.push(p);
  }
  return out;
}

// Demo story, labelled SIMULATED: steady on a beta-blocker, then two days without a logged dose, a raised resting
// heart rate and a symptom.
function demoDays(now: number): TrendDay[] {
  const resting: DailyResting[] = demoHistory(now);
  const out: TrendDay[] = [];
  for (let i = 0; i < resting.length; i++) {
    const raised: boolean = i < 2;   // demoHistory is newest first
    const d: TrendDay = {
      day: resting[i].day, restingBpm: resting[i].bpm, doses: raised ? 0 : 1, symptoms: i === 0 ? 1 : 0,
      alerts: i === 0 ? 1 : 0
    };
    out.push(d);
  }
  return out;
}

// Which project the watch history is read from.
//   BACKEND  the app backend is the Supabase project (release build): same URL and key as everything else.
//   SHARE    the AI backend is a local dev server (127.0.0.1) that has no watch tables: read the deployed project
//            (Config.SHARE_BACKEND_URL) with its own public client key (LocalConfig.SHARE_ANON_KEY).
//   DEMO     no backend, or no key for the deployed project: built-in demo history, labelled SIMULATED.
export type TrendsRoute = 'BACKEND' | 'SHARE' | 'DEMO';

export function trendsRoute(hasWatchCloud: boolean, hasBackend: boolean, shareUrl: string, shareKey: string,
  backendKey: string): TrendsRoute {
  if (hasWatchCloud) {
    return 'BACKEND';
  }
  // Without its own key the share key falls back to the local backend's key, which the project rejects.
  return hasBackend && shareUrl !== '' && shareKey !== '' && shareKey !== backendKey ? 'SHARE' : 'DEMO';
}

export async function loadTrends(now: number, span: number): Promise<TrendData> {
  const route: TrendsRoute = trendsRoute(Config.hasWatchCloud(), Config.hasBackend(), Config.SHARE_BACKEND_URL,
    Config.SHARE_ANON_KEY, Config.SUPABASE_ANON_KEY);
  if (route === 'DEMO') {
    const demo: TrendData = { days: fillDays(demoDays(now), now, span), insights: [], source: 'DEMO', simulated: true };
    return demo;
  }
  const target: NetTarget | undefined = route === 'SHARE' ? shareTarget() : undefined;
  const rows: WatchDaySummary[] | undefined = await WatchDataClient.dailySummary(span, true, target);
  if (rows === undefined) {
    const off: TrendData = { days: fillDays([], now, span), insights: [], source: 'OFFLINE', simulated: false };
    return off;
  }
  const insights: WatchInsight[] | undefined = await WatchDataClient.insights(true, target);
  const days: TrendDay[] = rows.map((r: WatchDaySummary) => {
    const d: TrendDay = {
      day: r.day, restingBpm: r.restingBpm, doses: r.dosesTaken, symptoms: r.symptoms, alerts: r.alerts + r.sos
    };
    return d;
  });
  const data: TrendData = {
    days: fillDays(days, now, span),
    insights: insights !== undefined ? insights : [],
    source: 'WATCH',
    simulated: rows.some((r: WatchDaySummary) => r.simulated) ||
      (insights !== undefined && insights.some((i: WatchInsight) => i.simulated))
  };
  return data;
}
