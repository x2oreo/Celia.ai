// The signed-in user (Workstream B1). This API is a contract with Workstream A: keep these signatures stable.
//
// Sign in once, then the app keeps working offline. The session (access token, refresh token, expiry, user id,
// email) is stored in the encrypted RDB (data/LocalStore.ets, setting `session`). With a stored session the user
// stays signed in with no network, even after the access token expires; the token is refreshed ahead of expiry
// and retried every minute until the network is back. Only the server saying the session is gone signs out.
// The emergency card and medicine check never wait for any of this.

import { Listeners } from '../common/Listeners';
import { setUserBearer } from '../common/Net';
import { Logger } from '../common/Logger';
import { LocalStore, StoreTopic } from '../data/LocalStore';
import { Profile } from '../model/Profile';
import { AuthClient, AuthOutcome, AuthResult, AuthTokens } from './AuthClient';

const log: Logger = new Logger('Session');

export const SESSION_KEY: string = 'session';
// Refresh this long before the access token expires (Supabase's default lifetime is 1 h).
export const REFRESH_MARGIN_MS: number = 5 * 60 * 1000;
// While a refresh is due but failing (offline, server error), try again this often.
export const RETRY_MS: number = 60 * 1000;

export class StoredSession {
  accessToken: string = '';
  refreshToken: string = '';
  expiresAt: number = 0;   // ms epoch
  userId: string = '';
  email: string = '';
}

export function sessionFromTokens(t: AuthTokens): StoredSession {
  const s: StoredSession = new StoredSession();
  s.accessToken = t.accessToken;
  s.refreshToken = t.refreshToken;
  s.expiresAt = t.expiresAt;
  s.userId = t.userId;
  s.email = t.email;
  return s;
}

// Stored JSON → session, or undefined when missing or corrupt (then the user is signed out, nothing crashes).
export function parseStoredSession(raw: string): StoredSession | undefined {
  if (raw.length === 0) {
    return undefined;
  }
  try {
    const v: StoredSession | null = JSON.parse(raw) as StoredSession | null;
    if (v === null || typeof v !== 'object') {
      return undefined;
    }
    if (typeof v.accessToken !== 'string' || v.accessToken.length === 0 || typeof v.refreshToken !== 'string' ||
      v.refreshToken.length === 0 || typeof v.userId !== 'string' || v.userId.length === 0 ||
      typeof v.expiresAt !== 'number') {
      return undefined;
    }
    const s: StoredSession = new StoredSession();
    s.accessToken = v.accessToken;
    s.refreshToken = v.refreshToken;
    s.expiresAt = v.expiresAt;
    s.userId = v.userId;
    s.email = typeof v.email === 'string' ? v.email : '';
    return s;
  } catch (e) {
    return undefined;
  }
}

export function isExpired(s: StoredSession, nowMs: number): boolean {
  return nowMs >= s.expiresAt;
}

// Refresh once inside the margin before expiry, or any time after it.
export function needsRefresh(s: StoredSession, nowMs: number): boolean {
  return nowMs >= s.expiresAt - REFRESH_MARGIN_MS;
}

// When to try the next refresh: at the start of the margin, or after RETRY_MS when one is already due.
export function nextRefreshDelay(s: StoredSession, nowMs: number): number {
  const due: number = s.expiresAt - REFRESH_MARGIN_MS - nowMs;
  return due > 0 ? due : RETRY_MS;
}

export type RefreshAction = 'REPLACE' | 'KEEP' | 'SIGN_OUT';

// What a refresh result does to the stored session. Only the server rejecting the refresh token signs out;
// offline, rate limits and server errors keep the old session (the app keeps working, the next retry may succeed).
export function refreshAction(outcome: AuthOutcome): RefreshAction {
  if (outcome === 'OK') {
    return 'REPLACE';
  }
  if (outcome === 'SESSION_REVOKED') {
    return 'SIGN_OUT';
  }
  return 'KEEP';
}

// Signed in = a stored session exists. Expiry does not matter: offline with an expired token is still signed in.
export function signedInWith(s: StoredSession | undefined): boolean {
  return s !== undefined;
}

export type LaunchRoute = 'MAIN' | 'WELCOME';

// Where the app opens. A stored session goes straight in (offline too). Someone who set the app up before accounts
// existed (local profile, no session) also goes straight in; only a fresh install sees Welcome.
export function launchRoute(hasSession: boolean, hasProfile: boolean): LaunchRoute {
  return hasSession || hasProfile ? 'MAIN' : 'WELCOME';
}

export class Session {
  private static changes: Listeners<boolean> = new Listeners<boolean>();
  private static current: StoredSession | undefined = undefined;
  private static profileName: string = '';
  private static loading: Promise<void> | undefined = undefined;
  private static refreshing: Promise<void> | undefined = undefined;
  private static timer: number = -1;
  private static watchingProfile: boolean = false;

  // Loads the stored session once (called at launch before routing; later calls return the same promise).
  static load(): Promise<void> {
    if (Session.loading === undefined) {
      Session.loading = Session.doLoad();
    }
    return Session.loading;
  }

  static isSignedIn(): boolean {
    return signedInWith(Session.current);
  }

  static userId(): string {
    return Session.current !== undefined ? Session.current.userId : '';
  }

  // Name from the local profile, or '' when unknown.
  static userName(): string {
    return Session.profileName;
  }

  static email(): string {
    return Session.current !== undefined ? Session.current.email : '';
  }

  // Current access token (JWT), or '' when signed out. May be expired while offline.
  static accessToken(): string {
    return Session.current !== undefined ? Session.current.accessToken : '';
  }

  // Access token for a request made now: refreshed first when due. '' when signed out. May still be expired when
  // the refresh could not reach the server - the request then fails like any offline request.
  static async freshToken(): Promise<string> {
    await Session.load();
    if (Session.current !== undefined && needsRefresh(Session.current, Date.now())) {
      await Session.refreshNow();
    }
    return Session.accessToken();
  }

  // Store a new session after sign-up / log-in.
  static async start(tokens: AuthTokens): Promise<void> {
    await Session.load();
    Session.current = sessionFromTokens(tokens);
    await Session.persist();
    Session.schedule();
    Session.changes.emit(true);
  }

  // Signs out on this phone at once; revoking the session on the server is best effort (works offline too).
  // Local data stays unless the caller also clears it.
  static async signOut(): Promise<void> {
    await Session.load();
    const token: string = Session.accessToken();
    Session.current = undefined;
    Session.clearTimer();
    await LocalStore.get().setSetting(SESSION_KEY, '');
    Session.changes.emit(false);
    if (token.length > 0) {
      AuthClient.logOut(token).catch(() => {
      });
    }
  }

  // Called with the new signed-in state after sign-in, sign-out or a failed refresh.
  static onChange(listener: (signedIn: boolean) => void): () => void {
    return Session.changes.add(listener);
  }

  // Refresh now, at most one at a time. Applies refreshAction() to the result.
  static refreshNow(): Promise<void> {
    if (Session.refreshing === undefined) {
      Session.refreshing = Session.doRefresh().finally(() => {
        Session.refreshing = undefined;
      });
    }
    return Session.refreshing;
  }

  private static async doLoad(): Promise<void> {
    setUserBearer(() => Session.current !== undefined && !isExpired(Session.current, Date.now()) ?
      Session.current.accessToken : '');
    const raw: string = await LocalStore.get().getSetting(SESSION_KEY, '');
    Session.current = parseStoredSession(raw);
    await Session.loadName();
    if (!Session.watchingProfile) {
      Session.watchingProfile = true;
      LocalStore.get().onChange((topic: StoreTopic) => {
        if (topic === 'profile') {
          Session.loadName();
        }
      });
    }
    Session.schedule();
  }

  private static async loadName(): Promise<void> {
    const p: Profile | undefined = await LocalStore.get().getProfile();
    Session.profileName = p !== undefined && p.name !== undefined ? p.name : '';
  }

  private static async doRefresh(): Promise<void> {
    const s: StoredSession | undefined = Session.current;
    if (s === undefined) {
      return;
    }
    const r: AuthResult = await AuthClient.refresh(s.refreshToken);
    if (Session.current !== s) {
      return;   // signed out or signed in again meanwhile
    }
    const action: RefreshAction = refreshAction(r.outcome);
    if (action === 'REPLACE' && r.tokens !== undefined) {
      Session.current = sessionFromTokens(r.tokens);
      await Session.persist();
    } else if (action === 'SIGN_OUT') {
      log.warn('refresh token rejected; signing out');
      Session.current = undefined;
      await LocalStore.get().setSetting(SESSION_KEY, '');
      Session.clearTimer();
      Session.changes.emit(false);
      return;
    } else {
      log.info(`refresh deferred: ${r.outcome}`);
    }
    Session.schedule();
  }

  private static async persist(): Promise<void> {
    if (Session.current !== undefined) {
      await LocalStore.get().setSetting(SESSION_KEY, JSON.stringify(Session.current));
    }
  }

  private static schedule(): void {
    Session.clearTimer();
    if (Session.current === undefined) {
      return;
    }
    // setTimeout caps at ~24.8 days; a session that far out is refreshed at the next launch anyway.
    const delay: number = Math.min(nextRefreshDelay(Session.current, Date.now()), 0x7fffffff);
    Session.timer = setTimeout(() => {
      Session.timer = -1;
      Session.refreshNow();
    }, delay);
  }

  private static clearTimer(): void {
    if (Session.timer !== -1) {
      clearTimeout(Session.timer);
      Session.timer = -1;
    }
  }
}
