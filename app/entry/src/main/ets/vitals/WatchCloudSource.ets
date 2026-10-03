// Watch → phone link through Supabase. The Celia watch app (watch/) uploads small metrics to `watch_metrics`; this
// source polls new rows every 2 s and turns them into phone VitalsSamples, so the phone's own AlarmRules, chart and
// SOS flow run on real watch data. Only events the phone cannot derive from samples (SOS, fall, slow recovery,
// low SpO2) are forwarded as alerts. Nothing personal is sent: the request carries only the watch's device id.

import { AlertSeverity, VitalsAlert, VitalsSample, VitalsSourceKind } from '../model/Vitals';
import { Config } from '../common/Config';
import { getJson, NetResult } from '../common/Net';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('WatchCloud');

const POLL_MS: number = 2000;
const BATCH: number = 200;
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
}

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

  static toAlert(r: MetricRow): VitalsAlert | undefined {
    const ts: number = Date.parse(r.recorded_at);
    const p: Record<string, Object> = r.payload;
    const hr: number = num(p, 'bpm') ?? 0;
    switch (r.type) {
      case 'sos': {
        const why: string = str(p, 'reason') === 'fall' ? 'after a fall with no answer' : 'the wearer asked for help';
        return alertOf(ts, hr, 'CRITICAL', `SOS from your watch: ${why}. Check on them now.`);
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
      case 'vitals_alert':
        if (str(p, 'signal') === 'spo2') {
          return alertOf(ts, 0, 'WARN', `Oxygen saturation low on the watch: ${num(p, 'value') ?? 0}% (simulated signal).`);
        }
        return undefined;
      default:
        return undefined;
    }
  }

  private async poll(): Promise<void> {
    if (this.inFlight || this.cb === undefined) {
      return;
    }
    this.inFlight = true;
    try {
      if (this.lastId < 0) {
        await this.bootstrap();
      } else {
        await this.fetchNew();
      }
    } finally {
      this.inFlight = false;
    }
  }

  // Start after the newest existing row (no replay of old alerts), but pick up the latest extras.
  private async bootstrap(): Promise<void> {
    const dev: string = Config.WATCH_DEVICE_ID;
    const res: NetResult = await getJson(`/rest/v1/watch_metrics?device_id=eq.${dev}&select=id&order=id.desc&limit=1`,
      Config.DRUG_CHECK_TIMEOUT_MS, !this.ledgered);
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
      '&select=id,type,payload,recorded_at,source', Config.DRUG_CHECK_TIMEOUT_MS, false);
    if (v.ok) {
      this.apply(v.body, false);
    }
  }

  private async fetchNew(): Promise<void> {
    const path: string = `/rest/v1/watch_metrics?device_id=eq.${Config.WATCH_DEVICE_ID}&id=gt.${this.lastId}` +
      `&select=id,type,payload,recorded_at,source&order=id.asc&limit=${BATCH}`;
    const res: NetResult = await getJson(path, Config.DRUG_CHECK_TIMEOUT_MS, false);
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
    }
  }
}
