// Privacy ledger (F-46): every request that leaves the phone is recorded here — time, endpoint, field NAMES
// and size, never values. Also the D6 guard: personal fields are refused before anything is sent.

import { LocalStore } from '../data/LocalStore';

export interface LedgerEntry {
  ts: number;
  endpoint: string;
  fields: string[];
  bytes: number;
  outcome: string;   // 'OK' | 'ERROR' | 'BLOCKED'
  exception?: string; // id of the PersonalDataException that let personal fields leave, if any
}

const SETTING_KEY: string = 'ledger';
const MAX_ENTRIES: number = 200;

// Personal data never leaves the device (docs/ARCHITECTURE.md data rule).
export const FORBIDDEN_FIELDS: string[] = ['name', 'phone', 'email', 'contacts', 'notes', 'address', 'lat', 'lon',
  'location'];

export function forbiddenFields(fields: string[]): string[] {
  return fields.filter((f: string) => FORBIDDEN_FIELDS.includes(f.toLowerCase()));
}

// The only requests allowed to carry personal data, each named, scoped to one endpoint and to the listed fields.
// FORBIDDEN_FIELDS stays as strict as before for everything else. Every use is still written to the ledger, with
// the exception's id, so "What left my phone" shows it.
export class PersonalDataException {
  id: string;
  endpoint: string;   // path prefix, e.g. '/rest/v1/profiles'
  fields: string[];   // personal fields it may carry (top-level names, or the profile document's fields)
  reason: string;

  constructor(id: string, endpoint: string, fields: string[], reason: string) {
    this.id = id;
    this.endpoint = endpoint;
    this.fields = fields;
    this.reason = reason;
  }
}

// Signing up / in sends the account email (and the password, which is not stored anywhere on our side).
export const EXCEPTION_ACCOUNT_AUTH: PersonalDataException = new PersonalDataException('ACCOUNT_AUTH', '/auth/v1/',
  ['email'], 'Sign up and log in need the account email.');
// The profile backup under the user's account (backend migration 20261004100000_profiles_auth.sql, RLS by user).
export const EXCEPTION_PROFILE_SYNC: PersonalDataException = new PersonalDataException('PROFILE_SYNC',
  '/rest/v1/profiles', ['name', 'phone', 'email', 'contacts', 'notes'],
  'Your profile and medicines are backed up to your own account so a new phone can restore them.');

// With the user's consent (Settings → Account), the paired watch's SOS contacts and the user's first name, so the
// server can alert them (migration 20261004100100_sos_contacts_account.sql, owner-only RPC).
export const EXCEPTION_SOS_CONTACTS: PersonalDataException = new PersonalDataException('SOS_CONTACTS',
  '/rest/v1/rpc/sync_sos_contacts', ['name', 'phone', 'contacts'],
  'You switched on "Alert my contacts from my watch".');

export const PERSONAL_DATA_EXCEPTIONS: PersonalDataException[] = [EXCEPTION_ACCOUNT_AUTH, EXCEPTION_PROFILE_SYNC,
  EXCEPTION_SOS_CONTACTS];

// Personal fields a request may NOT send: forbidden fields not covered by the named exception for this endpoint.
// An exception only applies when the endpoint matches its own prefix, so it cannot be borrowed by another call.
export function blockedFields(endpoint: string, fields: string[], exception: PersonalDataException | undefined):
  string[] {
  const forbidden: string[] = forbiddenFields(fields);
  if (exception === undefined || !endpoint.startsWith(exception.endpoint)) {
    return forbidden;
  }
  return forbidden.filter((f: string) => !exception.fields.includes(f.toLowerCase()));
}

// Plain-text export of the ledger (newest first, as listed). Field names and sizes only — never values.
export function ledgerReport(entries: LedgerEntry[]): string {
  const lines: string[] = ['What left my phone (Celia privacy ledger)', ''];
  entries.forEach((e: LedgerEntry) => {
    const fields: string = e.fields.length > 0 ? e.fields.join(', ') : '(no fields)';
    const why: string = e.exception !== undefined && e.exception.length > 0 ? `  exception: ${e.exception}` : '';
    lines.push(`${new Date(e.ts).toISOString()}  ${e.outcome}  ${e.endpoint}  sent: ${fields}  ${e.bytes} B${why}`);
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
