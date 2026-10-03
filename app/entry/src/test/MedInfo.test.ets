import { describe, it, expect } from '@ohos/hypium';
import { DRUGS, DrugEntry } from '../main/ets/drugs/DrugDataset';
import { DRUG_INFO, DrugInfo, drugInfo, INFO_LINE_MAX, INFO_TIP_MAX } from '../main/ets/drugs/DrugInfo';
import { MedFacts, medFacts, medSubtitle } from '../main/ets/drugs/MedFacts';
import { checkCached, classifyMedInfo, parseMedInfo } from '../main/ets/drugs/MedInfoClient';
import { Medication } from '../main/ets/model/Medication';

function med(id: number, name: string, ingredient: string): Medication {
  const m: Medication = { id: id, name: name, ingredient: ingredient, dose: '', addedAt: 0 };
  return m;
}

export default function medInfoTest() {
  describe('DrugInfo', () => {
    it('everyDrugHasInfo', 0, () => {
      let missing: string = '';
      for (const e of DRUGS) {
        if (drugInfo(e.ingredient) === undefined) {
          missing += `${e.ingredient} `;
        }
      }
      expect(missing).assertEqual('');
    });

    it('infoIsShortAndKnown', 0, () => {
      let bad: string = '';
      for (const e of DRUG_INFO) {
        const known: boolean = DRUGS.some((d: DrugEntry) => d.ingredient === e.ingredient);
        const tooLong: boolean = e.usedFor.length > INFO_LINE_MAX || e.howItWorks.length > INFO_LINE_MAX ||
          e.tips.some((t: string) => t.length > INFO_LINE_MAX);
        if (!known || tooLong || e.tips.length > INFO_TIP_MAX || e.usedFor.length === 0) {
          bad += `${e.ingredient} `;
        }
      }
      expect(bad).assertEqual('');
    });

    it('lookupIgnoresCase', 0, () => {
      const i: DrugInfo | undefined = drugInfo(' Nadolol ');
      expect(i !== undefined).assertTrue();
    });
  });

  describe('MedFacts', () => {
    it('brandResolvesToIngredientFacts', 0, () => {
      const f: MedFacts = medFacts(med(1, 'Zofran', ''), []);
      expect(f.known).assertTrue();
      expect(f.ingredient).assertEqual('ondansetron');
      expect(f.risk).assertEqual('KNOWN_RISK');
      expect(f.usedFor.length > 0).assertTrue();
      expect(f.brands.includes('Zofran')).assertFalse();
    });

    it('unknownStaysUnknown', 0, () => {
      const f: MedFacts = medFacts(med(1, 'Mysteryzol', ''), []);
      expect(f.known).assertFalse();
      expect(f.risk).assertEqual('UNKNOWN_DRUG');
      expect(f.tips.length).assertEqual(0);
      expect(medSubtitle(med(1, 'Mysteryzol', ''))).assertEqual('');
    });

    it('findsInteractionWithMyMeds', 0, () => {
      const mine: Medication[] = [med(1, 'clarithromycin', 'clarithromycin'), med(2, 'ondansetron', 'ondansetron')];
      const f: MedFacts = medFacts(mine[0], mine);
      expect(f.interactions.length).assertEqual(1);
    });

    it('notListedHasNoAlternatives', 0, () => {
      const f: MedFacts = medFacts(med(1, 'nadolol', 'nadolol'), []);
      expect(f.risk).assertEqual('NOT_LISTED');
      expect(f.alternatives.length).assertEqual(0);
    });
  });

  describe('MedInfoClient', () => {
    it('acceptsValidReply', 0, () => {
      const raw: string = '{"recognised":true,"summary":"An antibiotic.","contains":"Amoxicillin","usedFor":' +
        '"Infections","tips":["Finish the course."]}';
      expect(parseMedInfo(raw, 1)?.summary).assertEqual('An antibiotic.');
    });

    it('rejectsBadJsonUnknownAndSafetyTalk', 0, () => {
      expect(parseMedInfo('not json', 1) === undefined).assertTrue();
      expect(parseMedInfo('{"recognised":false,"summary":"","contains":"","usedFor":"","tips":[]}', 1) ===
        undefined).assertTrue();
      const qt: string = '{"recognised":true,"summary":"Safe, does not prolong QT.","contains":"x","usedFor":"y",' +
        '"tips":[]}';
      expect(parseMedInfo(qt, 1) === undefined).assertTrue();
      const dose: string = '{"recognised":true,"summary":"A painkiller.","contains":"x","usedFor":"y",' +
        '"tips":["Take 500 mg twice a day."]}';
      expect(parseMedInfo(dose, 1) === undefined).assertTrue();
    });

    it('rejectsWordFamiliesNotJustExactWords', 0, () => {
      const bad: string[] = ['Can cause arrhythmias.', 'Rarely torsades de pointes.', 'May lengthen the QTc.',
        'Usually 500mg.', 'Children 2.5 mg.', 'Talk to us about heart rhythm.'];
      for (const t of bad) {
        const raw: string = `{"recognised":true,"summary":"${t}","contains":"x","usedFor":"y","tips":[]}`;
        expect(classifyMedInfo(raw, 1).result).assertEqual('REJECTED');
      }
    });

    it('tellsRejectedFromUnknown', 0, () => {
      const unknown: string = '{"recognised":false,"summary":"","contains":"","usedFor":"","tips":[]}';
      const dropped: string = '{"recognised":false,"dropped":true,"summary":"","contains":"","usedFor":"","tips":[]}';
      expect(classifyMedInfo(unknown, 1).result).assertEqual('NOT_RECOGNISED');
      expect(classifyMedInfo(dropped, 1).result).assertEqual('REJECTED');
      expect(classifyMedInfo('not json', 1).result).assertEqual('REJECTED');
    });

    it('cacheExpiresAndIsRechecked', 0, () => {
      const day: number = 24 * 3600 * 1000;
      const good: string = '{"summary":"An antibiotic.","contains":"x","usedFor":"y","tips":[],"fetchedAt":0}';
      expect(checkCached(good, 29 * day)?.summary).assertEqual('An antibiotic.');
      expect(checkCached(good, 31 * day) === undefined).assertTrue();
      const tampered: string = '{"summary":"Prolongs QT.","contains":"x","usedFor":"y","tips":[],"fetchedAt":0}';
      expect(checkCached(tampered, day) === undefined).assertTrue();
      expect(checkCached('', day) === undefined).assertTrue();
      expect(checkCached('{bad', day) === undefined).assertTrue();
    });
  });
}
