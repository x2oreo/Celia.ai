// One medicine check, kept on-device for the history timeline and the doctor report (F-23).

import { ComboKind, RiskLevel } from './DrugVerdict';

export type ScanVia = 'TEXT' | 'BARCODE' | 'ONBOARDING' | 'CHAT' | 'INTENT';

export interface ScanRecord {
  id: number;
  ts: number;
  via: ScanVia;
  query: string;
  ingredient: string;   // '' if unknown
  risk: RiskLevel;
  combo: ComboKind;     // NONE when no interaction with my meds
}
