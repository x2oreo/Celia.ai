// Supabase Auth over plain HTTPS (no supabase-js in the app). Endpoints, from the Supabase Auth API reference:
//   POST /auth/v1/signup                          {email, password} → session, or the user alone when the project
//                                                  still requires email confirmation
//   POST /auth/v1/token?grant_type=password       {email, password} → session
//   POST /auth/v1/token?grant_type=refresh_token  {refresh_token}   → new session (refresh tokens are single-use)
//   POST /auth/v1/logout                          Bearer access token → 204
// A session is {access_token, refresh_token, expires_in, expires_at?, user: {id, email}}. Errors come as
// {code, error_code, msg} (current Auth) or {error, error_description} (older): both are parsed.
// The parse functions are pure and exported for tests; the network calls go through common/Net.ets.

import { http } from '@kit.NetworkKit';
import { accountTarget, NetResult, RequestOpts, requestJson } from '../common/Net';
import { EXCEPTION_ACCOUNT_AUTH } from '../privacy/Ledger';

const AUTH_TIMEOUT_MS: number = 10000;

// What a sign-up / log-in / refresh came to. OFFLINE and SERVER mean "try again later"; the stored session stays.
export type AuthOutcome = 'OK' | 'CONFIRM_EMAIL' | 'INVALID_CREDENTIALS' | 'EMAIL_TAKEN' | 'WEAK_PASSWORD' |
  'INVALID_EMAIL' | 'EMAIL_NOT_CONFIRMED' | 'SIGNUP_DISABLED' | 'RATE_LIMITED' | 'SESSION_REVOKED' | 'OFFLINE' |
  'SERVER';

export class AuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresAt: number;   // ms epoch
  userId: string;
  email: string;

  constructor(accessToken: string, refreshToken: string, expiresAt: number, userId: string, email: string) {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    this.expiresAt = expiresAt;
    this.userId = userId;
    this.email = email;
  }
}

export class AuthResult {
  outcome: AuthOutcome;
  tokens: AuthTokens | undefined;

  constructor(outcome: AuthOutcome, tokens: AuthTokens | undefined = undefined) {
    this.outcome = outcome;
    this.tokens = tokens;
  }
}

interface AuthUserJson {
  id?: string;
  email?: string;
}

interface AuthReplyJson {
  access_token?: string;
  refresh_token?: string;
  expires_in?: number;
  expires_at?: number;   // seconds epoch
  user?: AuthUserJson;
  // sign-up with confirmation on: the user object itself
  id?: string;
  email?: string;
  // errors
  error_code?: string;
  error?: string;
  error_description?: string;
  msg?: string;
}

class EmailPassword {
  email: string;
  password: string;

  constructor(email: string, password: string) {
    this.email = email;
    this.password = password;
  }
}

class RefreshBody {
  refresh_token: string;

  constructor(refreshToken: string) {
    this.refresh_token = refreshToken;
  }
}

const UUID: RegExp = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function parseJson(body: string): AuthReplyJson | undefined {
  try {
    const v: AuthReplyJson | null = JSON.parse(body) as AuthReplyJson | null;
    return v === null || typeof v !== 'object' ? undefined : v;
  } catch (e) {
    return undefined;
  }
}

// Session tokens from a successful reply, or undefined when anything needed is missing or malformed.
export function parseTokens(body: string, nowMs: number): AuthTokens | undefined {
  const j: AuthReplyJson | undefined = parseJson(body);
  if (j === undefined || j.user === undefined || j.user === null) {
    return undefined;
  }
  const access: string = typeof j.access_token === 'string' ? j.access_token : '';
  const refresh: string = typeof j.refresh_token === 'string' ? j.refresh_token : '';
  const id: string = typeof j.user.id === 'string' ? j.user.id : '';
  if (access.length === 0 || refresh.length === 0 || !UUID.test(id)) {
    return undefined;
  }
  let expiresAt: number = 0;
  if (typeof j.expires_at === 'number' && j.expires_at > 0) {
    expiresAt = j.expires_at * 1000;
  } else if (typeof j.expires_in === 'number' && j.expires_in > 0) {
    expiresAt = nowMs + j.expires_in * 1000;
  } else {
    return undefined;
  }
  const email: string = typeof j.user.email === 'string' ? j.user.email : '';
  return new AuthTokens(access, refresh, expiresAt, id, email);
}

// Error reply → outcome. Unknown 4xx on a refresh means the session is gone; on sign-in it means bad credentials.
export function errorOutcome(status: number, body: string, refreshing: boolean): AuthOutcome {
  if (status === 0) {
    return 'OFFLINE';
  }
  if (status === 429) {
    return 'RATE_LIMITED';
  }
  if (status >= 500) {
    return 'SERVER';
  }
  const j: AuthReplyJson | undefined = parseJson(body);
  const code: string = j === undefined ? '' :
    (typeof j.error_code === 'string' ? j.error_code : (typeof j.error === 'string' ? j.error : ''));
  if (code === 'over_request_rate_limit' || code === 'over_email_send_rate_limit') {
    return 'RATE_LIMITED';
  }
  if (refreshing) {
    return 'SESSION_REVOKED';
  }
  if (code === 'user_already_exists' || code === 'email_exists') {
    return 'EMAIL_TAKEN';
  }
  if (code === 'weak_password') {
    return 'WEAK_PASSWORD';
  }
  if (code === 'email_address_invalid' || code === 'validation_failed') {
    return 'INVALID_EMAIL';
  }
  if (code === 'email_not_confirmed') {
    return 'EMAIL_NOT_CONFIRMED';
  }
  if (code === 'signup_disabled') {
    return 'SIGNUP_DISABLED';
  }
  return 'INVALID_CREDENTIALS';
}

// Reply to POST /token (password or refresh grant).
export function parseTokenReply(status: number, body: string, nowMs: number, refreshing: boolean): AuthResult {
  if (status >= 200 && status < 300) {
    const t: AuthTokens | undefined = parseTokens(body, nowMs);
    return t !== undefined ? new AuthResult('OK', t) : new AuthResult('SERVER');
  }
  return new AuthResult(errorOutcome(status, body, refreshing));
}

// Reply to POST /signup: a session when "Confirm email" is off; the bare user when the project wants the address
// confirmed first (then nobody is signed in yet and the app says "check your email").
export function parseSignUpReply(status: number, body: string, nowMs: number): AuthResult {
  if (status >= 200 && status < 300) {
    const t: AuthTokens | undefined = parseTokens(body, nowMs);
    if (t !== undefined) {
      return new AuthResult('OK', t);
    }
    const j: AuthReplyJson | undefined = parseJson(body);
    const id: string = j === undefined ? '' :
      (typeof j.id === 'string' ? j.id : (j.user !== undefined && typeof j.user.id === 'string' ? j.user.id : ''));
    return UUID.test(id) ? new AuthResult('CONFIRM_EMAIL') : new AuthResult('SERVER');
  }
  return new AuthResult(errorOutcome(status, body, false));
}

// Light client-side checks so the form can say what is wrong before a round trip. Auth has the final word.
export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

export function looksLikeEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizeEmail(email));
}

export const MIN_PASSWORD_LENGTH: number = 8;

export class AuthClient {
  static async signUp(email: string, password: string): Promise<AuthResult> {
    const body: string = JSON.stringify(new EmailPassword(normalizeEmail(email), password));
    const r: NetResult = await AuthClient.post('/auth/v1/signup', body, ['email', 'password']);
    return parseSignUpReply(r.status, r.body, Date.now());
  }

  static async logIn(email: string, password: string): Promise<AuthResult> {
    const body: string = JSON.stringify(new EmailPassword(normalizeEmail(email), password));
    const r: NetResult = await AuthClient.post('/auth/v1/token?grant_type=password', body, ['email', 'password']);
    return parseTokenReply(r.status, r.body, Date.now(), false);
  }

  static async refresh(refreshToken: string): Promise<AuthResult> {
    const body: string = JSON.stringify(new RefreshBody(refreshToken));
    const r: NetResult = await AuthClient.post('/auth/v1/token?grant_type=refresh_token', body, ['refresh_token']);
    return parseTokenReply(r.status, r.body, Date.now(), true);
  }

  // Revokes the session on the server. Best effort: signing out on the phone never waits for this.
  static async logOut(accessToken: string): Promise<boolean> {
    const r: NetResult = await requestJson(http.RequestMethod.POST, '/auth/v1/logout', '', [], AUTH_TIMEOUT_MS,
      accountTarget(accessToken));
    return r.ok;
  }

  private static async post(path: string, body: string, fields: string[]): Promise<NetResult> {
    const opts: RequestOpts = new RequestOpts();
    opts.exception = EXCEPTION_ACCOUNT_AUTH;
    return requestJson(http.RequestMethod.POST, path, body, fields, AUTH_TIMEOUT_MS, accountTarget(), opts);
  }
}
