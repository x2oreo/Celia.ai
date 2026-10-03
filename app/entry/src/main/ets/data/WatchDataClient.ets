// Read-only client for the watch views in Supabase (docs/team/watch-data-for-phone.md). Not wired to any screen
// yet: callers decide how to use it. Every fetch returns `undefined` when the request failed (no backend, network,
// bad response) and `[]` when it worked but there is no data, so callers can tell "offline" from "nothing yet".
// The parse* functions are pure and unit-tested; they drop rows that don't match the expected shape.

import { Config } from '../common/Config';
import { getJson, NetResult, NetTarget } from '../common/Net';
import { WatchSource } from '../vitals/WatchSource';
import { Logger } from '../common/Logger';
import {
  WatchDaySummary, WatchDose, WatchInsight, WatchInsightKind, WatchInsightSeverity, WatchStatus, WatchSymptom,
  WatchSymptomKind, WatchVitalsDay, WatchWearStatus
} from '../model/WatchData';

const log: Logger = new Logger('WatchData');

// Rows as PostgREST returns them (snake_case). Fields are checked before use.
interface StatusRow {
  status: string;
  on_wrist: boolean;
  last_sync: string;
  wear_changed_at: string | null;
}

interface DoseRow {
  id: number;
  name: string;
  taken_at: string;
  day: string;
  simulated: boolean;
}

interface SymptomRow {
  id: number;
  kind: string;
  bpm: number;
  recorded_at: string;
  simulated: boolean;
}

interface DaySummaryRow {
  day: string;
  doses_taken: number;
  first_dose_at: string | null;
  symptoms: number;
  symptom_kinds: string[] | null;
  fine_check_ins: number;
  alerts: number;
  falls: number;
  sos: number;
  resting_bpm: number | null;
  simulated: boolean;
}

interface InsightRow {
  kind: string;
  severity: string;
  ts: string;
  message: string;
  simulated: boolean;
}

interface VitalsDayRow {
  day: string;
  avg_bpm: number | null;
  min_bpm: number | null;
  max_bpm: number | null;
  hrv_ms: number | null;
  spo2: number | null;
  breathing_rate: number | null;
  sleep_minutes: number | null;
  stress_minutes: number | null;
  steps: number | null;
  simulated: boolean;
}

const WEAR_STATUSES: string[] = ['ON_WRIST', 'OFF_WRIST', 'OFFLINE'];
const SYMPTOM_KINDS: string[] = ['fine', 'palpitations', 'dizziness', 'fainting', 'other'];
const INSIGHT_KINDS: string[] = ['SYMPTOM_AFTER_RISKY_DRUG', 'FAINTING_REPORTED', 'REPEATED_SYMPTOMS', 'NO_DOSE_LOGGED'];
const SEVERITIES: string[] = ['CRITICAL', 'WARN', 'INFO'];
const DAY_RE: RegExp = new RegExp('^\\d{4}-\\d{2}-\\d{2}$');

function time(v: string | null | undefined): number {
  if (typeof v !== 'string') {
    return 0;
  }
  const t: number = Date.parse(v);
  return isNaN(t) ? 0 : t;
}

function count(v: number | null | undefined): number {
  return typeof v === 'number' && isFinite(v) && v >= 0 ? Math.round(v) : 0;
}

/** JSON array from a response body, or undefined if it isn't one. */
function rowsOf<T>(body: string): T[] | undefined {
  try {
    const parsed: T[] = JSON.parse(body) as T[];
    return Array.isArray(parsed) ? parsed : undefined;
  } catch (e) {
    log.warn(`bad JSON: ${JSON.stringify(e)}`);
    return undefined;
  }
}

export function parseStatus(body: string): WatchStatus[] | undefined {
  const rows: StatusRow[] | undefined = rowsOf<StatusRow>(body);
  if (rows === undefined) {
    return undefined;
  }
  const out: WatchStatus[] = [];
  for (const r of rows) {
    if (typeof r.status !== 'string' || !WEAR_STATUSES.includes(r.status) || time(r.last_sync) === 0) {
      continue;
    }
    const s: WatchStatus = {
      status: r.status as WatchWearStatus,
      onWrist: r.on_wrist !== false,
      lastSync: time(r.last_sync),
      wearChangedAt: time(r.wear_changed_at)
    };
    out.push(s);
  }
  return out;
}

export function parseDoses(body: string): WatchDose[] | undefined {
  const rows: DoseRow[] | undefined = rowsOf<DoseRow>(body);
  if (rows === undefined) {
    return undefined;
  }
  const out: WatchDose[] = [];
  for (const r of rows) {
    if (typeof r.id !== 'number' || typeof r.name !== 'string' || r.name.length === 0 || time(r.taken_at) === 0 ||
      typeof r.day !== 'string' || !DAY_RE.test(r.day)) {
      continue;
    }
    const d: WatchDose = { id: r.id, name: r.name, takenAt: time(r.taken_at), day: r.day, simulated: r.simulated === true };
    out.push(d);
  }
  return out;
}

export function parseSymptoms(body: string): WatchSymptom[] | undefined {
  const rows: SymptomRow[] | undefined = rowsOf<SymptomRow>(body);
  if (rows === undefined) {
    return undefined;
  }
  const out: WatchSymptom[] = [];
  for (const r of rows) {
    if (typeof r.id !== 'number' || typeof r.kind !== 'string' || !SYMPTOM_KINDS.includes(r.kind) ||
      time(r.recorded_at) === 0) {
      continue;
    }
    const s: WatchSymptom = {
      id: r.id, kind: r.kind as WatchSymptomKind, bpm: count(r.bpm), recordedAt: time(r.recorded_at),
      simulated: r.simulated === true
    };
    out.push(s);
  }
  return out;
}

export function parseDailySummary(body: string): WatchDaySummary[] | undefined {
  const rows: DaySummaryRow[] | undefined = rowsOf<DaySummaryRow>(body);
  if (rows === undefined) {
    return undefined;
  }
  const out: WatchDaySummary[] = [];
  for (const r of rows) {
    if (typeof r.day !== 'string' || !DAY_RE.test(r.day)) {
      continue;
    }
    const kinds: string[] = Array.isArray(r.symptom_kinds) ?
      r.symptom_kinds.filter((k: string) => typeof k === 'string' && SYMPTOM_KINDS.includes(k)) : [];
    const d: WatchDaySummary = {
      day: r.day,
      dosesTaken: count(r.doses_taken),
      firstDoseAt: time(r.first_dose_at),
      symptoms: count(r.symptoms),
      symptomKinds: kinds,
      fineCheckIns: count(r.fine_check_ins),
      alerts: count(r.alerts),
      falls: count(r.falls),
      sos: count(r.sos),
      restingBpm: count(r.resting_bpm),
      simulated: r.simulated === true
    };
    out.push(d);
  }
  return out;
}

export function parseInsights(body: string): WatchInsight[] | undefined {
  const rows: InsightRow[] | undefined = rowsOf<InsightRow>(body);
  if (rows === undefined) {
    return undefined;
  }
  const out: WatchInsight[] = [];
  for (const r of rows) {
    if (typeof r.kind !== 'string' || !INSIGHT_KINDS.includes(r.kind) || typeof r.severity !== 'string' ||
      !SEVERITIES.includes(r.severity) || typeof r.message !== 'string' || r.message.length === 0) {
      continue;
    }
    const i: WatchInsight = {
      kind: r.kind as WatchInsightKind,
      severity: r.severity as WatchInsightSeverity,
      ts: time(r.ts),
      message: r.message,
      simulated: r.simulated === true
    };
    out.push(i);
  }
  // CRITICAL first, then newest first.
  const rank = (s: WatchInsightSeverity): number => s === 'CRITICAL' ? 0 : s === 'WARN' ? 1 : 2;
  out.sort((a: WatchInsight, b: WatchInsight) => rank(a.severity) - rank(b.severity) || b.ts - a.ts);
  return out;
}

export function parseVitalsDaily(body: string): WatchVitalsDay[] | undefined {
  const rows: VitalsDayRow[] | undefined = rowsOf<VitalsDayRow>(body);
  if (rows === undefined) {
    return undefined;
  }
  const out: WatchVitalsDay[] = [];
  for (const r of rows) {
    if (typeof r.day !== 'string' || !DAY_RE.test(r.day)) {
      continue;
    }
    // Oxygen keeps its decimal; anything outside what a wrist can report is dropped, not shown.
    const spo2: number = typeof r.spo2 === 'number' && r.spo2 >= 50 && r.spo2 <= 100 ? Math.round(r.spo2 * 10) / 10 : 0;
    const d: WatchVitalsDay = {
      day: r.day,
      avgBpm: count(r.avg_bpm),
      minBpm: count(r.min_bpm),
      maxBpm: count(r.max_bpm),
      hrvMs: count(r.hrv_ms),
      spo2: spo2,
      breathingRate: count(r.breathing_rate),
      sleepMinutes: count(r.sleep_minutes),
      stressMinutes: count(r.stress_minutes),
      steps: count(r.steps),
      simulated: r.simulated === true
    };
    out.push(d);
  }
  return out;
}

export class WatchDataClient {
  /** Device filter for every query. Hackathon: one demo watch (Config.WATCH_DEVICE_ID). */
  private static dev(): string {
    return encodeURIComponent(Config.WATCH_DEVICE_ID);
  }

  // Reads from `target`, or from the project that holds the watch tables (WatchSource.target: the app backend when
  // it is the Supabase project, the deployed project while the AI backend is a local dev server).
  private static async get(path: string, ledger: boolean, target?: NetTarget): Promise<string | undefined> {
    const to: NetTarget | undefined = target !== undefined ? target : WatchSource.target();
    if (to === undefined) {
      return undefined;
    }
    const res: NetResult = await getJson(path, Config.DRUG_CHECK_TIMEOUT_MS, ledger, to);
    return res.ok ? res.body : undefined;
  }

  /** Current wear status, or undefined if offline / the watch never synced. Pass ledger=false when polling. */
  static async status(ledger: boolean = true): Promise<WatchStatus | undefined> {
    const body: string | undefined = await WatchDataClient.get(
      `/rest/v1/watch_status?device_id=eq.${WatchDataClient.dev()}&select=status,on_wrist,last_sync,wear_changed_at`,
      ledger);
    const rows: WatchStatus[] | undefined = body === undefined ? undefined : parseStatus(body);
    return rows !== undefined && rows.length > 0 ? rows[0] : undefined;
  }

  /** Doses taken on the watch since `sinceDay` (YYYY-MM-DD), newest first. */
  static async doses(sinceDay: string, ledger: boolean = true): Promise<WatchDose[] | undefined> {
    const since: string = DAY_RE.test(sinceDay) ? `&day=gte.${sinceDay}` : '';
    const body: string | undefined = await WatchDataClient.get(
      `/rest/v1/watch_doses?device_id=eq.${WatchDataClient.dev()}${since}` +
        '&select=id,name,taken_at,day,simulated&order=taken_at.desc&limit=200', ledger);
    return body === undefined ? undefined : parseDoses(body);
  }

  /** Latest "How do you feel?" answers, newest first. includeFine=false leaves out check-in OKs. */
  static async symptoms(limit: number, includeFine: boolean, ledger: boolean = true): Promise<WatchSymptom[] | undefined> {
    const fine: string = includeFine ? '' : '&kind=neq.fine';
    const n: number = Math.max(1, Math.min(200, Math.round(limit)));
    const body: string | undefined = await WatchDataClient.get(
      `/rest/v1/watch_symptoms?device_id=eq.${WatchDataClient.dev()}${fine}` +
        `&select=id,kind,bpm,recorded_at,simulated&order=recorded_at.desc&limit=${n}`, ledger);
    return body === undefined ? undefined : parseSymptoms(body);
  }

  /** The last `days` days that have any watch data, newest first (doctor report, agent). */
  static async dailySummary(days: number, ledger: boolean = true,
    target?: NetTarget): Promise<WatchDaySummary[] | undefined> {
    const n: number = Math.max(1, Math.min(90, Math.round(days)));
    const body: string | undefined = await WatchDataClient.get(
      `/rest/v1/watch_daily_summary?device_id=eq.${WatchDataClient.dev()}` +
        '&select=day,doses_taken,first_dose_at,symptoms,symptom_kinds,fine_check_ins,alerts,falls,sos,resting_bpm,' +
        `simulated&order=day.desc&limit=${n}`, ledger, target);
    return body === undefined ? undefined : parseDailySummary(body);
  }

  /** Current fixed-rule insights, CRITICAL first. */
  static async insights(ledger: boolean = true, target?: NetTarget): Promise<WatchInsight[] | undefined> {
    const body: string | undefined = await WatchDataClient.get(
      `/rest/v1/watch_insights?device_id=eq.${WatchDataClient.dev()}&select=kind,severity,ts,message,simulated`, ledger,
      target);
    return body === undefined ? undefined : parseInsights(body);
  }

  /** Daily vitals (heart rate range, HRV, oxygen, breathing, sleep, stress time, steps), newest first. */
  static async vitalsDaily(days: number, ledger: boolean = true,
    target?: NetTarget): Promise<WatchVitalsDay[] | undefined> {
    const n: number = Math.max(1, Math.min(90, Math.round(days)));
    const body: string | undefined = await WatchDataClient.get(
      `/rest/v1/watch_vitals_daily?device_id=eq.${WatchDataClient.dev()}` +
        '&select=day,avg_bpm,min_bpm,max_bpm,hrv_ms,spo2,breathing_rate,sleep_minutes,stress_minutes,steps,' +
        `simulated&order=day.desc&limit=${n}`, ledger, target);
    return body === undefined ? undefined : parseVitalsDaily(body);
  }
}
