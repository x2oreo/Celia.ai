import { describe, it, expect } from '@ohos/hypium';
import {
  MAX_SOS_CONTACTS, SosPayload, SosStatus, callingCode, firstName, parseSosStatus, sosPayload, toE164,
  watchSosWhom
} from '../main/ets/account/SosContacts';
import { watchAccess } from '../main/ets/data/WatchPairing';
import { sendsUserToken } from '../main/ets/common/Net';
import { EXCEPTION_SOS_CONTACTS, blockedFields } from '../main/ets/privacy/Ledger';
import { Contact, Profile } from '../main/ets/model/Profile';

function contact(name: string, phone: string): Contact {
  const c: Contact = { name: name, phone: phone, relation: '' };
  return c;
}

function profile(country: string, contacts: Contact[], name: string): Profile {
  const p: Profile = {
    condition: 'LQTS', genotype: 'LQT2', hasIcd: false, notes: '', contacts: contacts, country: country, name: name
  };
  return p;
}

const PROJECT: string = 'https://jxiggumhircfuhianmel.supabase.co';

export default function sosContactsTest() {
  describe('SosContacts', () => {
    it('watchSosSaysWhoWasAlerted', 0, () => {
      const sentAt: number = Date.parse('2026-10-04T10:00:00Z');
      const st: SosStatus = new SosStatus();
      expect(watchSosWhom(false, true, st, sentAt)).assertEqual('OFF');
      expect(watchSosWhom(true, false, st, sentAt)).assertEqual('OFF');
      expect(watchSosWhom(true, true, undefined, sentAt)).assertEqual('PENDING');
      st.lastStatus = 'sent';
      st.lastAt = sentAt - 3600000;   // the previous SOS, an hour earlier
      expect(watchSosWhom(true, true, st, sentAt)).assertEqual('PENDING');
      st.lastAt = sentAt + 4000;
      expect(watchSosWhom(true, true, st, sentAt)).assertEqual('SENT');
      st.lastStatus = 'dry_run';
      expect(watchSosWhom(true, true, st, sentAt)).assertEqual('DRY_RUN');
      st.lastStatus = 'skipped_global_limit';
      expect(watchSosWhom(true, true, st, sentAt)).assertEqual('SKIPPED');
      st.lastStatus = 'unknown';
      expect(watchSosWhom(true, true, st, sentAt)).assertEqual('FAILED');
    });

    it('makesNumbersInternational', 0, () => {
      expect(toE164('+48 600 123 456', 'PL')).assertEqual('+48600123456');
      expect(toE164('0048 600-123-456', 'BG')).assertEqual('+48600123456');
      expect(toE164('600 123 456', 'PL')).assertEqual('+48600123456');
      expect(toE164('0888 123 456', 'BG')).assertEqual('+359888123456');   // trunk 0 dropped
      expect(toE164('06 12345678', 'NL')).assertEqual('+31612345678');
      expect(toE164('333 1234567', 'IT')).assertEqual('+393331234567');
      expect(toE164('06 1234 5678', 'IT')).assertEqual('+390612345678');   // Italy keeps the 0
    });

    it('refusesNumbersItCannotPlace', 0, () => {
      expect(toE164('600 123 456', undefined)).assertEqual('');
      expect(toE164('600 123 456', 'XX')).assertEqual('');
      expect(toE164('12', 'PL')).assertEqual('');
      expect(toE164('+0 600 123 456', 'PL')).assertEqual('');
      expect(toE164('', 'PL')).assertEqual('');
    });

    it('knowsCallingCodes', 0, () => {
      expect(callingCode('pl')).assertEqual('48');
      expect(callingCode('US')).assertEqual('1');
      expect(callingCode(undefined)).assertEqual('');
    });

    it('sendsOnlyTheFirstName', 0, () => {
      expect(firstName('  Ola   Nowak ')).assertEqual('Ola');
      expect(firstName(undefined)).assertEqual('');
      expect(firstName('')).assertEqual('');
    });

    it('buildsWhatTheServerGets', 0, () => {
      const p: SosPayload = sosPayload(profile('PL', [
        contact('Mum', '600 000 001'), contact('Dad', '+359 888 123 456'), contact('No number', 'call me'),
        contact('Mum again', '+48600000001'), contact('', '600 000 002')
      ], 'Ola Nowak'));
      expect(p.contacts.length).assertEqual(2);
      expect(p.contacts[0].phone).assertEqual('+48600000001');
      expect(p.contacts[1].name).assertEqual('Dad');
      expect(p.skipped).assertEqual(2);
      expect(p.firstName).assertEqual('Ola');
    });

    it('capsAtFiveContacts', 0, () => {
      const many: Contact[] = [];
      for (let i = 0; i < 8; i++) {
        many.push(contact(`C${i}`, `60000000${i}`));
      }
      expect(sosPayload(profile('PL', many, 'A')).contacts.length).assertEqual(MAX_SOS_CONTACTS);
    });

    it('parsesTheServerStatus', 0, () => {
      const s: SosStatus | undefined = parseSosStatus(
        '{"contacts":2,"has_name":true,"last":{"status":"dry_run","at":"2026-10-04T09:00:00+00:00","contacts":2}}');
      expect((s as SosStatus).contacts).assertEqual(2);
      expect((s as SosStatus).hasName).assertTrue();
      expect((s as SosStatus).lastStatus).assertEqual('dry_run');
      expect((s as SosStatus).lastAt).assertEqual(Date.parse('2026-10-04T09:00:00Z'));
      const none: SosStatus | undefined = parseSosStatus('{"contacts":0,"has_name":false,"last":null}');
      expect((none as SosStatus).lastStatus === undefined).assertTrue();
      expect(parseSosStatus('{"last":null}') === undefined).assertTrue();
      expect(parseSosStatus('nope') === undefined).assertTrue();
      expect((parseSosStatus('{"contacts":1,"last":{"status":"weird"}}') as SosStatus).lastStatus).assertEqual('unknown');
    });

    it('letsOnlyTheContactsRpcCarryContacts', 0, () => {
      expect(blockedFields('/rest/v1/rpc/sync_sos_contacts', ['p_device_id', 'contacts', 'name', 'phone'],
        EXCEPTION_SOS_CONTACTS).length).assertEqual(0);
      expect(blockedFields('/rest/v1/rpc/sync_sos_contacts', ['notes'], EXCEPTION_SOS_CONTACTS).join(','))
        .assertEqual('notes');
      expect(blockedFields('/rest/v1/watch_context', ['name'], EXCEPTION_SOS_CONTACTS).join(',')).assertEqual('name');
    });
  });

  describe('Watch access by account (B9)', () => {
    it('needsTheOwnerForAPairedWatch', 0, () => {
      expect(watchAccess(false, false)).assertEqual('DEMO');
      expect(watchAccess(false, true)).assertEqual('DEMO');
      expect(watchAccess(true, true)).assertEqual('OWNER');
      expect(watchAccess(true, false)).assertEqual('SIGN_IN_NEEDED');
    });

    it('sendsTheUserTokenOnlyToTheDatabase', 0, () => {
      expect(sendsUserToken('/rest/v1/watch_metrics?device_id=eq.x', PROJECT, PROJECT)).assertTrue();
      expect(sendsUserToken('/rest/v1/rpc/set_watch_genotype', PROJECT, PROJECT)).assertTrue();
      expect(sendsUserToken('/functions/v1/agent', PROJECT, PROJECT)).assertFalse();   // AI paths stay anonymous
      expect(sendsUserToken('/rest/v1/watch_metrics', 'http://127.0.0.1:8787', PROJECT)).assertFalse();
      expect(sendsUserToken('/rest/v1/watch_metrics', '', PROJECT)).assertFalse();
    });
  });
}
