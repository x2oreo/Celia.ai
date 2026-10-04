// Shared contract - see docs/ARCHITECTURE.md.

export type VitalsSourceKind = 'WATCH' | 'SIMULATED';

export interface VitalsSample {
  ts: number;
  hr: number;
  source: VitalsSourceKind;
  // Optional extras (F-32). The watch fills what it can; SimulatedSource fills all.
  hrv?: number;          // ms (RMSSD-like)
  restingHr?: number;
  asleep?: boolean;
  irregular?: boolean;   // irregular rhythm flag from the watch
  steps?: number;        // steps in the last minute - > 60 counts as exertion
}

export type AlertKind = 'TACHY_AT_REST' | 'BRADY' | 'HR_ALARM_FROM_WATCH' | 'WATCH_DISCONNECTED' |
  'IRREGULAR_RHYTHM' | 'HRV_DROP' | 'HIGH_HR_EXERTION' | 'RESTING_HR_RISE';

export type AlertSeverity = 'INFO' | 'WARN' | 'CRITICAL';

export interface VitalsAlert {
  ts: number;
  kind: AlertKind;
  hr: number;
  message: string;
  severity?: AlertSeverity;   // CRITICAL starts the SOS countdown (F-27)
  // Set only for the watch's own `sos` row: the watch already counted down and sent it, so the phone must not
  // start a second countdown (B8).
  watchSos?: WatchSos;
}

export interface WatchSos {
  reason: string;          // 'fall' | 'need_help'
  withLocation: boolean;   // the row carried lat/lon
}
