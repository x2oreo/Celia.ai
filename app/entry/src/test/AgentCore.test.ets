// AgentCore end-to-end without a backend (List.test forces Config offline): the deterministic paths must work.

import { describe, it, expect } from '@ohos/hypium';
import { AgentCore, alertText } from '../main/ets/agent/AgentCore';
import { VitalsAlert } from '../main/ets/model/Vitals';
import { AgentReply, UiAction, VerdictCardPayload } from '../main/ets/model/AgentTypes';
import { LocalStore } from '../main/ets/data/LocalStore';
import { Medication } from '../main/ets/model/Medication';
import { AgentPrompt } from '../main/ets/agent/AgentPrompt';
import { ChatMessage, LogDosePayload, QuickRepliesPayload } from '../main/ets/model/AgentTypes';
import { keepOnRestore } from '../main/ets/model/Chat';
import { ReminderService } from '../main/ets/reminders/ReminderService';
import { DoseLog, DoseReminder, dayKey } from '../main/ets/reminders/DoseSchedule';
import { doseToLog } from '../main/ets/agent/tools/ActionTools';
import { verdictQuickReplies } from '../main/ets/agent/VerdictText';

// One reminder scheduled for the current minute (so it is DUE, and never crosses midnight), replacing any others.
async function dueReminder(id: number, med: string): Promise<DoseReminder> {
  const d: Date = new Date();
  const r: DoseReminder = { id: id, medId: 1, medName: med, hour: d.getHours(), minute: d.getMinutes(), reminderId: -1 };
  await LocalStore.get().setSetting('reminders', JSON.stringify([r]));
  await LocalStore.get().setSetting('doseLog', '[]');
  return r;
}

async function takenToday(id: number): Promise<boolean> {
  const logs: DoseLog[] = await ReminderService.doseLog();
  return logs.some((l: DoseLog) => l.reminderId === id && l.day === dayKey(Date.now()) && l.status === 'TAKEN');
}

function reminder(id: number, med: string, hour: number): DoseReminder {
  const r: DoseReminder = { id: id, medId: id, medName: med, hour: hour, minute: 0, reminderId: -1 };
  return r;
}

function card(ingredient: string, risk: string, combined: string): VerdictCardPayload {
  const c: VerdictCardPayload = {
    query: ingredient, ingredient: ingredient, risk: risk, combinedRisk: combined, reason: '', source: 'test',
    findings: []
  };
  return c;
}

function find(reply: AgentReply, type: string): UiAction | undefined {
  return reply.actions.find((a: UiAction) => a.type === type);
}

export default function agentCoreTest() {
  describe('AgentCoreOffline', () => {
    it('drugQuestionGetsDeterministicVerdictCard', 0, async () => {
      const r: AgentReply = await AgentCore.get().send('Can I take clarithromycin?');
      expect(r.fallback).assertTrue();
      const a: UiAction | undefined = find(r, 'SHOW_VERDICT');
      expect(a !== undefined).assertTrue();
      const v: VerdictCardPayload = JSON.parse((a as UiAction).payload) as VerdictCardPayload;
      expect(v.risk).assertEqual('KNOWN_RISK');
      expect(r.text.includes('known-risk list')).assertTrue();
      expect(r.text.toLowerCase().includes(' safe')).assertFalse();
    });

    it('unknownDrugIsNeverReportedSafe', 0, async () => {
      const r: AgentReply = await AgentCore.get().send('Can I take zorblax?');
      const v: VerdictCardPayload =
        JSON.parse((find(r, 'SHOW_VERDICT') as UiAction).payload) as VerdictCardPayload;
      expect(v.risk).assertEqual('UNKNOWN_DRUG');
      expect(r.text.includes('pharmacist')).assertTrue();
    });

    it('emergencyBypassesModel', 0, async () => {
      const r: AgentReply = await AgentCore.get().send('I just passed out');
      expect(find(r, 'START_EMERGENCY') !== undefined).assertTrue();
    });

    it('emptyInputIsHandled', 0, async () => {
      const r: AgentReply = await AgentCore.get().send('   ');
      expect(r.actions.length).assertEqual(0);
    });

    it('unknownConfirmIdWritesNothing', 0, async () => {
      const before: number = (await LocalStore.get().listMeds()).length;
      const expired: AgentReply = await AgentCore.get().resolveAction('missing-id', true);
      expect(expired.text.includes('expired')).assertTrue();
      const after: Medication[] = await LocalStore.get().listMeds();
      expect(after.length).assertEqual(before);
    });
  });

  describe('LogDose', () => {
    it('picksDueThenMissedForTheNamedMedicineNeverUpcoming', 0, () => {
      const now: number = new Date(2026, 9, 3, 12, 30, 0, 0).getTime();
      const rs: DoseReminder[] = [reminder(1, 'Nadolol', 8), reminder(2, 'Magnesium', 12), reminder(3, 'Nadolol', 20)];
      expect((doseToLog(rs, [], now, '') as DoseReminder).id).assertEqual(2);          // due now wins
      expect((doseToLog(rs, [], now, 'my meds') as DoseReminder).id).assertEqual(2);   // not a medicine name
      expect((doseToLog(rs, [], now, 'nadolol') as DoseReminder).id).assertEqual(1);   // missed 08:00, not 20:00
      expect((doseToLog(rs, [], now, 'Nadolol 40 mg') as DoseReminder).id).assertEqual(1);
      expect(doseToLog(rs, [], now, 'ibuprofen') === undefined).assertTrue();          // never another medicine
      const taken: DoseLog[] = [{ reminderId: 1, day: dayKey(now), status: 'TAKEN', ts: now }];
      expect(doseToLog(rs, taken, now, 'nadolol') === undefined).assertTrue();         // 20:00 is upcoming
    });

    it('proposesACardAndWritesOnlyOnConfirm', 0, async () => {
      const r: DoseReminder = await dueReminder(1001, 'Nadolol');
      const reply: AgentReply = await AgentCore.get().send('I took my nadolol');
      const a: UiAction | undefined = find(reply, 'LOG_DOSE');
      expect(a !== undefined).assertTrue();
      const p: LogDosePayload = JSON.parse((a as UiAction).payload) as LogDosePayload;
      expect(p.medicine).assertEqual('Nadolol');
      expect(reply.text.includes('Nothing is logged')).assertTrue();
      expect(await takenToday(r.id)).assertFalse();
      const done: AgentReply = await AgentCore.get().resolveAction(p.actionId, true);
      expect(done.text.includes('as taken')).assertTrue();
      expect(await takenToday(r.id)).assertTrue();
      // A second tap on the same card finds nothing to resolve.
      const again: AgentReply = await AgentCore.get().resolveAction(p.actionId, true);
      expect(again.text.includes('expired')).assertTrue();
      // Asking again the same day proposes nothing: the dose is already marked.
      const second: AgentReply = await AgentCore.get().send('I took my nadolol');
      expect(find(second, 'LOG_DOSE') === undefined).assertTrue();
    });

    it('cancelWritesNothing', 0, async () => {
      const r: DoseReminder = await dueReminder(1002, 'Nadolol');
      const reply: AgentReply = await AgentCore.get().send('mark my nadolol as taken');
      const p: LogDosePayload = JSON.parse((find(reply, 'LOG_DOSE') as UiAction).payload) as LogDosePayload;
      const done: AgentReply = await AgentCore.get().resolveAction(p.actionId, false);
      expect(done.text.includes("didn't change anything")).assertTrue();
      expect(await takenToday(r.id)).assertFalse();
    });

    it('doseMarkedElsewhereIsNotWrittenTwice', 0, async () => {
      const r: DoseReminder = await dueReminder(1003, 'Nadolol');
      const reply: AgentReply = await AgentCore.get().send('I have taken my medicine');
      const p: LogDosePayload = JSON.parse((find(reply, 'LOG_DOSE') as UiAction).payload) as LogDosePayload;
      await ReminderService.mark(r, 'SKIPPED');   // the user marked it on the reminders screen meanwhile
      const done: AgentReply = await AgentCore.get().resolveAction(p.actionId, true);
      expect(done.text.includes('already marked')).assertTrue();
      expect(await takenToday(r.id)).assertFalse();
    });

    it('restoredChatNeverReplaysTheWrite', 0, async () => {
      const r: DoseReminder = await dueReminder(1004, 'Nadolol');
      const reply: AgentReply = await AgentCore.get().send('I took my nadolol');
      const a: UiAction = find(reply, 'LOG_DOSE') as UiAction;
      const p: LogDosePayload = JSON.parse(a.payload) as LogDosePayload;
      expect(keepOnRestore(a)).assertFalse();
      await AgentCore.get().whenSaved();
      // Reopen the chat from the store, as a cold start or the Chats page does.
      expect(await AgentCore.get().openChat(AgentCore.get().currentChatId())).assertTrue();
      const cards: number = AgentCore.get().getHistory().filter((m: ChatMessage) =>
        (m.actions ?? []).some((x: UiAction) => x.type === 'LOG_DOSE')).length;
      expect(cards).assertEqual(0);
      const done: AgentReply = await AgentCore.get().resolveAction(p.actionId, true);
      expect(done.text.includes('expired')).assertTrue();
      expect(await takenToday(r.id)).assertFalse();
    });

    it('noReminderMeansNoCard', 0, async () => {
      await LocalStore.get().setSetting('reminders', '[]');
      const reply: AgentReply = await AgentCore.get().send('I took my nadolol');
      expect(reply.actions.length).assertEqual(0);
      expect(reply.text.includes('No reminders are set')).assertTrue();
    });
  });

  describe('VerdictQuickReplies', () => {
    it('comeFromTheRiskLevelOnly', 0, () => {
      expect(verdictQuickReplies(card('clarithromycin', 'KNOWN_RISK', 'KNOWN_RISK'))[0])
        .assertEqual('What can I take instead of clarithromycin?');
      const listed: string[] = verdictQuickReplies(card('ibuprofen', 'NOT_LISTED', 'NOT_LISTED'));
      expect(listed[0]).assertEqual('Add ibuprofen to my medicines');
      // Not listed alone but risky with the user's medicines: never offer to add it.
      const combo: string[] = verdictQuickReplies(card('ibuprofen', 'NOT_LISTED', 'POSSIBLE_RISK'));
      expect(combo.some((o: string) => o.startsWith('Add '))).assertFalse();
      const unknown: string[] = verdictQuickReplies(card('', 'UNKNOWN_DRUG', 'UNKNOWN_DRUG'));
      expect(unknown.some((o: string) => o.startsWith('Add ') || o.includes('instead of'))).assertFalse();
      for (const o of listed.concat(combo).concat(unknown)) {
        expect(o.toLowerCase().includes('safe')).assertFalse();
      }
    });

    it('chipsNeverTripTheEmergencyGateOrChatCommands', 0, async () => {
      const all: string[] = verdictQuickReplies(card('sotalol', 'KNOWN_RISK', 'KNOWN_RISK'))
        .concat(verdictQuickReplies(card('ibuprofen', 'NOT_LISTED', 'NOT_LISTED')))
        .concat(verdictQuickReplies(card('', 'UNKNOWN_DRUG', 'UNKNOWN_DRUG')));
      for (const o of all) {
        const r: AgentReply = await AgentCore.get().send(o);
        expect(find(r, 'START_EMERGENCY') === undefined).assertTrue();
      }
      const q: QuickRepliesPayload = { options: all };
      expect(q.options.length > 0).assertTrue();
    });
  });

  describe('AgentPrompt', () => {
    it('queuesUntilTheChatSubscribes', 0, () => {
      AgentPrompt.drain();
      AgentPrompt.ask('  Can I take Klacid?  ');
      AgentPrompt.ask('   ');
      const queued: string[] = AgentPrompt.drain();
      expect(queued.length).assertEqual(1);
      expect(queued[0]).assertEqual('Can I take Klacid?');
      expect(AgentPrompt.drain().length).assertEqual(0);
    });

    it('deliversLiveAndRequestsTheChat', 0, () => {
      const heard: string[] = [];
      let opened: number = 0;
      const offAsk: () => void = AgentPrompt.onAsk((q: string) => {
        heard.push(q);
      });
      const offOpen: () => void = AgentPrompt.onOpenChat(() => {
        opened++;
      });
      AgentPrompt.ask('Is ondansetron OK?');
      offAsk();
      offOpen();
      expect(heard.length).assertEqual(1);
      expect(opened).assertEqual(1);
      expect(AgentPrompt.drain().length).assertEqual(0);
    });
  });

  describe('VitalsCheckInText', () => {
    it('doesNotRepeatTheRateOrTheQuestion', 0, () => {
      const a: VitalsAlert = { ts: 0, kind: 'TACHY_AT_REST', hr: 121, severity: 'WARN',
        message: 'Heart rate 121 while resting. Sit or lie down. Are you OK?' };
      expect(alertText(a)).assertEqual('Heart rate 121 while resting. Sit or lie down. Are you OK?');
      const b: VitalsAlert = { ts: 0, kind: 'IRREGULAR_RHYTHM', hr: 85, severity: 'WARN',
        message: 'The watch detected an irregular rhythm.' };
      expect(alertText(b)).assertEqual('Your heart rate is 85 bpm. The watch detected an irregular rhythm.');
    });
  });
}
