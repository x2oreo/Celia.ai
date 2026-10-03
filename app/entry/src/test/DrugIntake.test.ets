import { describe, it, expect } from '@ohos/hypium';
import { CheckOutcome } from '../main/ets/drugs/CheckService';
import { WATCH_WINDOW_MS, intakeName, intakeRisk, riskToLog } from '../main/ets/drugs/DrugIntake';
import { ComboVerdict, DrugVerdict, RiskLevel } from '../main/ets/model/DrugVerdict';

function outcome(risk: RiskLevel, ingredient: string, query: string, comboKind: string): CheckOutcome {
  const v: DrugVerdict = JSON.parse(JSON.stringify({
    query: query, ingredient: ingredient, risk: risk, drugClass: '', reason: '', source: '', avoidCongenital: false,
    confidence: 1, trace: [], alternatives: []
  })) as DrugVerdict;
  const c: ComboVerdict = JSON.parse(JSON.stringify({ kind: comboKind, drugs: [], enzyme: '', reason: '' })) as ComboVerdict;
  return new CheckOutcome(v, c);
}

export default function drugIntakeTest() {
  describe('DrugIntake', () => {
    it('riskyVerdictsCanBeLogged', 0, () => {
      expect(intakeRisk(outcome('KNOWN_RISK', 'clarithromycin', 'Klacid', 'NONE'))).assertEqual('KNOWN_RISK');
      expect(intakeRisk(outcome('POSSIBLE_RISK', 'x', 'x', 'NONE'))).assertEqual('POSSIBLE_RISK');
      expect(intakeRisk(outcome('CONDITIONAL_RISK', 'x', 'x', 'NONE'))).assertEqual('CONDITIONAL_RISK');
    });

    it('notListedOnlyWithARiskyCombination', 0, () => {
      expect(intakeRisk(outcome('NOT_LISTED', 'ibuprofen', 'Ibuprom', 'NONE'))).assertEqual('');
      expect(intakeRisk(outcome('NOT_LISTED', 'x', 'x', 'CYP_INTERACTION'))).assertEqual('POSSIBLE_RISK');
    });

    it('unknownMedicinesAreNeverLogged', 0, () => {
      expect(intakeRisk(outcome('UNKNOWN_DRUG', '', 'mystery pill', 'NONE'))).assertEqual('');
    });

    it('logsTheIngredientWhenKnown', 0, () => {
      expect(intakeName(outcome('KNOWN_RISK', 'clarithromycin', 'Klacid', 'NONE'))).assertEqual('clarithromycin');
      expect(intakeName(outcome('KNOWN_RISK', '', 'Klacid', 'NONE'))).assertEqual('Klacid');
    });

    it('myMedicinesUseTheSameRule', 0, () => {
      expect(riskToLog('KNOWN_RISK', false)).assertEqual('KNOWN_RISK');
      expect(riskToLog('NOT_LISTED', true)).assertEqual('POSSIBLE_RISK');
      expect(riskToLog('NOT_LISTED', false)).assertEqual('');
      expect(riskToLog('UNKNOWN_DRUG', true)).assertEqual('');
    });

    it('watchWindowMatchesTheWatch', 0, () => {
      expect(WATCH_WINDOW_MS).assertEqual(72 * 3600 * 1000);
    });
  });
}
