import { Activity, VitalSignal } from '../model/WatchMetric';

/**
 * Plausible values for signals Huawei watches measure but third-party apps can't read yet (HRV, rhythm, SpO2,
 * breathing rate). Always labelled "simulated" in UI and data (`mocked`). Deterministic given the random source,
 * so it can be unit-tested.
 */
export interface MockVitals {
  hrvMs: number;
  spo2: number;
  breathingRate: number;
  irregularRhythm: boolean;
}

export const MOCKED_FIELDS: string[] = ['hrvMs', 'spo2', 'breathingRate', 'irregularRhythm'];

/** Simulate page / Vitals tiles can force one signal abnormal for a while. */
export type Anomaly = 'none' | 'hrv' | 'spo2' | 'rhythm' | 'hr';

/** Low HRV while not exercising suggests strong sympathetic (stress) drive, a known LQT1/LQT2 trigger context. */
export const HRV_LOW_MS = 20;
export const SPO2_LOW = 92;

/** Very fast heart rate without exertion is treated as a possible arrhythmia in the simulation (TdP story). */
const IRREGULAR_AT_REST_BPM = 170;

export function mockVitals(bpm: number, activity: Activity, rand: () => number): MockVitals {
  const jitter = (range: number): number => (rand() - 0.5) * range;
  let hrv = 45;
  let breathing = 14;
  let spo2 = 97.5;
  if (activity === 'ACTIVE') {
    hrv = 20;
    breathing = 24;
    spo2 = 96.5;
  } else if (activity === 'ASLEEP') {
    hrv = 60;
    breathing = 12;
    spo2 = 95.5;
  }
  // Higher HR → lower HRV, faster breathing.
  if (bpm > 0) {
    hrv = hrv * Math.min(1.3, Math.max(0.4, 70 / bpm));
    breathing = breathing + Math.max(0, (bpm - 90) / 15);
  }
  if (bpm > 0 && bpm < 42) {
    spo2 -= 3;
  }
  const irregular = activity !== 'ACTIVE' && bpm >= IRREGULAR_AT_REST_BPM;
  const v: MockVitals = {
    hrvMs: Math.max(5, Math.round(hrv + jitter(6))),
    spo2: Math.min(100, Math.round((spo2 + jitter(1)) * 10) / 10),
    breathingRate: Math.round(breathing + jitter(2)),
    irregularRhythm: irregular
  };
  return v;
}

/** A tapped anomaly drifts in, holds, then drifts back, so the demo looks like a real deterioration. */
export const ANOMALY_RAMP_MS = 2500;
export const ANOMALY_HOLD_MS = 10000;
export const ANOMALY_RECOVER_MS = 4000;
/** A tapped (demo) anomaly only has to stay past the threshold this long, so the alert lands ~3 s after the tap. */
export const ANOMALY_SUSTAIN_MS = 1000;
export const ANOMALY_TOTAL_MS = ANOMALY_RAMP_MS + ANOMALY_HOLD_MS + ANOMALY_RECOVER_MS;

/** 0 = normal, 1 = fully abnormal, `elapsedMs` after the tap. */
export function anomalyProgress(elapsedMs: number): number {
  if (elapsedMs <= 0 || elapsedMs >= ANOMALY_TOTAL_MS) {
    return 0;
  }
  if (elapsedMs < ANOMALY_RAMP_MS) {
    return elapsedMs / ANOMALY_RAMP_MS;
  }
  if (elapsedMs < ANOMALY_RAMP_MS + ANOMALY_HOLD_MS) {
    return 1;
  }
  return 1 - (elapsedMs - ANOMALY_RAMP_MS - ANOMALY_HOLD_MS) / ANOMALY_RECOVER_MS;
}

function lerp(from: number, to: number, k: number): number {
  return from + (to - from) * k;
}

/** Blends the chosen signal from its normal value towards an abnormal one by `progress` (demo). */
export function applyAnomaly(v: MockVitals, anomaly: Anomaly, progress: number, rand: () => number): MockVitals {
  if (progress <= 0) {
    return v;
  }
  if (anomaly === 'hrv') {
    v.hrvMs = Math.max(5, Math.round(lerp(v.hrvMs, 11 + rand() * 2, progress)));
    v.breathingRate = Math.round(lerp(v.breathingRate, 20, progress));
  } else if (anomaly === 'spo2') {
    v.spo2 = Math.round(lerp(v.spo2, 88.5 + rand() * 0.6, progress) * 10) / 10;
    v.breathingRate = Math.round(lerp(v.breathingRate, 22, progress));
  } else if (anomaly === 'rhythm') {
    // Rhythm is yes/no: it becomes irregular once the episode is well under way.
    v.irregularRhythm = v.irregularRhythm || progress >= 0.6;
  }
  return v;
}

/** A tapped heart-rate anomaly ends this far above the current high limit, so it crosses it in any state. */
export const HR_ANOMALY_ABOVE_LIMIT = 15;

/**
 * Demo heart rate while the Heart tile's anomaly runs: drifts from the sensor reading to the current high limit +
 * HR_ANOMALY_ABOVE_LIMIT and back (same curve as the other tiles). The normal alarm rule then decides the alert.
 */
export function hrAnomalyBpm(sensorBpm: number, limitHigh: number, progress: number): number {
  if (progress <= 0) {
    return sensorBpm;
  }
  const target = Math.max(sensorBpm, limitHigh + HR_ANOMALY_ABOVE_LIMIT);
  return Math.round(lerp(sensorBpm, target, Math.min(1, progress)));
}

/** Deterministic rule on the (simulated) inputs: which vital, if any, needs an alert. */
export function vitalAlertFor(v: MockVitals, activity: Activity): VitalSignal | undefined {
  if (v.spo2 > 0 && v.spo2 < SPO2_LOW) {
    return 'spo2';
  }
  if (activity !== 'ACTIVE' && v.hrvMs > 0 && v.hrvMs < HRV_LOW_MS) {
    return 'hrv';
  }
  return undefined;
}
