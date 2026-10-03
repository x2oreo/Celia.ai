import { describe, it, expect } from '@ohos/hypium';
import { parseStoredProfile } from '../main/ets/data/LocalStore';
import { CardField, Profile } from '../main/ets/model/Profile';
import {
  CardRow, cloneProfile, detailRows, parseList, shownOnCard, validBirthDate, withShown
} from '../main/ets/emergency/EmergencyDetails';
import { cardLabels } from '../main/ets/common/CardStrings';

function full(): Profile {
  const p: Profile = {
    condition: 'LQTS', genotype: 'LQT2', hasIcd: true, notes: 'n', contacts: [{ name: 'M', phone: '1', relation: '' }],
    dateOfBirth: '1990-04-12', sex: 'FEMALE', bloodType: 'A+', allergies: ['penicillin', 'latex'],
    icdModel: 'Medtronic', cardiologistName: 'Dr Nowak', cardiologistPhone: '+48 1', hospital: 'Bielański',
    extra: [{ label: 'Pacemaker', value: 'no' }], hiddenOnCard: []
  };
  return p;
}

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

  describe('EmergencyDetails', () => {
    const now: number = new Date(2026, 9, 4).getTime();

    it('rowsInFixedOrderEmptyHidden', 0, () => {
      const rows: CardRow[] = detailRows(full(), cardLabels('en'), now);
      expect(rows.map((r: CardRow) => r.id).join(',')).assertEqual(
        'dob,sex,blood,allergies,icdModel,cardiologist,hospital,extra');
      expect(rows[0].value).assertEqual('1990-04-12 (age 36)');
      expect(rows[3].value).assertEqual('penicillin, latex');
      expect(rows[5].value).assertEqual('Dr Nowak · +48 1');
      expect(rows[7].label).assertEqual('Pacemaker');
      const empty: Profile = { condition: 'LQTS', genotype: 'UNKNOWN', hasIcd: false, notes: '', contacts: [] };
      expect(detailRows(empty, cardLabels('en'), now).length).assertEqual(0);
    });

    it('hiddenFieldsAndIcdModelWithoutIcdLeftOut', 0, () => {
      const p: Profile = full();
      p.hiddenOnCard = [CardField.BLOOD_TYPE, CardField.EXTRA];
      p.hasIcd = false;
      const ids: string[] = detailRows(p, cardLabels('en'), now).map((r: CardRow) => r.id);
      expect(ids.includes('blood')).assertFalse();
      expect(ids.includes('extra')).assertFalse();
      expect(ids.includes('icdModel')).assertFalse();
      expect(detailRows(p, cardLabels('en'), now, true).some((r: CardRow) => r.id === 'blood')).assertTrue();
    });

    it('labelsFallBackToEnglish', 0, () => {
      expect(cardLabels('pl').bloodType).assertEqual('Blood type');
      expect(cardLabels(undefined).code).assertEqual('en');
    });

    it('showOnCardSwitch', 0, () => {
      const hidden: string[] = withShown([], CardField.HOSPITAL, false);
      expect(hidden.join()).assertEqual('hospital');
      expect(withShown(hidden, CardField.HOSPITAL, true).length).assertEqual(0);
      expect(withShown(hidden, CardField.HOSPITAL, false).length).assertEqual(1);   // no duplicates
      const p: Profile = full();
      p.hiddenOnCard = hidden;
      expect(shownOnCard(p, CardField.HOSPITAL)).assertFalse();
      expect(shownOnCard(p, CardField.NAME)).assertTrue();
    });

    it('cloneKeepsEveryFieldAndIsDeep', 0, () => {
      const p: Profile = full();
      p.name = 'Anna';
      p.country = 'PL';
      p.cardLanguage = 'pl';
      p.updatedAt = 5;
      const c: Profile = cloneProfile(p);
      // Same content, compared field by field through the stored form (key order may differ).
      expect(JSON.stringify(cloneProfile(parseStoredProfile(JSON.stringify(c)) as Profile)))
        .assertEqual(JSON.stringify(cloneProfile(parseStoredProfile(JSON.stringify(p)) as Profile)));
      expect(c.name).assertEqual('Anna');
      expect(c.cardLanguage).assertEqual('pl');
      expect(c.updatedAt).assertEqual(5);
      expect(c.hospital).assertEqual('Bielański');
      c.allergies?.push('nuts');
      c.contacts[0].name = 'X';
      c.extra?.pop();
      expect(p.allergies?.length).assertEqual(2);
      expect(p.contacts[0].name).assertEqual('M');
      expect(p.extra?.length).assertEqual(1);
    });

    it('listAndDateParsing', 0, () => {
      expect(parseList(' penicillin, latex;;Latex\nnuts ,').join('|')).assertEqual('penicillin|latex|nuts');
      expect(validBirthDate('', now)).assertTrue();
      expect(validBirthDate('1990-04-12', now)).assertTrue();
      expect(validBirthDate('1990-02-30', now)).assertFalse();
      expect(validBirthDate('12.04.1990', now)).assertFalse();
      expect(validBirthDate('2030-01-01', now)).assertFalse();
    });
  });
}
