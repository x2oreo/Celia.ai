/**
 * Metrics the watch sends to the backend (`watch_metrics` table).
 * Small, computed values only. The watch never uploads raw sensor streams.
 */

export type MetricType = 'hr_live' | 'hr_session' | 'hr_alert' | 'symptom' | 'medication_taken';

/** Where the heart rate came from. `simulated` must always be labelled as demo data in the UI. */
export type MetricSource = 'watch' | 'simulated';

export type HrSourceKind = 'SENSOR' | 'SIMULATED';

export type AlertDirection = 'high' | 'low';

export type SymptomKind = 'palpitations' | 'dizziness' | 'fainting' | 'other';

export interface HrLiveValues {
  bpm: number;
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
}

export interface SymptomValues {
  kind: SymptomKind;
  /** Heart rate at the moment of logging, 0 if unknown. */
  bpm: number;
}

export interface MedicationTakenValues {
  name: string;
}

export type MetricPayload = HrLiveValues | HrSessionValues | HrAlertValues | SymptomValues | MedicationTakenValues;

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
