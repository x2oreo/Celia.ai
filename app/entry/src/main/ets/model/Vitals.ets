// Shared contract — see docs/ARCHITECTURE.md.

export type VitalsSourceKind = 'WATCH' | 'SIMULATED';

export interface VitalsSample {
  ts: number;
  hr: number;
  source: VitalsSourceKind;
}

export type AlertKind = 'TACHY_AT_REST' | 'BRADY' | 'HR_ALARM_FROM_WATCH' | 'WATCH_DISCONNECTED';

export interface VitalsAlert {
  ts: number;
  kind: AlertKind;
  hr: number;
  message: string;
}
