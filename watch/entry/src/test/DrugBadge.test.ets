import { describe, it, expect } from '@ohos/hypium';
import { DRUG_WINDOW_MS, drugBadgeText, shortDrugName, symptomAfterDrugTitle, timeLeft } from '../main/ets/vitals/DrugBadge';

const H = 3600 * 1000;
const NOW = 1791050000000;

export default function drugBadgeTest() {
  describe('DrugBadge', () => {
    it('capitalisesAndShortensNames', 0, () => {
      expect(shortDrugName('clarithromycin')).assertEqual('Clarithromycin');
      expect(shortDrugName('hydroxychloroquine')).assertEqual('Hydroxychloro…');
      expect(shortDrugName('  ')).assertEqual('');
    });

    it('countsDownTheWatchWindow', 0, () => {
      expect(timeLeft(NOW, NOW)).assertEqual('3d left');
      expect(timeLeft(NOW - 30 * H, NOW)).assertEqual('1d left');
      expect(timeLeft(NOW - 66 * H, NOW)).assertEqual('6h left');
      expect(timeLeft(NOW - 71.5 * H, NOW)).assertEqual('<1h left');
      expect(timeLeft(NOW - DRUG_WINDOW_MS, NOW)).assertEqual('');
    });

    it('badgeDisappearsAfterTheWindow', 0, () => {
      expect(drugBadgeText('clarithromycin', NOW - 20 * H, NOW)).assertEqual('Clarithromycin · 2d left');
      expect(drugBadgeText('clarithromycin', NOW - 73 * H, NOW)).assertEqual('');
      expect(drugBadgeText('', NOW, NOW)).assertEqual('');
    });

    it('unknownTimeStillNamesTheDrug', 0, () => {
      expect(drugBadgeText('ondansetron', 0, NOW)).assertEqual('Ondansetron');
    });

    it('symptomWithin24hAfterTheDrugWarns', 0, () => {
      expect(symptomAfterDrugTitle('dizziness', 'clarithromycin', NOW - 3 * H, NOW)).assertEqual('Dizzy after Clarithromycin');
      expect(symptomAfterDrugTitle('palpitations', 'clarithromycin', NOW - 23 * H, NOW))
        .assertEqual('Racing heart after Clarithromycin');
    });

    it('noWarningForFineOldOrMissingDrug', 0, () => {
      expect(symptomAfterDrugTitle('fine', 'clarithromycin', NOW - H, NOW)).assertEqual('');
      expect(symptomAfterDrugTitle('dizziness', 'clarithromycin', NOW - 25 * H, NOW)).assertEqual('');
      expect(symptomAfterDrugTitle('dizziness', '', NOW - H, NOW)).assertEqual('');
      expect(symptomAfterDrugTitle('dizziness', 'clarithromycin', 0, NOW)).assertEqual('');
    });
  });
}
