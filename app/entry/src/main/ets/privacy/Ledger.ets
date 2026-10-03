// Privacy ledger (F-46): every request that leaves the phone is recorded here — time, endpoint, field NAMES
// and size, never values. Also the D6 guard: personal fields are refused before anything is sent.

import { LocalStore } from '../data/LocalStore';

export interface LedgerEntry {
  ts: number;
  endpoint: string;
  fields: string[];
  bytes: number;
  outcome: string;   // 'OK' | 'ERROR' | 'BLOCKED'
}

const SETTING_KEY: string = 'ledger';
const MAX_ENTRIES: number = 200;

// Personal data never leaves the device (docs/ARCHITECTURE.md data rule).
export const FORBIDDEN_FIELDS: string[] = ['name', 'phone', 'email', 'contacts', 'notes', 'address', 'lat', 'lon',
  'location'];

export function forbiddenFields(fields: string[]): string[] {
  return fields.filter((f: string) => FORBIDDEN_FIELDS.includes(f.toLowerCase()));
}

// Plain-text export of the ledger (newest first, as listed). Field names and sizes only — never values.
export function ledgerReport(entries: LedgerEntry[]): string {
  const lines: string[] = ['What left my phone (Celia privacy ledger)', ''];
  entries.forEach((e: LedgerEntry) => {
    const fields: string = e.fields.length > 0 ? e.fields.join(', ') : '(no fields)';
    lines.push(`${new Date(e.ts).toISOString()}  ${e.outcome}  ${e.endpoint}  sent: ${fields}  ${e.bytes} B`);
  });
  if (entries.length === 0) {
    lines.push('Nothing has left this phone.');
  }
  return lines.join('\n');
}

export class Ledger {
  static async list(): Promise<LedgerEntry[]> {
    const raw: string = await LocalStore.get().getSetting(SETTING_KEY, '[]');
    return (JSON.parse(raw) as LedgerEntry[]).reverse();
  }

  static async add(entry: LedgerEntry): Promise<void> {
    const raw: string = await LocalStore.get().getSetting(SETTING_KEY, '[]');
    let all: LedgerEntry[] = JSON.parse(raw) as LedgerEntry[];
    all.push(entry);
    if (all.length > MAX_ENTRIES) {
      all = all.slice(all.length - MAX_ENTRIES);
    }
    await LocalStore.get().setSetting(SETTING_KEY, JSON.stringify(all));
  }

  static async clear(): Promise<void> {
    await LocalStore.get().setSetting(SETTING_KEY, '[]');
  }
}
