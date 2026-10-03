/**
 * Metrics the watch sends to the backend (`watch_metrics` table).
 * Small, computed values only. The watch never uploads raw sensor streams.
 */

export type MetricType = 'hr_live' | 'hr_session' | 'hr_alert' | 'symptom' | 'medication_taken' | 'fall_detected' |
  'wear_state' | 'vitals' | 'hr_recovery' | 'rhythm_alert' | 'sos' | 'vitals_alert';

/** Where the heart rate came from. `simulated` must always be labelled as demo data in the UI. */
export type MetricSource = 'watch' | 'simulated';

export type HrSourceKind = 'SENSOR' | 'SIMULATED';

export type AlertDirection = 'high' | 'low';

/** What the wearer is doing: from motion, time of day and heart rate. UNKNOWN when there is no motion data. */
export type Activity = 'REST' | 'ACTIVE' | 'ASLEEP' | 'UNKNOWN';

export type Genotype = 'LQT1' | 'LQT2' | 'LQT3' | 'UNKNOWN';

export type FallResponse = 'ok' | 'need_help' | 'no_response';

export type SosReason = 'need_help' | 'fall';

/** Check-in answers ('fine' included so 'no symptoms' after an alert is recorded too). */
export type SymptomKind = 'fine' | 'palpitations' | 'dizziness' | 'fainting' | 'other';

export interface HrLiveValues {
  bpm: number;
  activity: Activity;
}

export interface HrSessionValues {
  avgBpm: number;
  maxBpm: number;
  minBpm: number;
  durationSec: number;
  samples: number;
}

export interface HrAlertValues {
  bpm: number;
  limitBpm: number;
  direction: AlertDirection;
  sustainedSec: number;
  activity: Activity;
}

export interface SymptomValues {
  kind: SymptomKind;
  /** Heart rate at the moment of logging, 0 if unknown. */
  bpm: number;
}

export interface MedicationTakenValues {
  name: string;
}

/** Hard impact followed by stillness (possible faint), and whether the wearer answered "I'm OK". */
export interface FallValues {
  /** Heart rate at the moment of the fall, 0 if unknown. */
  bpm: number;
  response: FallResponse;
  responseSec: number;
}

export interface WearStateValues {
  onWrist: boolean;
}

/**
 * Snapshot of every risk-model input, every 30 s. Fields listed in `mocked` are simulated: Huawei watches measure
 * them, but third-party apps can't read them yet (HRV, rhythm, SpO2, breathing). They show the intended design.
 */
export interface VitalsValues {
  bpm: number;
  restingBpm: number;
  activity: Activity;
  stress: boolean;
  steps: number;
  hrvMs: number;
  spo2: number;
  breathingRate: number;
  irregularRhythm: boolean;
  highLimitBpm: number;
  lowLimitBpm: number;
  genotype: Genotype;
  riskyDrug: string;
  mocked: string[];
}

/** Heart-rate recovery after exercise (LQT1): drop in the first minute after the activity peak. */
export interface HrRecoveryValues {
  peakBpm: number;
  bpmAfter60s: number;
  dropBpm: number;
  /** Drop under 12 bpm in 1 min is a commonly used "abnormal recovery" cut-off. */
  slow: boolean;
}

/**
 * The SOS countdown ran out (user asked for help, or didn't answer after a fall). The phone app / agent reacts to
 * this row: notify emergency contacts and offer to call 112. The watch itself does not dial.
 */
export interface SosValues {
  reason: SosReason;
  bpm: number;
  activity: Activity;
  /** WGS84 position at SOS time; omitted when location is denied or unavailable. */
  lat?: number;
  lon?: number;
  accuracyM?: number;
}

export type VitalSignal = 'hrv' | 'spo2';

/** Low HRV or low SpO2. These inputs are simulated today (see VitalsValues.mocked). */
export interface VitalsAlertValues {
  signal: VitalSignal;
  value: number;
  activity: Activity;
  mocked: boolean;
}

/** Irregular rhythm flag. Simulated until watch apps can access Huawei's rhythm detection. */
export interface RhythmAlertValues {
  bpm: number;
  activity: Activity;
  mocked: boolean;
}

export type MetricPayload = HrLiveValues | HrSessionValues | HrAlertValues | SymptomValues | MedicationTakenValues |
  FallValues | WearStateValues | VitalsValues | HrRecoveryValues | RhythmAlertValues | SosValues |
  VitalsAlertValues;

/** One row as stored in Supabase (snake_case to match the table columns). */
export interface MetricRow {
  device_id: string;
  type: MetricType;
  payload: MetricPayload;
  /** ISO 8601 timestamp of when it happened on the watch. */
  recorded_at: string;
  source: MetricSource;
}

export function sourceForKind(kind: HrSourceKind): MetricSource {
  return kind === 'SENSOR' ? 'watch' : 'simulated';
}

export function makeRow(deviceId: string, type: MetricType, payload: MetricPayload, tsMs: number,
  source: MetricSource): MetricRow {
  const row: MetricRow = {
    device_id: deviceId,
    type: type,
    payload: payload,
    recorded_at: new Date(tsMs).toISOString(),
    source: source
  };
  return row;
}
