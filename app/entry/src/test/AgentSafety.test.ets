// AI-safety tests: deterministic interaction rules, emergency pre-filter, model-output validation.
// Pure logic — runs locally without a device (app/scripts/test.sh).

import { describe, it, expect } from '@ohos/hypium';
import { DrugVerdict, RiskLevel } from '../main/ets/model/DrugVerdict';
import { InteractionFinding, VerdictCardPayload } from '../main/ets/model/AgentTypes';
import { ComboResult, escalate, evaluateCombo } from '../main/ets/safety/ComboRules';
import { SafetyGate } from '../main/ets/safety/SafetyGate';
import { EmergencyNumbers } from '../main/ets/safety/EmergencyNumbers';
import {
  checkFinalText, hasReassurance, parseArgs, parseRelay, RelayResponse, TextCheck
} from '../main/ets/agent/ResponseValidator';
import { parseOfflineIntent, ParsedIntent } from '../main/ets/agent/OfflineAgent';
import { ToolRegistry } from '../main/ets/agent/ToolRegistry';

function v(ingredient: string, risk: RiskLevel): DrugVerdict {
  const d: DrugVerdict = { query: ingredient, ingredient: ingredient, risk: risk, reason: '', source: 'test' };
  return d;
}

function card(ingredient: string, risk: string, combinedRisk: string): VerdictCardPayload {
  const findings: InteractionFinding[] = [];
  const c: VerdictCardPayload = {
    query: ingredient, ingredient: ingredient, risk: risk, combinedRisk: combinedRisk, reason: '', source: 'test',
    findings: findings
  };
  return c;
}

function kinds(r: ComboResult): string {
  return r.findings.map((f: InteractionFinding) => f.kind).join(',');
}

// Must equal TOOL_NAMES in backend/supabase/functions/_shared/tools.ts.
const BACKEND_TOOLS: string[] = ['check_drug', 'get_my_meds', 'get_vitals_summary', 'explain_condition',
  'suggest_alternatives', 'scan_medicine', 'add_med', 'show_emergency_card', 'start_emergency',
  'share_emergency_card'];

export default function agentSafetyTest() {
  describe('ComboRules', () => {
    it('noCurrentMedsKeepsRisk', 0, () => {
      const r: ComboResult = evaluateCombo(v('clarithromycin', 'KNOWN_RISK'), []);
      expect(r.combinedRisk).assertEqual('KNOWN_RISK');
      expect(r.findings.length).assertEqual(0);
    });

    it('additiveQtEscalates', 0, () => {
      const r: ComboResult = evaluateCombo(v('mirtazapine', 'POSSIBLE_RISK'), [v('quetiapine', 'CONDITIONAL_RISK')]);
      expect(kinds(r)).assertEqual('ADDITIVE_QT');
      expect(r.combinedRisk).assertEqual('KNOWN_RISK');
    });

    it('cypInhibitorOnQtSubstrateIsFlaggedBothWays', 0, () => {
      const forward: ComboResult = evaluateCombo(v('clarithromycin', 'KNOWN_RISK'), [v('escitalopram', 'KNOWN_RISK')]);
      expect(kinds(forward)).assertEqual('ADDITIVE_QT,CYP_INHIBITION');
      const backward: ComboResult = evaluateCombo(v('escitalopram', 'KNOWN_RISK'), [v('clarithromycin', 'KNOWN_RISK')]);
      expect(kinds(backward)).assertEqual('ADDITIVE_QT,CYP_INHIBITION');
    });

    it('notListedInhibitorOfQtDrugEscalates', 0, () => {
      const r: ComboResult = evaluateCombo(v('grapefruit', 'NOT_LISTED'), [v('quetiapine', 'CONDITIONAL_RISK')]);
      expect(kinds(r)).assertEqual('CYP_INHIBITION');
      expect(r.combinedRisk).assertEqual('POSSIBLE_RISK');
    });

    it('harmlessPairHasNoFindings', 0, () => {
      const r: ComboResult = evaluateCombo(v('paracetamol', 'NOT_LISTED'), [v('nadolol', 'NOT_LISTED')]);
      expect(r.findings.length).assertEqual(0);
      expect(r.combinedRisk).assertEqual('NOT_LISTED');
    });

    it('threeQtDrugsFlagged', 0, () => {
      const r: ComboResult = evaluateCombo(v('ondansetron', 'KNOWN_RISK'),
        [v('citalopram', 'KNOWN_RISK'), v('quetiapine', 'CONDITIONAL_RISK')]);
      expect(kinds(r).includes('MANY_QT_DRUGS')).assertTrue();
    });

    it('unknownDrugIsNeverEscalatedIntoAListedCategory', 0, () => {
      expect(escalate('UNKNOWN_DRUG')).assertEqual('UNKNOWN_DRUG');
      const r: ComboResult = evaluateCombo(v('', 'UNKNOWN_DRUG'), [v('citalopram', 'KNOWN_RISK'),
        v('haloperidol', 'KNOWN_RISK'), v('methadone', 'KNOWN_RISK')]);
      expect(r.combinedRisk).assertEqual('UNKNOWN_DRUG');
    });

    it('sameDrugAlreadyTakenIsNotAnInteraction', 0, () => {
      const r: ComboResult = evaluateCombo(v('sotalol', 'KNOWN_RISK'), [v('sotalol', 'KNOWN_RISK')]);
      expect(r.findings.length).assertEqual(0);
    });
  });

  describe('SafetyGate', () => {
    it('redFlagsTriggerEmergency', 0, () => {
      const phrases: string[] = ['I think I fainted', 'I passed out at the pool', 'I have chest pain',
        "I can't breathe", 'my heart is racing and I feel dizzy', 'please help, I feel strange',
        'Zemdlałam w pracy', 'call an ambulance'];
      for (const p of phrases) {
        expect(SafetyGate.classify(p, false)).assertEqual('EMERGENCY');
      }
    });

    it('normalQuestionsDoNotTrigger', 0, () => {
      const phrases: string[] = ['Can I take ibuprofen?', 'show my emergency card', 'help me find an alternative',
        'what does LQT2 mean', 'is my heart rate okay today'];
      for (const p of phrases) {
        expect(SafetyGate.classify(p, false)).assertEqual('NONE');
      }
    });

    it('checkInAnswersOnlyCountWhenPending', 0, () => {
      expect(SafetyGate.classify('I feel unwell', true)).assertEqual('UNWELL');
      expect(SafetyGate.classify("I'm OK", true)).assertEqual('OK');
      expect(SafetyGate.classify('I was running', true)).assertEqual('OK');
      expect(SafetyGate.classify('I feel unwell', false)).assertEqual('NONE');
    });

    it('emergencyNumberByRegion', 0, () => {
      expect(EmergencyNumbers.forRegion('PL')).assertEqual('112');
      expect(EmergencyNumbers.forRegion('us')).assertEqual('911');
      expect(EmergencyNumbers.forRegion('GB')).assertEqual('999');
      expect(EmergencyNumbers.forRegion('')).assertEqual('112');
    });
  });

  describe('ResponseValidator', () => {
    it('parsesValidRelayResponse', 0, () => {
      const r: RelayResponse | undefined = parseRelay(
        '{"promptVersion":"x","responseId":"resp_1","text":"","toolCalls":[{"callId":"c1","name":"check_drug",' +
          '"arguments":"{\\"name\\":\\"Klacid\\"}"}]}');
      expect(r !== undefined).assertTrue();
      expect((r as RelayResponse).toolCalls[0].name).assertEqual('check_drug');
    });

    it('rejectsMalformedRelayResponses', 0, () => {
      expect(parseRelay('{"oops": <<not json>>') === undefined).assertTrue();
      expect(parseRelay('[]') === undefined).assertTrue();
      expect(parseRelay('{"responseId":"r","text":"hi"}') === undefined).assertTrue();
      expect(parseRelay('{"responseId":"r","text":"hi","toolCalls":[{"callId":1}]}') === undefined).assertTrue();
    });

    it('rejectsNonObjectToolArguments', 0, () => {
      expect(parseArgs('{"name":"x"}') !== undefined).assertTrue();
      expect(parseArgs('"x"') === undefined).assertTrue();
      expect(parseArgs('[1]') === undefined).assertTrue();
      expect(parseArgs('nope') === undefined).assertTrue();
    });

    it('detectsReassuranceButNotNegations', 0, () => {
      expect(hasReassurance('Klacid is safe for you.')).assertTrue();
      expect(hasReassurance('It is fine to take with nadolol.')).assertTrue();
      expect(hasReassurance('There is no QT risk.')).assertTrue();
      expect(hasReassurance('Klacid is not safe for you.')).assertFalse();
      expect(hasReassurance("It isn't okay to take it without asking.")).assertFalse();
    });

    it('replacesTextThatReassuresAboutRiskyDrug', 0, () => {
      const c: TextCheck = checkFinalText('Clarithromycin is safe, go for it.',
        [card('clarithromycin', 'KNOWN_RISK', 'KNOWN_RISK')]);
      expect(c.issue).assertEqual('REASSURES_RISKY');
      expect(c.text.includes('known-risk list')).assertTrue();
    });

    it('replacesTextThatOmitsTheRisk', 0, () => {
      const c: TextCheck = checkFinalText('Clarithromycin is an antibiotic used for chest infections.',
        [card('clarithromycin', 'KNOWN_RISK', 'KNOWN_RISK')]);
      expect(c.issue).assertEqual('DOWNPLAYS_VERDICT');
    });

    it('unknownDrugMustSendUserToPharmacist', 0, () => {
      const bad: TextCheck = checkFinalText('I could not find that one.', [card('', 'UNKNOWN_DRUG', 'UNKNOWN_DRUG')]);
      expect(bad.issue).assertEqual('DOWNPLAYS_VERDICT');
      const good: TextCheck = checkFinalText('I could not find it. Please ask a pharmacist first.',
        [card('', 'UNKNOWN_DRUG', 'UNKNOWN_DRUG')]);
      expect(good.issue).assertEqual('NONE');
    });

    it('keepsFaithfulText', 0, () => {
      const c: TextCheck = checkFinalText('Clarithromycin is on the known-risk list, so avoid it. Ask your doctor.',
        [card('clarithromycin', 'KNOWN_RISK', 'KNOWN_RISK')]);
      expect(c.issue).assertEqual('NONE');
    });

    it('blocksUngroundedSafetyClaimsButAllowsOtherReassurance', 0, () => {
      expect(checkFinalText('Ibuprofen is safe to take.', []).issue).assertEqual('REASSURES_RISKY');
      expect(checkFinalText('Your heart rate is fine right now.', []).issue).assertEqual('NONE');
    });

    it('emptyTextFallsBack', 0, () => {
      expect(checkFinalText('   ', []).issue).assertEqual('EMPTY');
    });
  });

  describe('OfflineAgent', () => {
    it('extractsDrugFromQuestions', 0, () => {
      const cases: string[][] = [
        ['Can I take Klacid 500 mg?', 'klacid 500 mg'],
        ['is ibuprofen safe for me?', 'ibuprofen'],
        ['what about ondansetron', 'ondansetron'],
        ['Czy mogę wziąć apap?', 'apap'],
        ['Nurofen', 'nurofen']
      ];
      for (const c of cases) {
        const p: ParsedIntent = parseOfflineIntent(c[0]);
        expect(p.intent).assertEqual('CHECK_DRUG');
        expect(p.drug).assertEqual(c[1]);
      }
    });

    it('routesOtherIntents', 0, () => {
      expect(parseOfflineIntent('show my emergency card').intent).assertEqual('EMERGENCY_CARD');
      expect(parseOfflineIntent('let me scan the box').intent).assertEqual('SCAN');
      expect(parseOfflineIntent('what are my meds').intent).assertEqual('MY_MEDS');
      expect(parseOfflineIntent('hello').intent).assertEqual('UNKNOWN');
    });
  });

  describe('ToolRegistry', () => {
    it('matchesBackendToolSchemas', 0, () => {
      const names: string[] = new ToolRegistry().names().sort();
      expect(names.join(',')).assertEqual(BACKEND_TOOLS.slice().sort().join(','));
    });
  });
}
