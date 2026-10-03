// B10: emergency contacts reach the server, so a watch SOS can alert them (backend/supabase/functions/sos).
// Only with consent: a switch in Settings → Account, off by default. When on, the phone sends the contacts' names
// and numbers plus the user's first name for the paired watch through `sync_sos_contacts` (owner-only RPC,
// migration 20261004100100); when switched off, it sends an empty list, which deletes them. Without Twilio secrets
// the server records `dry_run`; `sos_status` lets the app say so plainly.
// The pure parts (phone normalisation, what gets sent, status parsing) are exported for tests.

import { http } from '@kit.NetworkKit';
import { Config } from '../common/Config';
import { Logger } from '../common/Logger';
import { accountTarget, NetResult, RequestOpts, requestJson } from '../common/Net';
import { LocalStore, StoreTopic } from '../data/LocalStore';
import { WatchPairing } from '../data/WatchPairing';
import { Contact, Profile } from '../model/Profile';
import { EXCEPTION_SOS_CONTACTS } from '../privacy/Ledger';
import { Session } from './Session';

const log: Logger = new Logger('SosContacts');

export const CONSENT_KEY: string = 'sos_contacts_consent';   // 'on' | ''
export const MAX_SOS_CONTACTS: number = 5;                   // the sos function reads at most 5
const TIMEOUT_MS: number = 10000;
const E164: RegExp = /^\+[1-9][0-9]{6,14}$/;

// Country calling codes (ITU-T E.164 assignments) for the countries the app knows (common/EmergencyNumbers.ets).
const CALLING_CODES: Record<string, string> = {
  'AL': '355', 'AT': '43', 'BA': '387', 'BE': '32', 'BG': '359', 'CH': '41', 'CY': '357', 'CZ': '420', 'DE': '49',
  'DK': '45', 'EE': '372', 'ES': '34', 'FI': '358', 'FR': '33', 'GB': '44', 'GR': '30', 'HR': '385', 'HU': '36',
  'IE': '353', 'IS': '354', 'IT': '39', 'LT': '370', 'LU': '352', 'LV': '371', 'MD': '373', 'ME': '382',
  'MK': '389', 'MT': '356', 'NL': '31', 'NO': '47', 'PL': '48', 'PT': '351', 'RO': '40', 'RS': '381', 'SE': '46',
  'SI': '386', 'SK': '421', 'TR': '90', 'UA': '380', 'US': '1', 'CA': '1', 'MX': '52', 'BR': '55', 'AR': '54',
  'AU': '61', 'NZ': '64', 'JP': '81', 'KR': '82', 'CN': '86', 'IN': '91', 'AE': '971', 'IL': '972', 'ZA': '27',
  'EG': '20', 'TH': '66'
};

export function callingCode(country: string | undefined): string {
  if (country === undefined) {
    return '';
  }
  const c: string | undefined = CALLING_CODES[country.toUpperCase()];
  return c !== undefined ? c : '';
}

// A number as typed → E.164 ("+48600123456"), or '' when it cannot be made one. "+…" and "00…" are international
// already; a local number takes the profile country's code, dropping one national trunk "0" (Italy keeps it).
export function toE164(phone: string, country: string | undefined): string {
  const raw: string = phone.trim();
  let digits: string = raw.replace(/[^0-9]/g, '');
  let out: string = '';
  if (raw.startsWith('+')) {
    out = `+${digits}`;
  } else if (digits.startsWith('00')) {
    out = `+${digits.substring(2)}`;
  } else {
    const cc: string = callingCode(country);
    if (cc === '') {
      return '';
    }
    if (digits.startsWith('0') && cc !== '39') {
      digits = digits.substring(1);
    }
    out = `+${cc}${digits}`;
  }
  return E164.test(out) ? out : '';
}

// First word of the name, at most 40 characters ("Ola Nowak" → "Ola"); the alert text says "Ola may need help".
export function firstName(name: string | undefined): string {
  if (name === undefined) {
    return '';
  }
  const first: string = name.trim().split(/\s+/)[0];
  return first.substring(0, 40);
}

export class SosContact {
  name: string;
  phone: string;

  constructor(name: string, phone: string) {
    this.name = name;
    this.phone = phone;
  }
}

export class SosPayload {
  contacts: SosContact[] = [];
  skipped: number = 0;   // contacts whose number could not be made international
  firstName: string = '';
}

// What the server gets for this profile: up to 5 contacts in profile order with E.164 numbers, and the first name.
export function sosPayload(profile: Profile): SosPayload {
  const p: SosPayload = new SosPayload();
  const seen: string[] = [];
  profile.contacts.forEach((c: Contact) => {
    const phone: string = toE164(c.phone, profile.country);
    const name: string = c.name.trim().substring(0, 40);
    if (phone === '' || name === '') {
      p.skipped++;
      return;
    }
    if (seen.includes(phone) || p.contacts.length >= MAX_SOS_CONTACTS) {
      return;
    }
    seen.push(phone);
    p.contacts.push(new SosContact(name, phone));
  });
  p.firstName = firstName(profile.name);
  return p;
}

export type DispatchStatus = 'sent' | 'partial' | 'failed' | 'dry_run' | 'skipped_cooldown' | 'no_contacts' |
  'skipped_global_limit' | 'unknown';

export class SosStatus {
  contacts: number = 0;
  hasName: boolean = false;
  lastStatus: DispatchStatus | undefined = undefined;
  lastAt: number = 0;
}

interface LastJson {
  status?: string;
  at?: string;
}

interface StatusJson {
  contacts?: number;
  has_name?: boolean;
  last?: LastJson | null;
}

const STATUSES: string[] = ['sent', 'partial', 'failed', 'dry_run', 'skipped_cooldown', 'no_contacts',
  'skipped_global_limit'];

export function parseSosStatus(body: string): SosStatus | undefined {
  try {
    const j: StatusJson | null = JSON.parse(body) as StatusJson | null;
    if (j === null || typeof j !== 'object' || typeof j.contacts !== 'number') {
      return undefined;
    }
    const s: SosStatus = new SosStatus();
    s.contacts = j.contacts;
    s.hasName = j.has_name === true;
    if (j.last !== undefined && j.last !== null && typeof j.last.status === 'string') {
      s.lastStatus = STATUSES.includes(j.last.status) ? j.last.status as DispatchStatus : 'unknown';
      const at: number = typeof j.last.at === 'string' ? Date.parse(j.last.at) : NaN;
      s.lastAt = isNaN(at) ? 0 : at;
    }
    return s;
  } catch (e) {
    return undefined;
  }
}

export type SosSyncResult = 'SENT' | 'CLEARED' | 'NOT_SIGNED_IN' | 'NOT_PAIRED' | 'OFFLINE' | 'ERROR';

class SyncBody {
  p_device_id: string;
  p_contacts: SosContact[];
  p_first_name: string | null;

  constructor(deviceId: string, contacts: SosContact[], first: string | null) {
    this.p_device_id = deviceId;
    this.p_contacts = contacts;
    this.p_first_name = first;
  }
}

class DeviceBody {
  p_device_id: string;

  constructor(deviceId: string) {
    this.p_device_id = deviceId;
  }
}

export class SosContacts {
  private static started: boolean = false;
  private static timer: number = -1;
  static lastResult: SosSyncResult | undefined = undefined;
  static lastSkipped: number = 0;

  static async consent(): Promise<boolean> {
    return (await LocalStore.get().getSetting(CONSENT_KEY, '')) === 'on';
  }

  // Turning it on sends the contacts now; turning it off deletes them from the server.
  static async setConsent(on: boolean): Promise<SosSyncResult> {
    await LocalStore.get().setSetting(CONSENT_KEY, on ? 'on' : '');
    return SosContacts.sync();
  }

  // Keep the server copy current: after profile edits, sign-in and watch binding. Call once at launch.
  static start(): void {
    if (SosContacts.started) {
      return;
    }
    SosContacts.started = true;
    LocalStore.get().onChange((t: StoreTopic) => {
      if (t === 'profile') {
        SosContacts.schedule();
      }
    });
    WatchPairing.bound.add(() => {
      SosContacts.schedule();
    });
  }

  private static schedule(): void {
    if (SosContacts.timer !== -1) {
      clearTimeout(SosContacts.timer);
    }
    SosContacts.timer = setTimeout(() => {
      SosContacts.timer = -1;
      SosContacts.consent().then((on: boolean) => {
        if (on) {
          SosContacts.sync();
        }
      });
    }, 3000);
  }

  // Sends the contacts (consent on) or an empty list (consent off) for the paired watch.
  static async sync(): Promise<SosSyncResult> {
    const r: SosSyncResult = await SosContacts.send(await SosContacts.consent());
    SosContacts.lastResult = r;
    return r;
  }

  // Before deleting the account copy: remove the contacts from the server too, whatever the switch says.
  static async clearOnServer(): Promise<SosSyncResult> {
    return SosContacts.send(false);
  }

  static async status(): Promise<SosStatus | undefined> {
    if (!Session.isSignedIn() || !WatchPairing.isPaired()) {
      return undefined;
    }
    const token: string = await Session.freshToken();
    const r: NetResult = await requestJson(http.RequestMethod.POST, '/rest/v1/rpc/sos_status',
      JSON.stringify(new DeviceBody(Config.WATCH_DEVICE_ID)), ['p_device_id'], TIMEOUT_MS, accountTarget(token));
    return r.ok ? parseSosStatus(r.body) : undefined;
  }

  private static async send(on: boolean): Promise<SosSyncResult> {
    if (!Session.isSignedIn()) {
      return 'NOT_SIGNED_IN';
    }
    if (!WatchPairing.isPaired()) {
      return 'NOT_PAIRED';
    }
    const profile: Profile | undefined = await LocalStore.get().getProfile();
    const payload: SosPayload = on && profile !== undefined ? sosPayload(profile) : new SosPayload();
    SosContacts.lastSkipped = payload.skipped;
    const body: SyncBody = new SyncBody(Config.WATCH_DEVICE_ID, payload.contacts,
      payload.firstName.length > 0 ? payload.firstName : null);
    const fields: string[] = ['p_device_id', 'p_contacts', 'p_first_name'];
    if (payload.contacts.length > 0) {
      fields.push('contacts', 'phone');
    }
    if (payload.contacts.length > 0 || payload.firstName.length > 0) {
      fields.push('name');
    }
    const opts: RequestOpts = new RequestOpts();
    opts.exception = EXCEPTION_SOS_CONTACTS;
    const token: string = await Session.freshToken();
    const r: NetResult = await requestJson(http.RequestMethod.POST, '/rest/v1/rpc/sync_sos_contacts',
      JSON.stringify(body), fields, TIMEOUT_MS, accountTarget(token), opts);
    if (!r.ok) {
      log.warn(`sync_sos_contacts HTTP ${r.status}`);
      return r.status === 0 ? 'OFFLINE' : 'ERROR';
    }
    return on ? 'SENT' : 'CLEARED';
  }
}
