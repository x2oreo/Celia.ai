import { describe, it, expect } from '@ohos/hypium';
import { parseStoredProfile } from '../main/ets/data/LocalStore';
import { Profile } from '../main/ets/model/Profile';

// Exactly what the app stored before Workstream B4 (no emergency details, no updatedAt).
const OLD_PROFILE_JSON: string = '{"condition":"LQTS","genotype":"LQT2","hasIcd":true,"notes":"Allergic to latex",' +
  '"contacts":[{"name":"Marek","phone":"+48600100200","relation":"husband"}],"name":"Anna","country":"PL",' +
  '"cardLanguage":"pl"}';

export default function emergencyProfileTest() {
  describe('StoredProfile', () => {
    it('oldStoredProfileLoadsWithDefaults', 0, () => {
      const p: Profile | undefined = parseStoredProfile(OLD_PROFILE_JSON);
      expect(p !== undefined).assertTrue();
      expect(p?.genotype).assertEqual('LQT2');
      expect(p?.hasIcd).assertTrue();
      expect(p?.name).assertEqual('Anna');
      expect(p?.contacts.length).assertEqual(1);
      expect(p?.contacts[0].phone).assertEqual('+48600100200');
      expect(p?.notes).assertEqual('Allergic to latex');
      // New fields: lists exist and are empty, single values stay absent (hidden on the card).
      expect(p?.allergies?.length).assertEqual(0);
      expect(p?.extra?.length).assertEqual(0);
      expect(p?.hiddenOnCard?.length).assertEqual(0);
      expect(p?.bloodType === undefined).assertTrue();
      expect(p?.dateOfBirth === undefined).assertTrue();
      expect(p?.updatedAt === undefined).assertTrue();
    });

    it('newFieldsSurviveARoundTrip', 0, () => {
      const p: Profile = {
        condition: 'LQTS', genotype: 'LQT1', hasIcd: true, notes: '', contacts: [],
        dateOfBirth: '1990-04-12', sex: 'FEMALE', bloodType: 'A+', allergies: ['penicillin'], icdModel: 'Medtronic',
        cardiologistName: 'Dr Nowak', cardiologistPhone: '+48 22 000 00 00', hospital: 'Szpital Bielański',
        extra: [{ label: 'Pacemaker', value: 'no' }], hiddenOnCard: ['dob'], updatedAt: 1759500000000
      };
      const back: Profile | undefined = parseStoredProfile(JSON.stringify(p));
      expect(back?.sex).assertEqual('FEMALE');
      expect(back?.allergies?.[0]).assertEqual('penicillin');
      expect(back?.extra?.[0].label).assertEqual('Pacemaker');
      expect(back?.hiddenOnCard?.[0]).assertEqual('dob');
      expect(back?.hospital).assertEqual('Szpital Bielański');
      expect(back?.updatedAt).assertEqual(1759500000000);
    });

    it('badValuesFallBackInsteadOfCrashing', 0, () => {
      const p: Profile | undefined = parseStoredProfile(
        '{"genotype":"LQT9","hasIcd":"yes","contacts":[{"name":"X"},null],"allergies":"latex","sex":"?"}');
      expect(p?.genotype).assertEqual('UNKNOWN');
      expect(p?.hasIcd).assertFalse();
      expect(p?.contacts.length).assertEqual(0);
      expect(p?.notes).assertEqual('');
      expect(p?.allergies?.length).assertEqual(0);
      expect(p?.sex === undefined).assertTrue();
      expect(parseStoredProfile('{oops') === undefined).assertTrue();
      expect(parseStoredProfile('null') === undefined).assertTrue();
    });
  });
}
