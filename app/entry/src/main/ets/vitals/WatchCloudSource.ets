// Watch → phone link through Supabase. The Celia watch app (watch/) uploads small metrics to `watch_metrics`; this
// source polls new rows every 2 s and turns them into phone VitalsSamples for the chart and SOS flow. Alerts are the
// watch's own decisions (hr_alert, rhythm_alert, vitals_alert, SOS, fall, slow recovery) forwarded as is; the phone
// does not re-run its AlarmRules on watch data. Nothing personal is sent: the request carries only the device id.

import { AlertSeverity, VitalsAlert, VitalsSample, VitalsSourceKind } from '../model/Vitals';
import { Config } from '../common/Config';
import { getJson, NetResult, NetTarget } from '../common/Net';
import { WatchSource } from './WatchSource';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('WatchCloud');

const POLL_MS: number = 2000;
const BATCH: number = 200;
// At start the live chart is filled with the watch's last few minutes instead of starting empty.
const BACKFILL_MS: number = 5 * 60 * 1000;
const BACKFILL_ROWS: number = 90;
// The phone's AlarmRules treat > 60 steps in the last minute as exertion; the watch reports activity directly.
const ACTIVE_STEPS: number = 120;

/** One `watch_metrics` row as returned by PostgREST. `payload` shape depends on `type` (watch/model/WatchMetric). */
export interface MetricRow {
  id: number;
  type: string;
  payload: Record<string, Object>;
  recorded_at: string;
  source: string;
}

interface IdRow {
  id: number;
}

export interface WatchCloudCallbacks {
  onSample: (s: VitalsSample) => void;
  onAlert: (a: VitalsAlert) => void;
  /** A "How do you feel?" answer given on the watch: 'fine', 'dizziness', 'palpitations', 'fainting' or 'other'. */
  onAnswer: (kind: string) => void;
  /** The watch's recent heart-rate readings at start, oldest first, for history only (no alerts, no listeners). */
  onBackfill: (samples: VitalsSample[]) => void;
}

const ANSWER_KINDS: string[] = ['fine', 'dizziness', 'palpitations', 'fainting', 'other'];

function num(p: Record<string, Object>, key: string): number | undefined {
  const v: Object | undefined = p[key];
  return typeof v === 'number' ? v : undefined;
}

function str(p: Record<string, Object>, key: string): string {
  const v: Object | undefined = p[key];
  return typeof v === 'string' ? v : '';
}

function bool(p: Record<string, Object>, key: string): boolean | undefined {
  const v: Object | undefined = p[key];
  return typeof v === 'boolean' ? v : undefined;
}

function alertOf(ts: number, hr: number, severity: AlertSeverity, message: string): VitalsAlert {
  const a: VitalsAlert = { ts: ts, kind: 'HR_ALARM_FROM_WATCH', hr: hr, message: message, severity: severity };
  return a;
}

export class WatchCloudSource {
  private lastId: number = -1;
  private timer: number = -1;
  private inFlight: boolean = false;
  private ledgered: boolean = false;
  private cb: WatchCloudCallbacks | undefined = undefined;
  // Latest slow-changing extras from `vitals` rows, attached to every live sample.
  private hrv: number | undefined = undefined;
  private restingHr: number | undefined = undefined;
  private irregular: boolean | undefined = undefined;

  start(cb: WatchCloudCallbacks): void {
    this.cb = cb;
    this.poll();
    this.timer = setInterval(() => this.poll(), POLL_MS);
    log.info(`polling watch ${Config.WATCH_DEVICE_ID}`);
  }

  stop(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  // Pure mapping, exported for tests: a row → sample and/or alert.
  static toSample(r: MetricRow, hrv: number | undefined, restingHr: number | undefined,
    irregular: boolean | undefined): VitalsSample | undefined {
    if (r.type !== 'hr_live') {
      return undefined;
    }
    const bpm: number | undefined = num(r.payload, 'bpm');
    if (bpm === undefined || bpm <= 0) {
      return undefined;
    }
    const activity: string = str(r.payload, 'activity');
    const source: VitalsSourceKind = r.source === 'watch' ? 'WATCH' : 'SIMULATED';
    const liveHrv: number | undefined = num(r.payload, 'hrvMs');
    const liveIrregular: boolean | undefined = bool(r.payload, 'irregular');
    const s: VitalsSample = {
      ts: Date.parse(r.recorded_at),
      hr: bpm,
      source: source,
      hrv: liveHrv ?? hrv,
      restingHr: restingHr,
      asleep: activity === 'ASLEEP',
      irregular: liveIrregular ?? irregular,
      steps: activity === 'ACTIVE' ? ACTIVE_STEPS : 0
    };
    return s;
  }

  // The watch is the one place that decides a heart rate is out of range (its limits know the activity, genotype
  // and risky drug, and it waits ALERT_SUSTAIN_SEC). The phone shows that decision instead of re-deciding it.
  static hrAlert(ts: number, hr: number, p: Record<string, Object>): VitalsAlert | undefined {
    const limit: number = num(p, 'limitBpm') ?? 0;
    const secs: number = num(p, 'sustainedSec') ?? 0;
    const activity: string = str(p, 'activity');
    const when: string = activity === 'ASLEEP' ? 'while asleep' : activity === 'ACTIVE' ? 'while active' :
      activity === 'REST' ? 'while resting' : '';
    const lasted: string = secs > 0 ? ` for ${secs} s` : '';
    if (str(p, 'direction') === 'low') {
      return alertOf(ts, hr, hr > 0 && hr <= 40 ? 'CRITICAL' : 'WARN',
        `Heart rate ${hr} ${when}${lasted}, below your watch limit of ${limit}. Are you OK?`.replace('  ', ' '));
    }
    if (str(p, 'direction') === 'high') {
      return alertOf(ts, hr, hr >= 150 || (limit > 0 && hr >= limit + 30) ? 'CRITICAL' : 'WARN',
        `Heart rate ${hr} ${when}${lasted}, above your watch limit of ${limit}. Sit or lie down. Are you OK?`
          .replace('  ', ' '));
    }
    return undefined;
  }

  /** Backfill rows (newest first, as fetched) → samples oldest first. Rows that aren't a live reading are skipped. */
  static backfill(body: string, hrv: number | undefined, restingHr: number | undefined,
    irregular: boolean | undefined): VitalsSample[] {
    let rows: MetricRow[] = [];
    try {
      rows = JSON.parse(body) as MetricRow[];
    } catch (e) {
      return [];
    }
    if (!Array.isArray(rows)) {
      return [];
    }
    const out: VitalsSample[] = [];
    for (const r of rows) {
      if (typeof r.id !== 'number' || r.payload === null || typeof r.payload !== 'object') {
        continue;
      }
      const s: VitalsSample | undefined = WatchCloudSource.toSample(r, hrv, restingHr, irregular);
      if (s !== undefined && !isNaN(s.ts)) {
        out.push(s);
      }
    }
    return out.sort((a: VitalsSample, b: VitalsSample) => a.ts - b.ts);
  }

  /** The watch's check-in answer in a `symptom` row, or undefined for any other row. */
  static answerOf(r: MetricRow): string | undefined {
    if (r.type !== 'symptom') {
      return undefined;
    }
    const kind: string = str(r.payload, 'kind');
    return ANSWER_KINDS.includes(kind) ? kind : undefined;
  }

  static toAlert(r: MetricRow): VitalsAlert | undefined {
    const ts: number = Date.parse(r.recorded_at);
    const p: Record<string, Object> = r.payload;
    const hr: number = num(p, 'bpm') ?? 0;
    switch (r.type) {
      case 'sos': {
        const why: string = str(p, 'reason') === 'fall' ? 'after a fall with no answer' : 'the wearer asked for help';
        const a: VitalsAlert = alertOf(ts, hr, 'CRITICAL', `SOS from your watch: ${why}. Check on them now.`);
        a.watchSos = { reason: str(p, 'reason'), withLocation: num(p, 'lat') !== undefined && num(p, 'lon') !== undefined };
        return a;
      }
      case 'fall_detected': {
        const resp: string = str(p, 'response');
        if (resp === 'ok') {
          return alertOf(ts, hr, 'WARN', 'The watch detected a fall. They answered "I\'m OK".');
        }
        // need_help / no_response: the watch follows up with an `sos` row; this one is informational.
        return alertOf(ts, hr, 'WARN', 'The watch detected a fall and they did not confirm they are OK.');
      }
      case 'hr_recovery':
        if (bool(p, 'slow') === true) {
          const drop: number = num(p, 'dropBpm') ?? 0;
          return alertOf(ts, num(p, 'bpmAfter60s') ?? 0, 'WARN',
            `Slow heart-rate recovery after exercise: only −${drop} bpm in 1 minute. Rest; mention it to your doctor.`);
        }
        return undefined;
      case 'hr_alert':
        return WatchCloudSource.hrAlert(ts, hr, p);
      case 'rhythm_alert':
        return alertOf(ts, hr, hr >= 150 || (hr > 0 && hr <= 40) ? 'CRITICAL' : 'WARN',
          `Irregular rhythm flagged by the watch at ${hr} bpm (simulated signal). Sit down. Are you OK?`);
      case 'vitals_alert':
        if (str(p, 'signal') === 'spo2') {
          return alertOf(ts, 0, 'WARN', `Oxygen saturation low on the watch: ${num(p, 'value') ?? 0}% (simulated signal).`);
        }
        if (str(p, 'signal') === 'hrv') {
          return alertOf(ts, 0, 'INFO', `Heart-rate variability low on the watch: ${num(p, 'value') ?? 0} ms (simulated signal).`);
        }
        return undefined;
      default:
        return undefined;
    }
  }

  private async poll(): Promise<void> {
    const target: NetTarget | undefined = WatchSource.target();
    if (this.inFlight || this.cb === undefined || target === undefined) {
      return;
    }
    this.inFlight = true;
    try {
      if (this.lastId < 0) {
        await this.bootstrap(target);
      } else {
        await this.fetchNew(target);
      }
    } finally {
      this.inFlight = false;
    }
  }

  // Start after the newest existing row (no replay of old alerts), but pick up the latest extras and the last few
  // minutes of readings for the chart.
  private async bootstrap(target: NetTarget): Promise<void> {
    const dev: string = Config.WATCH_DEVICE_ID;
    const res: NetResult = await getJson(`/rest/v1/watch_metrics?device_id=eq.${dev}&select=id&order=id.desc&limit=1`,
      Config.DRUG_CHECK_TIMEOUT_MS, !this.ledgered, target);
    this.ledgered = true;
    if (!res.ok) {
      return;
    }
    try {
      const rows: IdRow[] = JSON.parse(res.body) as IdRow[];
      this.lastId = rows.length > 0 && typeof rows[0].id === 'number' ? rows[0].id : 0;
    } catch (e) {
      log.warn(`bad bootstrap response: ${JSON.stringify(e)}`);
      return;
    }
    const v: NetResult = await getJson(`/rest/v1/watch_metrics_latest?device_id=eq.${dev}&type=eq.vitals` +
      '&select=id,type,payload,recorded_at,source', Config.DRUG_CHECK_TIMEOUT_MS, false, target);
    if (v.ok) {
      this.apply(v.body, false);
    }
    // Rows up to lastId only: anything newer comes through fetchNew, so nothing is shown twice.
    const since: string = new Date(Date.now() - BACKFILL_MS).toISOString();
    const b: NetResult = await getJson(`/rest/v1/watch_metrics?device_id=eq.${dev}&type=eq.hr_live` +
      `&id=lte.${this.lastId}&recorded_at=gte.${since}&select=id,type,payload,recorded_at,source` +
      `&order=id.desc&limit=${BACKFILL_ROWS}`, Config.DRUG_CHECK_TIMEOUT_MS, false, target);
    if (b.ok && this.cb !== undefined) {
      const samples: VitalsSample[] = WatchCloudSource.backfill(b.body, this.hrv, this.restingHr, this.irregular);
      if (samples.length > 0) {
        this.cb.onBackfill(samples);
      }
    }
  }

  private async fetchNew(target: NetTarget): Promise<void> {
    const path: string = `/rest/v1/watch_metrics?device_id=eq.${Config.WATCH_DEVICE_ID}&id=gt.${this.lastId}` +
      `&select=id,type,payload,recorded_at,source&order=id.asc&limit=${BATCH}`;
    const res: NetResult = await getJson(path, Config.DRUG_CHECK_TIMEOUT_MS, false, target);
    if (res.ok) {
      this.apply(res.body, true);
    }
  }

  private apply(body: string, emit: boolean): void {
    let rows: MetricRow[] = [];
    try {
      rows = JSON.parse(body) as MetricRow[];
    } catch (e) {
      log.warn(`bad watch_metrics response: ${JSON.stringify(e)}`);
      return;
    }
    if (!Array.isArray(rows)) {
      return;
    }
    for (const r of rows) {
      if (typeof r.id !== 'number' || typeof r.type !== 'string' || r.payload === null || typeof r.payload !== 'object') {
        continue;
      }
      this.lastId = Math.max(this.lastId, r.id);
      if (r.type === 'vitals') {
        this.hrv = num(r.payload, 'hrvMs');
        this.restingHr = num(r.payload, 'restingBpm');
        this.irregular = bool(r.payload, 'irregularRhythm');
      }
      if (!emit || this.cb === undefined) {
        continue;
      }
      const s: VitalsSample | undefined = WatchCloudSource.toSample(r, this.hrv, this.restingHr, this.irregular);
      if (s !== undefined) {
        this.cb.onSample(s);
      }
      const a: VitalsAlert | undefined = WatchCloudSource.toAlert(r);
      if (a !== undefined) {
        this.cb.onAlert(a);
      }
      const answer: string | undefined = WatchCloudSource.answerOf(r);
      if (answer !== undefined) {
        this.cb.onAnswer(answer);
      }
    }
  }
}
