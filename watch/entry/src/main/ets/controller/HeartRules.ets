import { Logger } from '../common/Logger';
import {
  Activity,
  HrAlertValues,
  HrLiveValues,
  HrRecoveryValues,
  MetricPayload,
  MetricType,
  RhythmAlertValues,
  VitalSignal,
  VitalsAlertValues,
  VitalsValues
} from '../model/WatchMetric';
import { AlarmRules, AlarmTiming } from '../vitals/AlarmRules';
import { shortDrugName } from '../vitals/DrugBadge';
import { HrLimits, isStressed } from '../vitals/Limits';
import {
  ANOMALY_SUSTAIN_MS,
  ANOMALY_TOTAL_MS,
  Anomaly,
  anomalyProgress,
  applyAnomaly,
  mockVitals,
  vitalAlertFor
} from '../vitals/MockedVitals';
import { RecoveryTracker } from '../vitals/RecoveryTracker';
import { RestingHr } from '../vitals/RestingHr';
import { SessionStats } from '../vitals/SessionStats';

/** Which alert screen is up. */
export type AlertKind = 'NONE' | 'HIGH' | 'LOW' | 'RHYTHM' | 'RECOVERY' | 'HRV' | 'SPO2';

const LIVE_EVERY_MS = 5000;
const VITALS_EVERY_MS = 30000;
const MOCK_EVERY_MS = 1000;
const VITAL_ALERT_COOLDOWN_MS = 60000;
/** Monitoring is continuous, so summaries are sent per window instead of per start/stop. */
export const SUMMARY_WINDOW_MS = 5 * 60 * 1000;

/** What the rules need from the controller: rows, alert screens, vibration and the vitals snapshot. */
export interface RulesHost {
  record(type: MetricType, payload: MetricPayload, tsMs: number): void;

  showAlert(kind: AlertKind, value: number, detail: string): void;

  vibrate(durationMs: number): void;

  vitalsSnapshot(): VitalsValues;
}

/** One valid reading, once a second. `logicMs` is scenario time in demo mode (fast-forwarded), wall clock else. */
export interface Reading {
  nowMs: number;
  logicMs: number;
  bpm: number;
  activity: Activity;
  limits: HrLimits;
  /** Recently taken QT-risk drug, '' if none (names the reason for a lowered high limit). */
  riskyDrug: string;
}

/**
 * The deterministic rules on each reading: resting HR, stress, simulated vitals and their alerts, recovery after
 * exercise, heart rate outside the current limits, and the periodic `hr_live` / `vitals` / `hr_session` rows.
 */
@ObservedV2
export class HeartRules {
  @Trace restingBpm: number = 65;
  @Trace restingMeasured: boolean = false;
  @Trace stress: boolean = false;
  @Trace hrvMs: number = 0;
  @Trace spo2: number = 0;
  @Trace breathingRate: number = 0;
  @Trace irregularRhythm: boolean = false;
  @Trace lastRecovery: string = '';
  /** Signal currently forced abnormal from the Vitals page. */
  @Trace anomaly: Anomaly = 'none';

  private host: RulesHost;
  private rand: () => number;
  private sustainSec: number = 5;
  private alarm: AlarmRules = new AlarmRules(AlarmRules.defaultTiming());
  private resting: RestingHr = new RestingHr(65);
  private recovery: RecoveryTracker = new RecoveryTracker();
  private window: SessionStats = new SessionStats();
  private windowStartMs: number = 0;
  private lastLiveMs: number = 0;
  private lastVitalsMs: number = 0;
  private lastMockMs: number = 0;
  private anomalyStartMs: number = 0;
  private lastVitalAlertMs: number = 0;
  /** When HRV/SpO2 first went past its threshold; -1 = not past it. Same sustain rule as heart rate. */
  private vitalLowSinceMs: number = -1;

  constructor(host: RulesHost, rand: () => number) {
    this.host = host;
    this.rand = rand;
  }

  configure(sustainSec: number, restingBpm: number): void {
    this.sustainSec = sustainSec;
    const timing: AlarmTiming = { sustainSec: sustainSec, cooldownSec: 60 };
    this.alarm = new AlarmRules(timing);
    this.resting = new RestingHr(restingBpm);
    this.restingBpm = restingBpm;
  }

  /** Monitoring (re)started: fresh trackers and cadences. */
  start(now: number): void {
    this.alarm.reset();
    this.irregularRhythm = false;
    this.lastLiveMs = 0;
    this.lastVitalsMs = now;
    this.lastMockMs = 0;
    this.windowStartMs = now;
    this.window = new SessionStats();
    this.recovery = new RecoveryTracker();
  }

  /** Watch taken off or put on: a sustained-limit timer must not span it. */
  resetAlarm(): void {
    this.alarm.reset();
  }

  /** True when the 5-minute summary window is over. */
  windowDue(now: number): boolean {
    return now - this.windowStartMs >= SUMMARY_WINDOW_MS;
  }

  /** Window summary as an `hr_session` row, then start a new window. */
  flushWindow(nowMs: number): void {
    const summary = this.window.summary();
    if (summary !== undefined) {
      this.host.record('hr_session', summary, nowMs);
    }
    this.window = new SessionStats();
    this.windowStartMs = nowMs;
  }

  /** Vitals page tile tapped: that simulated signal drifts abnormal, holds and recovers. */
  startAnomaly(kind: Anomaly, now: number): void {
    this.anomaly = kind;
    this.anomalyStartMs = now;
    this.lastVitalAlertMs = 0;
    this.vitalLowSinceMs = -1;
  }

  /** True while a tapped anomaly still ramps (+ sustain + 1 s): the controller refreshes it faster then. */
  anomalyRamping(now: number, rampMs: number): boolean {
    return now - this.anomalyStartMs <= rampMs + ANOMALY_SUSTAIN_MS + 1000;
  }

  process(r: Reading): void {
    const now = r.nowMs;
    const t = r.logicMs;
    this.window.add(r.bpm, now);
    this.resting.add(r.bpm, t, r.activity);
    this.restingBpm = this.resting.value;
    this.restingMeasured = this.resting.measured;
    if (now - this.lastMockMs >= MOCK_EVERY_MS) {
      this.lastMockMs = now;
      this.updateMockedVitals(r.bpm, r.activity, now);
    }
    this.stress = isStressed(r.bpm, this.restingBpm, r.activity, this.hrvMs);
    if (now - this.lastLiveMs >= LIVE_EVERY_MS) {
      this.lastLiveMs = now;
      const live: HrLiveValues = { bpm: r.bpm, activity: r.activity };
      if (this.hrvMs > 0) {
        live.hrvMs = this.hrvMs;
      }
      live.irregular = this.irregularRhythm;
      this.host.record('hr_live', live, now);
    }
    if (now - this.lastVitalsMs >= VITALS_EVERY_MS) {
      this.lastVitalsMs = now;
      this.host.record('vitals', this.host.vitalsSnapshot(), now);
    }
    const rec = this.recovery.add(r.bpm, t, r.activity);
    if (rec !== undefined) {
      this.onRecovery(rec, now);
    }
    const alert = this.alarm.evaluate(r.bpm, t, r.limits, r.activity);
    if (alert !== undefined) {
      this.raiseAlert(alert, now, r);
    }
  }

  /** Simulated HRV / SpO2 / breathing / rhythm (Huawei measures them; watch apps can't read them yet). */
  updateMockedVitals(bpm: number, activity: Activity, now: number): void {
    const elapsed = now - this.anomalyStartMs;
    if (this.anomaly !== 'none' && elapsed >= ANOMALY_TOTAL_MS) {
      this.anomaly = 'none';
    }
    const m = applyAnomaly(mockVitals(bpm, activity, this.rand), this.anomaly,
      this.anomaly === 'none' ? 0 : anomalyProgress(elapsed), this.rand);
    this.hrvMs = m.hrvMs;
    this.spo2 = m.spo2;
    this.breathingRate = m.breathingRate;
    if (m.irregularRhythm && !this.irregularRhythm) {
      const v: RhythmAlertValues = { bpm: bpm, activity: activity, mocked: true };
      this.host.record('rhythm_alert', v, now);
      this.host.showAlert('RHYTHM', bpm, 'Simulated signal. Sit down now.');
      this.host.vibrate(1500);
      Logger.info('irregular rhythm (simulated)');
    }
    this.irregularRhythm = m.irregularRhythm;
    const signal = vitalAlertFor(m, activity);
    if (signal === undefined) {
      this.vitalLowSinceMs = -1;
      return;
    }
    if (this.vitalLowSinceMs < 0) {
      this.vitalLowSinceMs = now;
    }
    const sustainMs = this.anomaly !== 'none' ? ANOMALY_SUSTAIN_MS : this.sustainSec * 1000;
    const sustained = now - this.vitalLowSinceMs >= sustainMs;
    if (sustained && now - this.lastVitalAlertMs >= VITAL_ALERT_COOLDOWN_MS) {
      this.lastVitalAlertMs = now;
      this.raiseVitalAlert(signal, signal === 'hrv' ? m.hrvMs : m.spo2, activity, now);
    }
  }

  private raiseVitalAlert(signal: VitalSignal, value: number, activity: Activity, now: number): void {
    const v: VitalsAlertValues = { signal: signal, value: value, activity: activity, mocked: true };
    this.host.record('vitals_alert', v, now);
    if (signal === 'hrv') {
      this.host.showAlert('HRV', value, 'Simulated signal. Sit down and breathe slowly.');
    } else {
      this.host.showAlert('SPO2', value, 'Simulated signal. Sit up and breathe slowly.');
    }
    this.host.vibrate(1200);
    Logger.info(`vitals alert: ${signal}`);
  }

  private onRecovery(rec: HrRecoveryValues, now: number): void {
    this.host.record('hr_recovery', rec, now);
    this.lastRecovery = `${rec.peakBpm}→${rec.bpmAfter60s} (−${rec.dropBpm})${rec.slow ? ' slow' : ''}`;
    if (rec.slow) {
      this.host.showAlert('RECOVERY', rec.bpmAfter60s,
        `Only −${rec.dropBpm} bpm in 1 min after exercise. Rest and tell your doctor.`);
      this.host.vibrate(800);
    }
    Logger.info(`recovery: ${this.lastRecovery}`);
  }

  private raiseAlert(alert: HrAlertValues, tsMs: number, r: Reading): void {
    // A lowered high limit says which drug lowered it (the reason alone only says "drug").
    const why = alert.direction === 'high' && r.riskyDrug.length > 0 ?
      `lowered for ${shortDrugName(r.riskyDrug)}` : r.limits.reason;
    const detail = `Limit ${alert.limitBpm} · ${why}`;
    this.host.showAlert(alert.direction === 'high' ? 'HIGH' : 'LOW', alert.bpm, detail);
    this.host.record('hr_alert', alert, tsMs);
    if (alert.direction === 'low' && alert.activity === 'ASLEEP') {
      this.host.vibrate(400);
    } else {
      this.host.vibrate(1200);
    }
    Logger.info(`alert: ${detail}`);
  }
}
