// Event log entry stored on-device (LocalStore.logEvent / listEvents). Feeds the doctor report.

export type AppEventKind = 'DRUG_CHECK' | 'VITALS_ALERT' | 'EMERGENCY' | 'AGENT_FALLBACK';

export interface AppEvent {
  id: number;
  ts: number;
  kind: AppEventKind;
  detail: string;       // JSON string, shape depends on kind
}
