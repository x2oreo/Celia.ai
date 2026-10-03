import { Activity } from '../model/WatchMetric';

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
