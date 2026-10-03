import { describe, it, expect } from '@ohos/hypium';
import {
  AuthResult, AuthTokens, errorOutcome, looksLikeEmail, normalizeEmail, parseSignUpReply, parseTokenReply, parseTokens
} from '../main/ets/account/AuthClient';
import {
  REFRESH_MARGIN_MS, RETRY_MS, StoredSession, isExpired, launchRoute, needsRefresh, nextRefreshDelay,
  parseStoredSession, refreshAction, sessionFromTokens, signedInWith
} from '../main/ets/account/Session';
import {
  ProfileDoc, RemoteProfile, buildDoc, decideSync, localDocTime, parseRemote, personalFields
} from '../main/ets/account/ProfileSync';
import {
  EXCEPTION_ACCOUNT_AUTH, EXCEPTION_PROFILE_SYNC, LedgerEntry, blockedFields, ledgerReport
} from '../main/ets/privacy/Ledger';
import { Profile } from '../main/ets/model/Profile';
import { Medication } from '../main/ets/model/Medication';

const UID: string = '3f2a9c1e-7b4d-4e8a-9c2f-1a2b3c4d5e6f';
const NOW: number = 1_780_000_000_000;

function sessionJson(expiresIn: number, expiresAt: number): string {
  const at: string = expiresAt > 0 ? `,"expires_at":${expiresAt}` : '';
  return `{"access_token":"eyJ.a.b","refresh_token":"r-1","token_type":"bearer","expires_in":${expiresIn}${at},` +
    `"user":{"id":"${UID}","email":"ola@celia.app"}}`;
}

function session(expiresAt: number): StoredSession {
  return sessionFromTokens(new AuthTokens('eyJ.a.b', 'r-1', expiresAt, UID, 'ola@celia.app'));
}

function profile(updatedAt: number): Profile {
  const p: Profile = {
    condition: 'LQTS', genotype: 'LQT2', hasIcd: false, notes: '', contacts: [], updatedAt: updatedAt
  };
  return p;
}

export default function accountTest() {
  describe('AuthClient', () => {
    it('parsesASessionReply', 0, () => {
      const t: AuthTokens | undefined = parseTokens(sessionJson(3600, 0), NOW);
      expect(t !== undefined).assertTrue();
      expect((t as AuthTokens).userId).assertEqual(UID);
      expect((t as AuthTokens).email).assertEqual('ola@celia.app');
      expect((t as AuthTokens).expiresAt).assertEqual(NOW + 3600 * 1000);
    });

    it('prefersExpiresAtFromTheServer', 0, () => {
      const t: AuthTokens | undefined = parseTokens(sessionJson(3600, 1_780_000_900), NOW);
      expect((t as AuthTokens).expiresAt).assertEqual(1_780_000_900_000);
    });

    it('rejectsIncompleteOrMalformedSessions', 0, () => {
      expect(parseTokens('not json', NOW) === undefined).assertTrue();
      expect(parseTokens('null', NOW) === undefined).assertTrue();
      expect(parseTokens(`{"access_token":"a","refresh_token":"r","expires_in":3600}`, NOW) === undefined).assertTrue();
      expect(parseTokens(`{"access_token":"a","refresh_token":"r","expires_in":3600,"user":{"id":"x"}}`, NOW) ===
        undefined).assertTrue();
      expect(parseTokens(`{"access_token":"","refresh_token":"r","expires_in":3600,"user":{"id":"${UID}"}}`, NOW) ===
        undefined).assertTrue();
      expect(parseTokens(`{"access_token":"a","refresh_token":"r","user":{"id":"${UID}"}}`, NOW) === undefined)
        .assertTrue();
    });

    it('signUpWithSessionSignsIn', 0, () => {
      const r: AuthResult = parseSignUpReply(200, sessionJson(3600, 0), NOW);
      expect(r.outcome).assertEqual('OK');
      expect(r.tokens !== undefined).assertTrue();
    });

    it('signUpWithoutSessionAsksToConfirmEmail', 0, () => {
      const r: AuthResult = parseSignUpReply(200, `{"id":"${UID}","email":"ola@celia.app","confirmed_at":null}`, NOW);
      expect(r.outcome).assertEqual('CONFIRM_EMAIL');
      expect(r.tokens === undefined).assertTrue();
    });

    it('mapsCurrentAndOlderErrorShapes', 0, () => {
      expect(parseTokenReply(400, '{"code":400,"error_code":"invalid_credentials","msg":"Invalid login credentials"}',
        NOW, false).outcome).assertEqual('INVALID_CREDENTIALS');
      expect(parseTokenReply(400, '{"error":"invalid_grant","error_description":"Invalid login credentials"}', NOW,
        false).outcome).assertEqual('INVALID_CREDENTIALS');
      expect(parseSignUpReply(422, '{"code":422,"error_code":"user_already_exists","msg":"User already registered"}',
        NOW).outcome).assertEqual('EMAIL_TAKEN');
      expect(parseSignUpReply(422, '{"error_code":"weak_password"}', NOW).outcome).assertEqual('WEAK_PASSWORD');
      expect(parseSignUpReply(400, '{"error_code":"email_address_invalid"}', NOW).outcome).assertEqual('INVALID_EMAIL');
      expect(parseTokenReply(400, '{"error_code":"email_not_confirmed"}', NOW, false).outcome)
        .assertEqual('EMAIL_NOT_CONFIRMED');
      expect(parseSignUpReply(422, '{"error_code":"signup_disabled"}', NOW).outcome).assertEqual('SIGNUP_DISABLED');
    });

    it('separatesOfflineServerAndRateLimits', 0, () => {
      expect(errorOutcome(0, '', false)).assertEqual('OFFLINE');
      expect(errorOutcome(0, '', true)).assertEqual('OFFLINE');
      expect(errorOutcome(503, '', true)).assertEqual('SERVER');
      expect(errorOutcome(429, '', false)).assertEqual('RATE_LIMITED');
      expect(errorOutcome(400, '{"error_code":"over_request_rate_limit"}', true)).assertEqual('RATE_LIMITED');
      // A 2xx with an unreadable body is a server problem, not a sign-in.
      expect(parseTokenReply(200, 'oops', NOW, false).outcome).assertEqual('SERVER');
    });

    it('refreshRejectionMeansTheSessionIsGone', 0, () => {
      expect(parseTokenReply(400, '{"error_code":"refresh_token_not_found"}', NOW, true).outcome)
        .assertEqual('SESSION_REVOKED');
      expect(parseTokenReply(400, '{"error_code":"refresh_token_already_used"}', NOW, true).outcome)
        .assertEqual('SESSION_REVOKED');
      expect(parseTokenReply(200, sessionJson(3600, 0), NOW, true).outcome).assertEqual('OK');
    });

    it('checksEmailsLightly', 0, () => {
      expect(normalizeEmail('  Ola@Celia.App ')).assertEqual('ola@celia.app');
      expect(looksLikeEmail('ola@celia.app')).assertTrue();
      expect(looksLikeEmail('ola@celia')).assertFalse();
      expect(looksLikeEmail('ola celia@x.pl')).assertFalse();
      expect(looksLikeEmail('')).assertFalse();
    });
  });

  describe('Session', () => {
    it('roundTripsTheStoredSession', 0, () => {
      const s: StoredSession | undefined = parseStoredSession(JSON.stringify(session(NOW + 1000)));
      expect(s !== undefined).assertTrue();
      expect((s as StoredSession).userId).assertEqual(UID);
      expect((s as StoredSession).expiresAt).assertEqual(NOW + 1000);
    });

    it('treatsMissingOrCorruptStorageAsSignedOut', 0, () => {
      expect(parseStoredSession('') === undefined).assertTrue();
      expect(parseStoredSession('{') === undefined).assertTrue();
      expect(parseStoredSession('null') === undefined).assertTrue();
      expect(parseStoredSession('{"accessToken":"a","refreshToken":"","userId":"u","expiresAt":1}') === undefined)
        .assertTrue();
      expect(parseStoredSession('{"accessToken":"a","refreshToken":"r","userId":"u"}') === undefined).assertTrue();
      expect(signedInWith(parseStoredSession('garbage'))).assertFalse();
    });

    it('refreshesInsideTheMarginBeforeExpiry', 0, () => {
      const s: StoredSession = session(NOW + 60 * 60 * 1000);
      expect(needsRefresh(s, NOW)).assertFalse();
      expect(needsRefresh(s, s.expiresAt - REFRESH_MARGIN_MS - 1)).assertFalse();
      expect(needsRefresh(s, s.expiresAt - REFRESH_MARGIN_MS)).assertTrue();
      expect(needsRefresh(s, s.expiresAt + 1)).assertTrue();
      expect(isExpired(s, s.expiresAt - 1)).assertFalse();
      expect(isExpired(s, s.expiresAt)).assertTrue();
    });

    it('schedulesTheNextRefresh', 0, () => {
      const s: StoredSession = session(NOW + 60 * 60 * 1000);
      expect(nextRefreshDelay(s, NOW)).assertEqual(60 * 60 * 1000 - REFRESH_MARGIN_MS);
      expect(nextRefreshDelay(s, s.expiresAt + 5000)).assertEqual(RETRY_MS);
    });

    it('onlyTheServerRejectingTheRefreshSignsOut', 0, () => {
      expect(refreshAction('OK')).assertEqual('REPLACE');
      expect(refreshAction('SESSION_REVOKED')).assertEqual('SIGN_OUT');
      expect(refreshAction('OFFLINE')).assertEqual('KEEP');
      expect(refreshAction('SERVER')).assertEqual('KEEP');
      expect(refreshAction('RATE_LIMITED')).assertEqual('KEEP');
    });

    it('staysSignedInOfflineWithAnExpiredStoredSession', 0, () => {
      // Kill the app, network off, reopen a day later: the stored session is expired and the refresh is offline.
      const stored: string = JSON.stringify(session(NOW - 24 * 60 * 60 * 1000));
      const s: StoredSession | undefined = parseStoredSession(stored);
      expect(signedInWith(s)).assertTrue();
      expect(isExpired(s as StoredSession, NOW)).assertTrue();
      expect(needsRefresh(s as StoredSession, NOW)).assertTrue();
      expect(refreshAction(errorOutcome(0, '', true))).assertEqual('KEEP');
      expect(launchRoute(signedInWith(s), false)).assertEqual('MAIN');
    });

    it('opensWelcomeOnlyOnAFreshInstall', 0, () => {
      expect(launchRoute(false, false)).assertEqual('WELCOME');
      expect(launchRoute(true, false)).assertEqual('MAIN');
      expect(launchRoute(true, true)).assertEqual('MAIN');
      expect(launchRoute(false, true)).assertEqual('MAIN');   // set up before accounts existed
    });
  });

  describe('ProfileSync', () => {
    it('lastWriteWins', 0, () => {
      expect(decideSync(true, 200, true, 100, false)).assertEqual('PUSH');
      expect(decideSync(true, 100, true, 200, false)).assertEqual('PULL');
      expect(decideSync(true, 100, true, 100, false)).assertEqual('NONE');
      expect(decideSync(true, 100, false, 0, false)).assertEqual('PUSH');
      expect(decideSync(false, 0, true, 100, false)).assertEqual('PULL');   // fresh install restores
      expect(decideSync(false, 0, false, 0, false)).assertEqual('NONE');
    });

    it('neverPushesAnotherAccountsLocalData', 0, () => {
      expect(decideSync(true, 900, true, 100, true)).assertEqual('PULL');
      expect(decideSync(true, 900, false, 0, true)).assertEqual('NONE');
    });

    it('timesTheDocumentByTheNewerOfProfileAndMedicines', 0, () => {
      expect(localDocTime(profile(500), 300)).assertEqual(500);
      expect(localDocTime(profile(500), 800)).assertEqual(800);
      expect(localDocTime(undefined, 0)).assertEqual(0);
      const old: Profile = { condition: 'LQTS', genotype: 'LQT1', hasIcd: false, notes: '', contacts: [] };
      expect(localDocTime(old, 0)).assertEqual(0);
    });

    it('roundTripsTheDocument', 0, () => {
      const meds: Medication[] = [{ id: 7, name: 'Nadolol', ingredient: 'nadolol', dose: '40 mg', addedAt: 5 }];
      const doc: ProfileDoc = buildDoc(profile(500), meds);
      const body: string = `[{"data":${JSON.stringify(doc)},"updated_at":"2026-10-04T10:00:00.123+00:00"}]`;
      const r: RemoteProfile | undefined = parseRemote(body);
      expect(r !== undefined).assertTrue();
      expect((r as RemoteProfile).at).assertEqual(Date.parse('2026-10-04T10:00:00.123Z'));
      expect((r as RemoteProfile).doc.profile.genotype).assertEqual('LQT2');
      expect((r as RemoteProfile).doc.meds.length).assertEqual(1);
      expect((r as RemoteProfile).doc.meds[0].ingredient).assertEqual('nadolol');
    });

    it('ignoresMissingCorruptOrNewerDocuments', 0, () => {
      expect(parseRemote('[]') === undefined).assertTrue();
      expect(parseRemote('oops') === undefined).assertTrue();
      expect(parseRemote('[{"data":{"v":1,"profile":{"genotype":"LQT2"}},"updated_at":"2026-10-04T10:00:00Z"}]') ===
        undefined).assertTrue();
      const doc: string = JSON.stringify(buildDoc(profile(1), []));
      expect(parseRemote(`[{"data":${doc},"updated_at":"not a date"}]`) === undefined).assertTrue();
      const future: string = doc.replace('"v":1', '"v":2');
      expect(parseRemote(`[{"data":${future},"updated_at":"2026-10-04T10:00:00Z"}]`) === undefined).assertTrue();
    });

    it('dropsBrokenMedicinesButKeepsTheProfile', 0, () => {
      const doc: string = JSON.stringify(buildDoc(profile(1), [])).replace('"meds":[]',
        '"meds":[{"name":"","ingredient":"x","dose":""},{"name":"Nadolol","ingredient":"nadolol","dose":"","addedAt":1},7]');
      const r: RemoteProfile | undefined = parseRemote(`[{"data":${doc},"updated_at":"2026-10-04T10:00:00Z"}]`);
      expect((r as RemoteProfile).doc.meds.length).assertEqual(1);
    });

    it('namesThePersonalFieldsItSends', 0, () => {
      const p: Profile = profile(1);
      expect(personalFields(p).length).assertEqual(0);
      p.name = 'Ola';
      p.notes = 'ICD left side';
      p.contacts = [{ name: 'Mum', phone: '+48 600 000 000', relation: 'mother', email: 'mum@x.pl' }];
      const f: string[] = personalFields(p);
      expect(f.join(',')).assertEqual('name,contacts,phone,email,notes');
    });
  });

  describe('Ledger exceptions', () => {
    it('blocksPersonalFieldsWithoutAnException', 0, () => {
      expect(blockedFields('/rest/v1/profiles', ['data', 'name'], undefined).join(',')).assertEqual('name');
      expect(blockedFields('/functions/v1/agent', ['email'], undefined).join(',')).assertEqual('email');
    });

    it('allowsOnlyTheNamedFieldsOnTheNamedEndpoint', 0, () => {
      expect(blockedFields('/rest/v1/profiles?on_conflict=user_id', ['user_id', 'data', 'name', 'contacts'],
        EXCEPTION_PROFILE_SYNC).length).assertEqual(0);
      expect(blockedFields('/rest/v1/profiles', ['location'], EXCEPTION_PROFILE_SYNC).join(',')).assertEqual('location');
      expect(blockedFields('/auth/v1/signup', ['email', 'password'], EXCEPTION_ACCOUNT_AUTH).length).assertEqual(0);
      expect(blockedFields('/auth/v1/signup', ['email', 'contacts'], EXCEPTION_ACCOUNT_AUTH).join(','))
        .assertEqual('contacts');
    });

    it('cannotBeBorrowedByAnotherEndpoint', 0, () => {
      expect(blockedFields('/functions/v1/agent', ['name'], EXCEPTION_PROFILE_SYNC).join(',')).assertEqual('name');
      expect(blockedFields('/rest/v1/emergency_contacts', ['email'], EXCEPTION_ACCOUNT_AUTH).join(','))
        .assertEqual('email');
    });

    it('showsTheExceptionInTheReport', 0, () => {
      const e: LedgerEntry = {
        ts: 0, endpoint: '/rest/v1/profiles', fields: ['data', 'name'], bytes: 10, outcome: 'OK',
        exception: 'PROFILE_SYNC'
      };
      expect(ledgerReport([e]).includes('exception: PROFILE_SYNC')).assertTrue();
    });
  });
}
