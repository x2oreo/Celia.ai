// AI-safety tests: deterministic interaction rules, emergency pre-filter, model-output validation.
// Pure logic - runs locally without a device (app/scripts/test.sh).

import { describe, it, expect } from '@ohos/hypium';
import { DrugVerdict, RiskLevel } from '../main/ets/model/DrugVerdict';
import { InteractionFinding, UiAction, VerdictCardPayload } from '../main/ets/model/AgentTypes';
import { ComboResult, escalate, evaluateCombo } from '../main/ets/safety/ComboRules';
import { SafetyGate } from '../main/ets/safety/SafetyGate';
import { EmergencyNumbers } from '../main/ets/safety/EmergencyNumbers';
import {
  checkFinalText, hasReassurance, parseArgs, parseRelay, RelayResponse, TextCheck
} from '../main/ets/agent/ResponseValidator';
import {
  dosesText, OfflineAgent, parseOfflineIntent, ParsedIntent, remindersText, symptomLogText
} from '../main/ets/agent/OfflineAgent';
import {
  OpenRemindersTool, OpenSymptomLogTool, symptomLogOutput, SymptomLogOutput
} from '../main/ets/agent/tools/CareTools';
import { AgentReply, OPEN_PAGES, OpenPagePayload } from '../main/ets/model/AgentTypes';
import { ToolRegistry } from '../main/ets/agent/ToolRegistry';
import { TurnState } from '../main/ets/agent/ToolTypes';
import { ExplainConditionTool } from '../main/ets/agent/tools/InfoTools';
import { LogSymptomTool } from '../main/ets/agent/tools/SymptomTools';
import { buildSymptomEntry, parseSymptom, SymptomEntry } from '../main/ets/model/SymptomEntry';
import { VitalsSample } from '../main/ets/model/Vitals';
import { LocalStore } from '../main/ets/data/LocalStore';
import { AppEvent } from '../main/ets/model/AppEvent';

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
  'share_emergency_card', 'start_new_chat', 'log_symptom', 'prepare_doctor_visit', 'get_dose_status',
  'get_trends', 'open_symptom_log', 'open_reminders', 'log_dose'];

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

    it('typographicApostrophesStillTrigger', 0, () => {
      expect(SafetyGate.classify('I can\u2019t breathe', false)).assertEqual('EMERGENCY');
      expect(SafetyGate.classify('it\u2019s an emergency', false)).assertEqual('EMERGENCY');
      expect(SafetyGate.classify('I don\u2019t feel well', true)).assertEqual('UNWELL');
      expect(SafetyGate.classify('I\u2019m OK', true)).assertEqual('OK');
    });

    it('checkInAnswersOnlyCountWhenPending', 0, () => {
      expect(SafetyGate.classify('I feel unwell', true)).assertEqual('UNWELL');
      expect(SafetyGate.classify("I'm OK", true)).assertEqual('OK');
      expect(SafetyGate.classify('I was running', true)).assertEqual('OK');
      expect(SafetyGate.classify('I feel unwell', false)).assertEqual('NONE');
    });

    it('emergencyNumberByRegion', 0, () => {
      expect(EmergencyNumbers.forRegion('PL')).assertEqual('999');   // ambulance; same table as the SOS screen
      expect(EmergencyNumbers.forRegion('DE')).assertEqual('112');
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

    it('typographicApostrophesAreNormalised', 0, () => {
      expect(hasReassurance('It\u2019s safe for you.')).assertTrue();
      expect(hasReassurance('Ibuprofen isn\u2019t harmless for everyone.')).assertFalse();
    });

    it('deniedReassuranceIsNotReassurance', 0, () => {
      expect(hasReassurance('That does not mean the combination is safe.')).assertFalse();
      expect(hasReassurance('It is not on the lists, but that doesn\u2019t mean it\u2019s safe.')).assertFalse();
      expect(hasReassurance('It is not on the list. It is safe.')).assertTrue();
      const c: TextCheck = checkFinalText('No interaction with nadolol was flagged, but that does not mean the ' +
        'combination is safe. Klacid is on the known-risk list, so avoid it. Ask your doctor.',
        [card('clarithromycin', 'KNOWN_RISK', 'KNOWN_RISK')]);
      expect(c.issue).assertEqual('NONE');
    });

    it('emDashesBecomePlainDashes', 0, () => {
      const c: TextCheck = checkFinalText('Your heart rate looks steady \u2014 nice work.', []);
      expect(c.text).assertEqual('Your heart rate looks steady - nice work.');
    });

    it('polishReassuranceIsCaught', 0, () => {
      expect(hasReassurance('Apap jest bezpieczny.')).assertTrue();
      expect(hasReassurance('Można go bezpiecznie przyjmować.')).assertTrue();
      expect(hasReassurance('Nie ma żadnego ryzyka.')).assertTrue();
      expect(hasReassurance('Apap nie jest bezpieczny.')).assertFalse();
      expect(hasReassurance('To nie oznacza, że jest bezpieczny dla każdego.')).assertFalse();
      expect(checkFinalText('Apap jest bezpieczny, możesz go wziąć.', []).issue).assertEqual('REASSURES_RISKY');
    });

    it('polishVerdictWordingIsAccepted', 0, () => {
      const known: TextCheck = checkFinalText('Klacid jest na liście leków o znanym ryzyku wydłużenia QT. Unikaj go ' +
        'i skonsultuj się z lekarzem.', [card('clarithromycin', 'KNOWN_RISK', 'KNOWN_RISK')]);
      expect(known.issue).assertEqual('NONE');
      const unknown: TextCheck = checkFinalText('Nie znalazłam tego leku. Zapytaj farmaceutę.',
        [card('', 'UNKNOWN_DRUG', 'UNKNOWN_DRUG')]);
      expect(unknown.issue).assertEqual('NONE');
    });

    it('conditionalRiskMustMentionTheRisk', 0, () => {
      expect(checkFinalText('Loperamide is used for diarrhoea.', [card('loperamide', 'CONDITIONAL_RISK',
        'CONDITIONAL_RISK')]).issue).assertEqual('DOWNPLAYS_VERDICT');
      expect(checkFinalText('Loperamide needs caution; check with your doctor.', [card('loperamide',
        'CONDITIONAL_RISK', 'CONDITIONAL_RISK')]).issue).assertEqual('NONE');
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
        ['Nurofen', 'nurofen'],
        // "Ask Celia about this" from the check screen (found on the emulator: the drug came out as "it")
        ['I was offered Zofran (ondansetron). Is it safe for me, and what should I ask my doctor?', 'zofran (ondansetron)'],
        ['My doctor prescribed sotalol, is that ok?', 'sotalol']
      ];
      for (const c of cases) {
        const p: ParsedIntent = parseOfflineIntent(c[0]);
        expect(p.intent).assertEqual('CHECK_DRUG');
        expect(p.drug).assertEqual(c[1]);
      }
    });

    it('neverTakesAPronounAsTheDrug', 0, () => {
      expect(parseOfflineIntent('is it safe?').intent).assertEqual('UNKNOWN');
      expect(parseOfflineIntent('Is this OK for my heart?').drug === 'this').assertFalse();
    });

    it('routesOtherIntents', 0, () => {
      expect(parseOfflineIntent('show my emergency card').intent).assertEqual('EMERGENCY_CARD');
      expect(parseOfflineIntent('let me scan the box').intent).assertEqual('SCAN');
      expect(parseOfflineIntent('what are my meds').intent).assertEqual('MY_MEDS');
      expect(parseOfflineIntent('Check my current medicines').intent).assertEqual('MY_MEDS');
      expect(parseOfflineIntent('hello').intent).assertEqual('UNKNOWN');
    });

    it('routesPageIntentsBeforeMedicinePatterns', 0, () => {
      expect(parseOfflineIntent('Show me my symptom log').intent).assertEqual('SYMPTOM_LOG');
      expect(parseOfflineIntent('look at my past symptoms').intent).assertEqual('SYMPTOM_LOG');
      expect(parseOfflineIntent('check my reminders').intent).assertEqual('REMINDERS');
      expect(parseOfflineIntent('Remind me to take nadolol').intent).assertEqual('REMINDERS');
      expect(parseOfflineIntent('Did I take my nadolol today?').intent).assertEqual('DOSES');
      expect(parseOfflineIntent("what's due today").intent).assertEqual('DOSES');
      expect(parseOfflineIntent('How have I been the last two weeks?').intent).assertEqual('TRENDS');
      // A medicine question stays a medicine question.
      expect(parseOfflineIntent('Can I take ibuprofen today?').intent).assertEqual('CHECK_DRUG');
    });

    it('pageIntentsAnswerWithATileAndNoModel', 0, async () => {
      const log: AgentReply = await OfflineAgent.answer('open my symptom log', 'offline');
      expect(log.fallback).assertTrue();
      expect(log.actions.length).assertEqual(1);
      expect((JSON.parse(log.actions[0].payload) as OpenPagePayload).page).assertEqual('SYMPTOM_LOG');
      const rem: AgentReply = await OfflineAgent.answer('open my reminders', 'offline');
      expect((JSON.parse(rem.actions[0].payload) as OpenPagePayload).page).assertEqual('REMINDERS');
      const doses: AgentReply = await OfflineAgent.answer('did I take my nadolol?', 'offline');
      expect((JSON.parse(doses.actions[0].payload) as OpenPagePayload).page).assertEqual('REMINDERS');
    });

    it('pageTextsAreFixedSentences', 0, () => {
      const empty: SymptomLogOutput = { entriesLast30Days: 0, recent: [], note: '' };
      expect(symptomLogText(empty).includes('no symptoms logged')).assertTrue();
      const one: SymptomLogOutput = {
        entriesLast30Days: 1, recent: [{ symptom: 'Chest pain', severity: 4, activity: 'resting', daysAgo: 1 }], note: ''
      };
      expect(symptomLogText(one).includes('1 symptom in')).assertTrue();
      expect(symptomLogText(one).includes('chest pain, yesterday')).assertTrue();
      expect(remindersText([]).includes('No reminders')).assertTrue();
      expect(remindersText([{ medicine: 'Nadolol', time: '08:00' }]).includes('Nadolol at 08:00')).assertTrue();
      expect(dosesText([{ medicine: 'Nadolol', time: '08:00', status: 'MISSED' }]).includes('Nadolol 08:00 missed'))
        .assertTrue();
      expect(dosesText([]).includes('No reminders')).assertTrue();
    });
  });

  describe('PageTools', () => {
    it('symptomLogKeepsLast30DaysNewestFirst', 0, () => {
      const day: number = 24 * 60 * 60 * 1000;
      const now: number = 100 * day;
      const entry = (s: string, sev: number): string => {
        const e: SymptomEntry = {
          symptom: parseSymptom(s) ?? 'OTHER', severity: sev, activity: 'resting', note: 'private words', hrMin: 60,
          hrMax: 80
        };
        return JSON.stringify(e);
      };
      const events: AppEvent[] = [
        { id: 1, ts: now - 40 * day, kind: 'SYMPTOM', detail: entry('FAINTING', 5) },
        { id: 2, ts: now - 3 * day, kind: 'SYMPTOM', detail: entry('DIZZINESS', 2) },
        { id: 3, ts: now - 2 * day, kind: 'DOSE', detail: '{}' },
        { id: 4, ts: now - day - 1000, kind: 'SYMPTOM', detail: 'not json' },
        { id: 5, ts: now - 1000, kind: 'SYMPTOM', detail: entry('PALPITATIONS', 3) }
      ];
      const out: SymptomLogOutput = symptomLogOutput(events, now);
      expect(out.entriesLast30Days).assertEqual(2);
      expect(out.recent[0].symptom).assertEqual('Palpitations');
      expect(out.recent[0].daysAgo).assertEqual(0);
      expect(out.recent[1].symptom).assertEqual('Dizziness');
      expect(out.recent[1].daysAgo).assertEqual(3);
      // The free-text note and the heart rate stay on the phone: the model gets neither.
      expect(JSON.stringify(out).includes('private words')).assertFalse();
      expect(JSON.stringify(out).includes('hrMin')).assertFalse();
      expect(symptomLogOutput([], now).note.startsWith('No symptoms')).assertTrue();
    });

    it('openSymptomLogPushesOneTileAndWritesNothing', 0, async () => {
      const before: number = (await LocalStore.get().listEvents()).length;
      const turn: TurnState = new TurnState();
      const out: string = await new OpenSymptomLogTool().execute({}, turn);
      expect(out.includes('entriesLast30Days')).assertTrue();
      expect(turn.actions.length).assertEqual(1);
      expect(turn.actions[0].type).assertEqual('OPEN_PAGE');
      expect((JSON.parse(turn.actions[0].payload) as OpenPagePayload).page).assertEqual('SYMPTOM_LOG');
      expect(turn.pending.length).assertEqual(0);
      expect((await LocalStore.get().listEvents()).length).assertEqual(before);
    });

    it('openRemindersPushesOneTileAndSaysItCannotEdit', 0, async () => {
      const turn: TurnState = new TurnState();
      const out: string = await new OpenRemindersTool().execute({}, turn);
      expect(out.includes('You cannot add, change or delete')).assertTrue();
      expect(turn.actions.length).assertEqual(1);
      expect((JSON.parse(turn.actions[0].payload) as OpenPagePayload).page).assertEqual('REMINDERS');
      expect(turn.pending.length).assertEqual(0);
    });

    it('everyPageAToolOpensIsListed', 0, async () => {
      const reg: ToolRegistry = new ToolRegistry();
      const calls: string[][] = [
        ['prepare_doctor_visit', '{"specialty":"DENTIST"}'], ['get_dose_status', '{}'], ['get_trends', '{"days":14}'],
        ['open_symptom_log', '{}'], ['open_reminders', '{}']
      ];
      for (const c of calls) {
        const turn: TurnState = new TurnState();
        await reg.run(c[0], c[1], turn);
        expect(turn.actions.length).assertEqual(1);
        const page: string = (JSON.parse(turn.actions[0].payload) as OpenPagePayload).page;
        expect(OPEN_PAGES.includes(page)).assertTrue();
      }
    });
  });

  describe('ToolRegistry', () => {
    it('matchesBackendToolSchemas', 0, () => {
      const names: string[] = new ToolRegistry().names().sort();
      expect(names.join(',')).assertEqual(BACKEND_TOOLS.slice().sort().join(','));
    });

    it('explainConditionCarriesGenotypeCoachTips', 0, async () => {
      const turn: TurnState = new TurnState();
      turn.genotype = 'LQT2';
      const args: Record<string, Object> = { 'topic': 'triggers' };
      const out: string = await new ExplainConditionTool().execute(args, turn);
      const parsed: Record<string, Object> = JSON.parse(out) as Record<string, Object>;
      const tips: string[] = parsed['triggerTips'] as string[];
      expect(tips.length).assertEqual(3);
      expect(tips[0].startsWith('LQT2')).assertTrue();
    });
  });

  describe('LogSymptom', () => {
    it('entryClampsAndAttachesOnlyNearbyHeartRate', 0, () => {
      const at: number = 10000000;
      const samples: VitalsSample[] = [
        { ts: at - 60000, hr: 92, source: 'SIMULATED' },
        { ts: at - 5 * 60000, hr: 110, source: 'SIMULATED' },
        { ts: at - 30 * 60000, hr: 150, source: 'SIMULATED' }
      ];
      const e: SymptomEntry = buildSymptomEntry('DIZZINESS', 9, 'Swimming', '  felt odd ', samples, at);
      expect(e.severity).assertEqual(5);
      expect(e.activity).assertEqual('swimming');
      expect(e.note).assertEqual('felt odd');
      expect(e.hrMin).assertEqual(92);
      expect(e.hrMax).assertEqual(110);
      expect(buildSymptomEntry('OTHER', 0, 'skydiving', '', [], at).activity).assertEqual('other');
      expect(buildSymptomEntry('OTHER', 0, '', '', [], at).hrMin).assertEqual(-1);
    });

    it('parsesSymptomWords', 0, () => {
      expect(parseSymptom('chest pain')).assertEqual('CHEST_PAIN');
      expect(parseSymptom('shortness-of-breath')).assertEqual('SHORTNESS_OF_BREATH');
      expect(parseSymptom('headache') === undefined).assertTrue();
    });

    it('unknownSymptomIsAnErrorAndNothingIsLogged', 0, async () => {
      const before: number = (await LocalStore.get().listEvents()).length;
      const args: Record<string, Object> = { 'symptom': 'headache', 'severity': 2 };
      const out: string = await new LogSymptomTool().execute(args, new TurnState());
      expect(out.includes('error')).assertTrue();
      expect((await LocalStore.get().listEvents()).length).assertEqual(before);
    });

    it('mildSymptomIsLoggedWithoutEmergency', 0, async () => {
      const turn: TurnState = new TurnState();
      const args: Record<string, Object> = { 'symptom': 'DIZZINESS', 'severity': 2, 'activity': 'resting' };
      const out: string = await new LogSymptomTool().execute(args, turn);
      expect(out.includes('LOGGED')).assertTrue();
      expect(turn.emergencyStarted).assertFalse();
      const events: AppEvent[] = await LocalStore.get().listEvents();
      const last: AppEvent = events[events.length - 1];
      expect(last.kind).assertEqual('SYMPTOM');
      expect((JSON.parse(last.detail) as SymptomEntry).symptom).assertEqual('DIZZINESS');
    });

    it('redFlagStartsTheEmergencyFlowDeterministically', 0, async () => {
      const turn: TurnState = new TurnState();
      const args: Record<string, Object> = { 'symptom': 'FAINTING', 'severity': 1 };
      await new LogSymptomTool().execute(args, turn);
      expect(turn.emergencyStarted).assertTrue();
      expect(turn.actions.some((a: UiAction) => a.type === 'START_EMERGENCY')).assertTrue();
    });
  });
}
