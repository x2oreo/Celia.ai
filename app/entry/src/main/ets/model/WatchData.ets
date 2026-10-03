// Watch data read from the Supabase views (backend/supabase/migrations/*watch_phone_views*, *watch_insights*).
// See docs/team/watch-data-for-phone.md. `simulated: true` rows are demo data: label them in the UI.

export type WatchWearStatus = 'ON_WRIST' | 'OFF_WRIST' | 'OFFLINE';

/** watch_status: is the watch worn, taken off, or not syncing (no upload for 2 min). */
export interface WatchStatus {
  status: WatchWearStatus;
  onWrist: boolean;
  lastSync: number;        // epoch ms of the last upload
  wearChangedAt: number;   // epoch ms of the last on/off change, 0 if never reported
}

/** watch_doses: a "Took <medicine>" tap on the watch. */
export interface WatchDose {
  id: number;
  name: string;            // the watch's configured medicine name, e.g. 'nadolol'
  takenAt: number;         // epoch ms
  day: string;             // YYYY-MM-DD, Polish local time
  simulated: boolean;
}

export type WatchSymptomKind = 'fine' | 'palpitations' | 'dizziness' | 'fainting' | 'other';

/** watch_symptoms: a "How do you feel?" answer. 'fine' = check-in OK, not a symptom. */
export interface WatchSymptom {
  id: number;
  kind: WatchSymptomKind;
  bpm: number;             // heart rate at that moment, 0 if unknown
  recordedAt: number;      // epoch ms
  simulated: boolean;
}

/** watch_daily_summary: one row per day. */
export interface WatchDaySummary {
  day: string;             // YYYY-MM-DD
  dosesTaken: number;
  firstDoseAt: number;     // epoch ms, 0 if no dose
  symptoms: number;        // excluding 'fine'
  symptomKinds: string[];
  fineCheckIns: number;
  alerts: number;
  falls: number;
  sos: number;
  restingBpm: number;      // 0 if not enough rest data that day
  simulated: boolean;
}

export type WatchInsightKind = 'SYMPTOM_AFTER_RISKY_DRUG' | 'FAINTING_REPORTED' | 'REPEATED_SYMPTOMS' | 'NO_DOSE_LOGGED';

export type WatchInsightSeverity = 'CRITICAL' | 'WARN' | 'INFO';

/** watch_insights: a fixed-rule finding with a fixed text. Show `message` as is; never let the LLM change it. */
export interface WatchInsight {
  kind: WatchInsightKind;
  severity: WatchInsightSeverity;
  ts: number;              // epoch ms
  message: string;
  simulated: boolean;
}

/** watch_vitals_daily: one row per day from the watch's 30 s `vitals` snapshots. 0 = no reading that day. */
export interface WatchVitalsDay {
  day: string;             // YYYY-MM-DD
  avgBpm: number;
  minBpm: number;
  maxBpm: number;
  hrvMs: number;           // simulated on the watch today
  spo2: number;            // simulated on the watch today
  breathingRate: number;   // simulated on the watch today
  sleepMinutes: number;
  stressMinutes: number;   // raised heart rate while still; 0 is a real value
  steps: number;
  simulated: boolean;
}
