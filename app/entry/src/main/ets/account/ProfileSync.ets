// Profile backup under the account (Workstream B2). The phone's encrypted RDB stays the copy the UI reads; the
// account holds one document per user in `public.profiles` (backend migration 20261004100000_profiles_auth.sql,
// RLS: each user reads and writes only their own row).
//
// Decision (docs/workflow/b-accounts.md): medicines ride in the same document as the profile - one round trip, one
// RLS policy set, one timestamp. Sync is last-write-wins on that timestamp: the newer of Profile.updatedAt (stamped
// by LocalStore.saveProfile) and the last local medicine change. It runs at sign-in, at launch when signed in, and
// a few seconds after a local edit; every run reads the account copy first, then pushes or pulls whichever is newer.
// The decision functions are pure and exported for tests.

import { http } from '@kit.NetworkKit';
import { accountTarget, getJson, NetResult, RequestOpts, requestJson } from '../common/Net';
import { Logger } from '../common/Logger';
import { LocalStore, StoreTopic } from '../data/LocalStore';
import { Medication } from '../model/Medication';
import { Contact, Profile } from '../model/Profile';
import { EXCEPTION_PROFILE_SYNC } from '../privacy/Ledger';
import { Session } from './Session';

const log: Logger = new Logger('ProfileSync');

export const SYNC_DOC_VERSION: number = 1;
// ms epoch of the last local medicine change (medicines have no updatedAt of their own).
export const MEDS_AT_KEY: string = 'sync_meds_at';
// User id the local data was last synced with; '' = never synced (set up before accounts, or signed out since).
export const SYNC_OWNER_KEY: string = 'sync_owner';
const SYNC_TIMEOUT_MS: number = 10000;
const PUSH_DELAY_MS: number = 3000;

export interface SyncedMed {
  name: string;
  ingredient: string;
  dose: string;
  addedAt: number;
}

export interface ProfileDoc {
  v: number;
  profile: Profile;
  meds: SyncedMed[];
}

export class RemoteProfile {
  doc: ProfileDoc;
  at: number;   // ms epoch (profiles.updated_at)

  constructor(doc: ProfileDoc, at: number) {
    this.doc = doc;
    this.at = at;
  }
}

interface RemoteRowJson {
  data?: ProfileDoc;
  updated_at?: string;
}

class ProfileRow {
  user_id: string;
  data: ProfileDoc;
  updated_at: string;

  constructor(userId: string, data: ProfileDoc, updatedAt: string) {
    this.user_id = userId;
    this.data = data;
    this.updated_at = updatedAt;
  }
}

export type SyncDecision = 'PUSH' | 'PULL' | 'NONE';

// Last-write-wins. `localOwnedByOther`: the local data was synced with a different account (someone signed out and
// another person signed in on this phone) - it must never be pushed into this account; the account copy wins.
export function decideSync(hasLocal: boolean, localAt: number, hasRemote: boolean, remoteAt: number,
  localOwnedByOther: boolean): SyncDecision {
  if (localOwnedByOther) {
    return hasRemote ? 'PULL' : 'NONE';
  }
  if (!hasLocal) {
    return hasRemote ? 'PULL' : 'NONE';
  }
  if (!hasRemote) {
    return 'PUSH';
  }
  if (localAt > remoteAt) {
    return 'PUSH';
  }
  return remoteAt > localAt ? 'PULL' : 'NONE';
}

// Time of the local document: the newer of the profile edit and the last medicine change.
export function localDocTime(profile: Profile | undefined, medsAt: number): number {
  const p: number = profile !== undefined && typeof profile.updatedAt === 'number' ? profile.updatedAt : 0;
  return Math.max(p, medsAt);
}

export function buildDoc(profile: Profile, meds: Medication[]): ProfileDoc {
  const list: SyncedMed[] = meds.map((m: Medication) => {
    const s: SyncedMed = { name: m.name, ingredient: m.ingredient, dose: m.dose, addedAt: m.addedAt };
    return s;
  });
  const doc: ProfileDoc = { v: SYNC_DOC_VERSION, profile: profile, meds: list };
  return doc;
}

// Personal fields a pushed document carries, named for the privacy guard and the ledger (names only, never values).
export function personalFields(profile: Profile): string[] {
  const out: string[] = [];
  if (profile.name !== undefined && profile.name.length > 0) {
    out.push('name');
  }
  if (profile.contacts.length > 0) {
    out.push('contacts');
  }
  if (profile.contacts.some((c: Contact) => c.phone.length > 0) ||
    (profile.cardiologistPhone !== undefined && profile.cardiologistPhone.length > 0)) {
    out.push('phone');
  }
  if (profile.contacts.some((c: Contact) => c.email !== undefined && c.email.length > 0)) {
    out.push('email');
  }
  if (profile.notes.length > 0) {
    out.push('notes');
  }
  return out;
}

function validProfile(p: Profile | undefined | null): boolean {
  return p !== undefined && p !== null && typeof p === 'object' && typeof p.genotype === 'string' &&
    typeof p.hasIcd === 'boolean' && typeof p.notes === 'string' && Array.isArray(p.contacts);
}

function validMed(m: SyncedMed | undefined | null): boolean {
  return m !== undefined && m !== null && typeof m === 'object' && typeof m.name === 'string' &&
    m.name.length > 0 && typeof m.ingredient === 'string' && typeof m.dose === 'string';
}

// GET /rest/v1/profiles reply (an array with zero or one row) → the account copy, or undefined when there is none
// or it is unreadable. A newer document version than this app knows is treated as unreadable (never half-applied).
export function parseRemote(body: string): RemoteProfile | undefined {
  try {
    const rows: RemoteRowJson[] | null = JSON.parse(body) as RemoteRowJson[] | null;
    if (rows === null || !Array.isArray(rows) || rows.length === 0) {
      return undefined;
    }
    const row: RemoteRowJson = rows[0];
    const doc: ProfileDoc | undefined = row.data;
    const at: number = typeof row.updated_at === 'string' ? Date.parse(row.updated_at) : NaN;
    if (doc === undefined || doc === null || typeof doc !== 'object' || isNaN(at) || typeof doc.v !== 'number' ||
      doc.v > SYNC_DOC_VERSION || !validProfile(doc.profile)) {
      return undefined;
    }
    const meds: SyncedMed[] = Array.isArray(doc.meds) ? doc.meds.filter((m: SyncedMed) => validMed(m)) : [];
    const clean: ProfileDoc = { v: doc.v, profile: doc.profile, meds: meds };
    return new RemoteProfile(clean, at);
  } catch (e) {
    return undefined;
  }
}

export type SyncResult = 'PUSHED' | 'PULLED' | 'UP_TO_DATE' | 'SIGNED_OUT' | 'OFFLINE' | 'ERROR';

export class ProfileSync {
  private static started: boolean = false;
  private static applying: boolean = false;
  private static running: Promise<SyncResult> | undefined = undefined;
  private static timer: number = -1;
  static lastResult: SyncResult = 'UP_TO_DATE';
  static lastSyncAt: number = 0;

  // Called once at launch: sync now if signed in, then after every sign-in and every local edit.
  static start(): void {
    if (ProfileSync.started) {
      return;
    }
    ProfileSync.started = true;
    LocalStore.get().onChange((topic: StoreTopic) => {
      if (ProfileSync.applying) {
        return;
      }
      if (topic === 'meds') {
        LocalStore.get().setSetting(MEDS_AT_KEY, String(Date.now()));
        ProfileSync.schedule();
      } else if (topic === 'profile') {
        ProfileSync.schedule();
      }
    });
    Session.onChange((signedIn: boolean) => {
      if (signedIn) {
        ProfileSync.syncNow();
      }
    });
    if (Session.isSignedIn()) {
      ProfileSync.syncNow();
    }
  }

  // Read the account copy, then push or pull the newer one. One run at a time.
  static syncNow(): Promise<SyncResult> {
    if (ProfileSync.running === undefined) {
      ProfileSync.running = ProfileSync.run().then((r: SyncResult) => {
        ProfileSync.lastResult = r;
        if (r === 'PUSHED' || r === 'PULLED' || r === 'UP_TO_DATE') {
          ProfileSync.lastSyncAt = Date.now();
        }
        return r;
      }).finally(() => {
        ProfileSync.running = undefined;
      });
    }
    return ProfileSync.running;
  }

  // Deletes this user's document from the account (not the auth user, not this phone's data).
  static async deleteCloudData(): Promise<boolean> {
    const token: string = await Session.freshToken();
    const uid: string = Session.userId();
    if (token.length === 0 || uid.length === 0) {
      return false;
    }
    const r: NetResult = await requestJson(http.RequestMethod.DELETE,
      `/rest/v1/profiles?user_id=eq.${encodeURIComponent(uid)}`, '', [], SYNC_TIMEOUT_MS, accountTarget(token));
    if (r.ok) {
      await LocalStore.get().setSetting(SYNC_OWNER_KEY, '');
    }
    return r.ok;
  }

  private static schedule(): void {
    if (!Session.isSignedIn()) {
      return;
    }
    if (ProfileSync.timer !== -1) {
      clearTimeout(ProfileSync.timer);
    }
    ProfileSync.timer = setTimeout(() => {
      ProfileSync.timer = -1;
      ProfileSync.syncNow();
    }, PUSH_DELAY_MS);
  }

  private static async run(): Promise<SyncResult> {
    const token: string = await Session.freshToken();
    const uid: string = Session.userId();
    if (token.length === 0 || uid.length === 0) {
      return 'SIGNED_OUT';
    }
    const got: NetResult = await getJson(`/rest/v1/profiles?select=data,updated_at&user_id=eq.${encodeURIComponent(uid)}`,
      SYNC_TIMEOUT_MS, true, accountTarget(token));
    if (!got.ok) {
      return got.status === 0 ? 'OFFLINE' : 'ERROR';
    }
    const remote: RemoteProfile | undefined = parseRemote(got.body);
    const store: LocalStore = LocalStore.get();
    const profile: Profile | undefined = await store.getProfile();
    const medsAt: number = Number(await store.getSetting(MEDS_AT_KEY, '0'));
    const owner: string = await store.getSetting(SYNC_OWNER_KEY, '');
    const localAt: number = localDocTime(profile, isNaN(medsAt) ? 0 : medsAt);
    const decision: SyncDecision = decideSync(profile !== undefined, localAt, remote !== undefined,
      remote !== undefined ? remote.at : 0, owner.length > 0 && owner !== uid);
    if (decision === 'PUSH' && profile !== undefined) {
      return ProfileSync.push(uid, token, profile, localAt);
    }
    if (decision === 'PULL' && remote !== undefined) {
      await ProfileSync.apply(remote);
      await store.setSetting(SYNC_OWNER_KEY, uid);
      return 'PULLED';
    }
    if (owner !== uid && (owner.length === 0 || remote !== undefined)) {
      await store.setSetting(SYNC_OWNER_KEY, uid);
    }
    return 'UP_TO_DATE';
  }

  private static async push(uid: string, token: string, profile: Profile, at: number): Promise<SyncResult> {
    const meds: Medication[] = await LocalStore.get().listMeds();
    const row: ProfileRow = new ProfileRow(uid, buildDoc(profile, meds), new Date(at).toISOString());
    const fields: string[] = ['user_id', 'data', 'updated_at'].concat(personalFields(profile));
    const opts: RequestOpts = new RequestOpts();
    opts.prefer = 'resolution=merge-duplicates,return=minimal';
    opts.exception = EXCEPTION_PROFILE_SYNC;
    const r: NetResult = await requestJson(http.RequestMethod.POST, '/rest/v1/profiles?on_conflict=user_id',
      JSON.stringify(row), fields, SYNC_TIMEOUT_MS, accountTarget(token), opts);
    if (!r.ok) {
      log.warn(`push failed: ${r.status}`);
      return r.status === 0 ? 'OFFLINE' : 'ERROR';
    }
    await LocalStore.get().setSetting(SYNC_OWNER_KEY, uid);
    return 'PUSHED';
  }

  // Replace the local profile and medicines with the account copy, keeping its timestamp so the next run is a no-op.
  private static async apply(remote: RemoteProfile): Promise<void> {
    const store: LocalStore = LocalStore.get();
    ProfileSync.applying = true;
    try {
      const p: Profile = remote.doc.profile;
      p.updatedAt = remote.at;
      await store.saveProfile(p, false);
      const old: Medication[] = await store.listMeds();
      for (const m of old) {
        await store.removeMed(m.id);
      }
      for (const m of remote.doc.meds) {
        await store.addMed(m.name, m.ingredient, m.dose);
      }
      await store.setSetting(MEDS_AT_KEY, String(remote.at));
    } finally {
      ProfileSync.applying = false;
    }
  }
}
