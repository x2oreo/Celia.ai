import { describe, it, expect } from '@ohos/hypium';
import { DrugChecker, editDistance, tokenize } from '../main/ets/drugs/DrugChecker';
import { DRUGS, DrugEntry } from '../main/ets/drugs/DrugDataset';
import { ComboVerdict, DrugVerdict } from '../main/ets/model/DrugVerdict';
import { Medication } from '../main/ets/model/Medication';

function med(name: string, ingredient: string): Medication {
  const m: Medication = { id: 1, name: name, ingredient: ingredient, dose: '', addedAt: 0 };
  return m;
}

export default function drugCheckerTest() {
  describe('DrugData', () => {
    it('everyAliasIsUnique', 0, () => {
      const seen: Map<string, string> = new Map<string, string>();
      let duplicates: string = '';
      for (const e of DRUGS) {
        const keys: string[] = [e.ingredient].concat(e.aliases);
        for (const k of keys) {
          const owner: string | undefined = seen.get(k);
          if (owner !== undefined && owner !== e.ingredient) {
            duplicates += `${k}(${owner}/${e.ingredient}) `;
          }
          seen.set(k, e.ingredient);
        }
      }
      expect(duplicates).assertEqual('');
    });

    it('alternativesAreNotListed', 0, () => {
      const checker: DrugChecker = DrugChecker.get();
      let bad: string = '';
      for (const e of DRUGS) {
        for (const alt of e.alternatives) {
          const a: DrugEntry | undefined = checker.entry(alt);
          if (a === undefined || a.risk !== 'NOT_LISTED') {
            bad += `${e.ingredient}->${alt} `;
          }
        }
      }
      expect(bad).assertEqual('');
    });

    it('keysAreLowerCase', 0, () => {
      let bad: string = '';
      for (const e of DRUGS) {
        for (const k of [e.ingredient].concat(e.aliases)) {
          if (k !== k.toLowerCase() || k.trim() !== k) {
            bad += `${k} `;
          }
        }
      }
      expect(bad).assertEqual('');
    });
  });

  describe('DrugChecker', () => {
    const checker: DrugChecker = DrugChecker.get();

    it('brandResolvesToIngredient', 0, () => {
      const v: DrugVerdict = checker.checkSync('Klacid 500 mg tablets');
      expect(v.ingredient).assertEqual('clarithromycin');
      expect(v.risk).assertEqual('KNOWN_RISK');
      expect(v.alternatives !== undefined && v.alternatives.includes('amoxicillin')).assertTrue();
    });

    it('polishGenericResolves', 0, () => {
      const v: DrugVerdict = checker.checkSync('Cyprofloksacyna 500 mg tabletki powlekane');
      expect(v.ingredient).assertEqual('ciprofloxacin');
    });

    it('cyrillicBrandResolves', 0, () => {
      const v: DrugVerdict = checker.checkSync('Сумамед 500 мг таблетки');
      expect(v.ingredient).assertEqual('azithromycin');
      expect(v.risk).assertEqual('KNOWN_RISK');
    });

    it('typoIsCorrectedWithLowerConfidence', 0, () => {
      const v: DrugVerdict = checker.checkSync('ondansetrom');
      expect(v.ingredient).assertEqual('ondansetron');
      expect((v.confidence ?? 1) < 1).assertTrue();
    });

    it('shortUnknownWordIsNotGuessed', 0, () => {
      const v: DrugVerdict = checker.checkSync('zofrx');
      expect(v.risk).assertEqual('UNKNOWN_DRUG');
    });

    it('worstRiskWins', 0, () => {
      const v: DrugVerdict = checker.checkSync('ibuprofen and escitalopram and paracetamol');
      expect(v.risk).assertEqual('KNOWN_RISK');
      expect(v.ingredient).assertEqual('escitalopram');
    });

    it('safeDrugIsNotListed', 0, () => {
      const v: DrugVerdict = checker.checkSync('Nurofen Forte');
      expect(v.risk).assertEqual('NOT_LISTED');
      expect(v.confidence).assertEqual(0.95);
    });

    it('unknownNeverSafe', 0, () => {
      const v: DrugVerdict = checker.checkSync('Ibuprofen + bananaxolol');
      expect(v.risk).assertEqual('UNKNOWN_DRUG');
      expect(v.confidence).assertEqual(0);
    });

    it('stimulantIsFlaggedForCongenitalLqts', 0, () => {
      const v: DrugVerdict = checker.checkSync('Gripex');
      expect(v.ingredient).assertEqual('pseudoephedrine');
      expect(v.risk).assertEqual('CONDITIONAL_RISK');
      expect(v.reason.includes('congenital long QT')).assertTrue();
    });

    it('traceHasOneStepPerWord', 0, () => {
      const v: DrugVerdict = checker.checkSync('Zofran 8 mg');
      expect(v.trace !== undefined && v.trace.length === 1).assertTrue();
      expect(v.trace !== undefined && v.trace[0].kind === 'ALIAS').assertTrue();
    });

    it('suggestFindsBrands', 0, () => {
      const list: DrugEntry[] = checker.suggest('zof', 5);
      expect(list.length > 0 && list[0].ingredient === 'ondansetron').assertTrue();
    });

    it('tokenizeDropsDoseWords', 0, () => {
      expect(tokenize('Cipronex 500 mg film-coated tablets').join(',')).assertEqual('cipronex');
    });

    it('editDistanceBasics', 0, () => {
      expect(editDistance('kitten', 'sitting', 5)).assertEqual(3);
      expect(editDistance('abc', 'abc', 1)).assertEqual(0);
      expect(editDistance('abcdef', 'xyz', 1)).assertEqual(2);
    });
  });

  describe('Combo', () => {
    const checker: DrugChecker = DrugChecker.get();

    it('twoQtDrugsAreAdditive', 0, () => {
      const v: DrugVerdict = checker.checkSync('ondansetron');
      const c: ComboVerdict = checker.checkCombo(v, [med('Cipralex', 'escitalopram')]);
      expect(c.kind).assertEqual('ADDITIVE_QT');
    });

    it('cyp3a4InhibitorRaisesQtDrug', 0, () => {
      const v: DrugVerdict = checker.checkSync('clarithromycin');
      const c: ComboVerdict = checker.checkCombo(v, [med('Seroquel', 'quetiapine')]);
      expect(c.kind).assertEqual('CYP_INTERACTION');
      expect(c.enzyme).assertEqual('CYP3A4');
    });

    it('inhibitorThatIsNotQtStillCounts', 0, () => {
      const v: DrugVerdict = checker.checkSync('domperidone');
      const c: ComboVerdict = checker.checkCombo(v, [med('Isoptin', 'verapamil')]);
      expect(c.kind).assertEqual('CYP_INTERACTION');
    });

    it('safePairIsNone', 0, () => {
      const v: DrugVerdict = checker.checkSync('amoxicillin');
      const c: ComboVerdict = checker.checkCombo(v, [med('Concor', 'bisoprolol')]);
      expect(c.kind).assertEqual('NONE');
    });

    it('everyInteractingMedicineIsReportedEnzymeFirst', 0, () => {
      const v: DrugVerdict = checker.checkSync('ondansetron');
      const all: ComboVerdict[] = checker.checkCombos(v,
        [med('Cipralex', 'escitalopram'), med('Concor', 'bisoprolol'), med('Klacid', 'clarithromycin')]);
      expect(all.length).assertEqual(2);
      expect(all[0].kind).assertEqual('CYP_INTERACTION');
      expect(all[0].drugs[1]).assertEqual('clarithromycin');
      expect(all[1].kind).assertEqual('ADDITIVE_QT');
      expect(checker.checkCombo(v, [med('Cipralex', 'escitalopram'), med('Klacid', 'clarithromycin')]).kind)
        .assertEqual('CYP_INTERACTION');
    });

    it('notListedInhibitorIsFlaggedAgainstMyQtDrug', 0, () => {
      // The checked medicine is "not listed" on its own, but it raises the level of a QT drug I take.
      const diltiazem: DrugVerdict = checker.checkSync('diltiazem');
      expect(diltiazem.risk).assertEqual('NOT_LISTED');
      expect(checker.checkCombo(diltiazem, [med('Motilium', 'domperidone')]).kind).assertEqual('CYP_INTERACTION');
      const grapefruit: DrugVerdict = checker.checkSync('grapefruit juice');
      expect(grapefruit.risk).assertEqual('NOT_LISTED');
      expect(checker.checkCombo(grapefruit, [med('Seroquel', 'quetiapine')]).enzyme).assertEqual('CYP3A4');
    });

    it('cyp2c19InhibitorRaisesCitalopram', 0, () => {
      const v: DrugVerdict = checker.checkSync('omeprazole');
      const c: ComboVerdict = checker.checkCombo(v, [med('Cipramil', 'citalopram')]);
      expect(c.kind).assertEqual('CYP_INTERACTION');
      expect(c.enzyme).assertEqual('CYP2C19');
    });

    it('onlineVerdictStillAddsUp', 0, () => {
      // Resolved by the backend, not in the bundled dataset: no enzyme data, the QT category still counts.
      const online: DrugVerdict = { query: 'newdrug', ingredient: 'newdrugum', risk: 'POSSIBLE_RISK', reason: '',
        source: 'ONLINE' };
      expect(checker.checkCombo(online, [med('Cipralex', 'escitalopram')]).kind).assertEqual('ADDITIVE_QT');
      expect(checker.checkCombo(online, [med('Concor', 'bisoprolol')]).kind).assertEqual('NONE');
    });

    it('sameMedicineTwiceIsOneFinding', 0, () => {
      const v: DrugVerdict = checker.checkSync('ondansetron');
      expect(checker.checkCombos(v, [med('Cipralex', 'escitalopram'), med('Lexapro', 'escitalopram')]).length)
        .assertEqual(1);
    });

    it('unknownDrugHasNoCombo', 0, () => {
      const v: DrugVerdict = checker.checkSync('xyzzyqq');
      const c: ComboVerdict = checker.checkCombo(v, [med('Cipralex', 'escitalopram')]);
      expect(c.kind).assertEqual('NONE');
    });
  });
}
