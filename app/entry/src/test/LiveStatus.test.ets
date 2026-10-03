import { describe, it, expect } from '@ohos/hypium';
import { argbHex, endTitleKey, liveContent, notificationTitle } from '../main/ets/emergency/SosLiveText';
import { medIdLines, MedIdLines } from '../main/ets/widget/MedIdData';
import { CardField, Profile } from '../main/ets/model/Profile';
import { Medication } from '../main/ets/model/Medication';

function profile(): Profile {
  const p: Profile = {
    condition: 'LQTS', genotype: 'LQT2', hasIcd: true, icdModel: 'Medtronic Cobalt', notes: 'private note',
    name: 'Anna', allergies: ['penicillin'], bloodType: 'A+',
    contacts: [{ name: 'Mum', phone: '+48 600 100 200', relation: 'mother' }]
  };
  return p;
}

const MEDS: Medication[] = [{ id: 1, name: 'Nadolol', ingredient: 'nadolol', dose: '40 mg', addedAt: 0 }];

export default function liveStatusTest() {
  describe('SosLiveText', () => {
    it('manualSosNeverHasEmptyText', 0, () => {
      expect(liveContent('', 'Tap I\'m OK')).assertEqual('Tap I\'m OK');
      expect(liveContent('   ', 'Tap I\'m OK')).assertEqual('Tap I\'m OK');
      expect(liveContent(' heart rate 165 ', 'x')).assertEqual('heart rate 165');
    });

    it('notificationFillsTheTimerPlaceholder', 0, () => {
      expect(notificationTitle('SOS in ${placeholder.timer}. Tap if you are OK', 25))
        .assertEqual('SOS in 25 s. Tap if you are OK');
    });

    it('endTitles', 0, () => {
      expect(endTitleKey('OK')).assertEqual('ntf_live_end_ok');
      expect(endTitleKey('SENT')).assertEqual('ntf_live_end_sent');
      expect(endTitleKey('CLOSED')).assertEqual('ntf_live_end_closed');
    });

    it('colourAsArgbString', 0, () => {
      expect(argbHex(0xFFD92D20)).assertEqual('#FFD92D20');
      expect(argbHex(0x00000001)).assertEqual('#00000001');
    });
  });

  describe('MedIdCard', () => {
    it('showsWhatAParamedicNeeds', 0, () => {
      const l: MedIdLines = medIdLines(profile(), MEDS);
      expect(l.name).assertEqual('Anna');
      expect(l.condition).assertEqual('Long QT syndrome, type 2');
      expect(l.icd).assertEqual('Has an ICD · Medtronic Cobalt');
      expect(l.meds.includes('Nadolol')).assertTrue();
      expect(l.other).assertEqual('Allergies: penicillin · Blood A+');
    });

    it('neverShowsContactsOrNotes', 0, () => {
      const l: MedIdLines = medIdLines(profile(), MEDS);
      const all: string = `${l.name}${l.condition}${l.icd}${l.meds}${l.other}`;
      expect(all.includes('600')).assertFalse();
      expect(all.includes('Mum')).assertFalse();
      expect(all.includes('private note')).assertFalse();
    });

    it('respectsHiddenFields', 0, () => {
      const p: Profile = profile();
      p.hiddenOnCard = [CardField.NAME, CardField.ICD_MODEL, CardField.ALLERGIES, CardField.BLOOD_TYPE];
      const l: MedIdLines = medIdLines(p, []);
      expect(l.name).assertEqual('');
      expect(l.icd).assertEqual('Has an ICD');
      expect(l.other).assertEqual('');
      expect(l.meds).assertEqual('');
    });

    it('noProfileShowsTheGenericCondition', 0, () => {
      const l: MedIdLines = medIdLines(undefined, []);
      expect(l.condition).assertEqual('Long QT syndrome');
      expect(l.name).assertEqual('');
    });
  });
}
