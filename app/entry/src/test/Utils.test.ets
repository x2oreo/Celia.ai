import { describe, it, expect } from '@ohos/hypium';
import { gtinCheckDigitOk, lookupGtin, parseGs1 } from '../main/ets/drugs/Gs1';
import { forbiddenFields } from '../main/ets/privacy/Ledger';
import { DoseLog, DoseReminder, doseStatus, dayKey } from '../main/ets/reminders/DoseSchedule';
import { emergencyFor } from '../main/ets/common/EmergencyNumbers';
import { CARD_TEXTS, cardText, languageForCountry } from '../main/ets/common/CardStrings';
import { PHARMACY_TEXTS } from '../main/ets/emergency/PharmacyStrings';
import { tipOfTheDay, tipsFor } from '../main/ets/coach/Coach';
import { medsInteractions, riskCounts } from '../main/ets/drugs/MedsReview';
import { Medication } from '../main/ets/model/Medication';

function reminder(hour: number, minute: number): DoseReminder {
  const r: DoseReminder = { id: 7, medId: 1, medName: 'Nadolol', hour: hour, minute: minute, reminderId: 1 };
  return r;
}

function at(hour: number, minute: number): number {
  const d: Date = new Date(2026, 9, 3, hour, minute, 0, 0);
  return d.getTime();
}

export default function utilsTest() {
  describe('Gs1', () => {
    it('validEan13', 0, () => {
      expect(gtinCheckDigitOk('2000000000015')).assertTrue();
      expect(gtinCheckDigitOk('2000000000016')).assertFalse();
      expect(gtinCheckDigitOk('4006381333931')).assertTrue();
    });

    it('dataMatrixWithFnc1', 0, () => {
      expect(parseGs1(']d2010200000000001517270131\u001d10ABC123')).assertEqual('2000000000015');
      expect(parseGs1('(01)02000000000015(17)270131')).assertEqual('2000000000015');
    });

    it('plainTextIsNotAGtin', 0, () => {
      expect(parseGs1('Klacid 500') === undefined).assertTrue();
    });

    it('demoGtinResolves', 0, () => {
      const e = lookupGtin('2000000000046');
      expect(e !== undefined && e.ingredient === 'ondansetron').assertTrue();
    });
  });

  describe('Privacy', () => {
    it('personalFieldsAreBlocked', 0, () => {
      expect(forbiddenFields(['query', 'genotype']).length).assertEqual(0);
      expect(forbiddenFields(['query', 'Name', 'phone']).join(',')).assertEqual('Name,phone');
    });
  });

  describe('Doses', () => {
    it('statusThroughTheDay', 0, () => {
      const r: DoseReminder = reminder(8, 0);
      expect(doseStatus(r, [], at(7, 0))).assertEqual('UPCOMING');
      expect(doseStatus(r, [], at(8, 30))).assertEqual('DUE');
      expect(doseStatus(r, [], at(10, 0))).assertEqual('MISSED');
      const logs: DoseLog[] = [{ reminderId: 7, day: dayKey(at(8, 5)), status: 'TAKEN', ts: at(8, 5) }];
      expect(doseStatus(r, logs, at(10, 0))).assertEqual('TAKEN');
    });
  });

  describe('EmergencyData', () => {
    it('numbersByCountry', 0, () => {
      expect(emergencyFor('pl').ambulance).assertEqual('999');
      expect(emergencyFor('BG').ambulance).assertEqual('150');
      expect(emergencyFor('US').general).assertEqual('911');
      expect(emergencyFor('XX').ambulance).assertEqual('112');
      expect(emergencyFor(undefined).ambulance).assertEqual('112');
    });

    it('thirteenCompleteLanguages', 0, () => {
      expect(CARD_TEXTS.length).assertEqual(13);
      expect(PHARMACY_TEXTS.length).assertEqual(13);
      let empty: string = '';
      for (const t of CARD_TEXTS) {
        if (t.title === '' || t.avoid === '' || t.treatment === '' || t.condition === '') {
          empty += t.code;
        }
      }
      expect(empty).assertEqual('');
      expect(cardText('xx').code).assertEqual('en');
      expect(languageForCountry('AT')).assertEqual('de');
    });
  });

  describe('CoachAndReview', () => {
    it('genotypeTipsComeFirst', 0, () => {
      expect(tipsFor('LQT2')[0].title.startsWith('LQT2')).assertTrue();
      expect(tipOfTheDay('UNKNOWN', 0).title.length > 0).assertTrue();
    });

    it('medsReviewCountsAndPairs', 0, () => {
      const meds: Medication[] = [
        { id: 1, name: 'Cipralex', ingredient: 'escitalopram', dose: '', addedAt: 0 },
        { id: 2, name: 'Seroquel', ingredient: 'quetiapine', dose: '', addedAt: 0 },
        { id: 3, name: 'Concor', ingredient: 'bisoprolol', dose: '', addedAt: 0 }
      ];
      expect(riskCounts(meds).known).assertEqual(1);
      expect(riskCounts(meds).conditional).assertEqual(1);
      expect(medsInteractions(meds).length).assertEqual(1);
    });
  });
}
