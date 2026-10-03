import { describe, it, expect } from '@ohos/hypium';
import {
  agentLine, confirmStateOf, dayGreeting, dayHello, DoseFocus, doseFocus, doseNeedsWord, doseWhen, stagePhase, verdictOf
} from '../main/ets/components/agent/AgentLogic';
import { DoseLog, DoseReminder, dayKey } from '../main/ets/reminders/DoseSchedule';
import { VerdictCardPayload } from '../main/ets/model/AgentTypes';

export default function agentLogicTest() {
  describe('AgentLogic', () => {
    it('confirmCardStaysOpenUntilAnswered', 0, () => {
      expect(confirmStateOf([], [], 'a1')).assertEqual('OPEN');
      expect(confirmStateOf(['a2'], ['a2'], 'a1')).assertEqual('OPEN');
    });

    it('confirmCardKeepsTheAnswer', 0, () => {
      expect(confirmStateOf(['a1', 'a2'], ['a1'], 'a1')).assertEqual('ACCEPTED');
      expect(confirmStateOf(['a1', 'a2'], ['a1'], 'a2')).assertEqual('DECLINED');
    });

    it('verdictComesFromThePayload', 0, () => {
      const p: VerdictCardPayload = JSON.parse('{"query":"zofran","ingredient":"ondansetron","risk":"POSSIBLE_RISK",' +
        '"combinedRisk":"KNOWN_RISK","reason":"r","source":"s","findings":[]}') as VerdictCardPayload;
      expect(verdictOf(p).risk).assertEqual('KNOWN_RISK');
      expect(verdictOf(p).query).assertEqual('Zofran');
      expect(verdictOf(p).ingredient).assertEqual('ondansetron');
    });

    it('todayTitleFollowsTheHour', 0, () => {
      expect(dayHello(9, 'Ola')).assertEqual('Good morning, Ola');
      expect(dayHello(14, 'Ola')).assertEqual('Good afternoon, Ola');
      expect(dayHello(21, '')).assertEqual('Good evening');
      expect(dayHello(1, 'Ola')).assertEqual('Hi, Ola');
    });

    it('doseFocusPrefersDueThenMissedThenUpcoming', 0, () => {
      const now: number = new Date(2026, 9, 4, 14, 5, 0, 0).getTime();
      const morning: DoseReminder = { id: 1, medId: 1, medName: 'Nadolol', hour: 8, minute: 0, reminderId: -1 };
      const noon: DoseReminder = { id: 2, medId: 1, medName: 'Nadolol', hour: 14, minute: 0, reminderId: -1 };
      const night: DoseReminder = { id: 3, medId: 1, medName: 'Nadolol', hour: 20, minute: 0, reminderId: -1 };
      const none: DoseLog[] = [];
      const f: DoseFocus | undefined = doseFocus([night, morning, noon], none, now);
      expect(f?.reminder.id).assertEqual(2);
      expect(f?.status).assertEqual('DUE');
      const took: DoseLog[] = [
        { reminderId: 1, day: dayKey(now), status: 'TAKEN', ts: now },
        { reminderId: 2, day: dayKey(now), status: 'TAKEN', ts: now }
      ];
      const later: DoseFocus | undefined = doseFocus([night, morning, noon], took, now);
      expect(later?.reminder.id).assertEqual(3);
      expect(later?.status).assertEqual('UPCOMING');
      const all: DoseLog[] = took.concat([{ reminderId: 3, day: dayKey(now), status: 'TAKEN', ts: now }]);
      expect(doseFocus([night, morning, noon], all, now)).assertUndefined();
    });

    it('doseWhenSaysTheTimeInWords', 0, () => {
      const now: number = new Date(2026, 9, 4, 13, 50, 0, 0).getTime();
      const noon: DoseReminder = { id: 2, medId: 1, medName: 'Nadolol', hour: 14, minute: 0, reminderId: -1 };
      const f: DoseFocus = doseFocus([noon], [], now) as DoseFocus;
      expect(doseWhen(f, now)).assertEqual('Due at 14:00 · in 10 min');
      expect(doseNeedsWord(f, now)).assertTrue();
      const early: number = new Date(2026, 9, 4, 9, 0, 0, 0).getTime();
      expect(doseNeedsWord(doseFocus([noon], [], early), early)).assertFalse();
      expect(doseNeedsWord(undefined, now)).assertFalse();
    });

    it('agentLinePutsTheDoseFirst', 0, () => {
      const now: number = new Date(2026, 9, 4, 13, 50, 0, 0).getTime();
      const noon: DoseReminder = { id: 2, medId: 1, medName: 'Nadolol', hour: 14, minute: 0, reminderId: -1 };
      const f: DoseFocus | undefined = doseFocus([noon], [], now);
      expect(agentLine('Afternoon, Ola.', f, now, 1, 1)).assertEqual(
        'Your 14:00 nadolol is due soon. Want me to log it with you?');
      expect(agentLine('Afternoon, Ola.', undefined, now, 1, 1).indexOf('may interact') > 0).assertTrue();
      expect(agentLine('Afternoon, Ola.', undefined, now, 0, 1).indexOf('QT list') > 0).assertTrue();
      expect(agentLine('Afternoon, Ola.', undefined, now, 0, 0).indexOf('looks calm') > 0).assertTrue();
    });

    it('orbThinksWhileATypedTurnRuns', 0, () => {
      expect(stagePhase(true, 'OFF')).assertEqual('THINKING');
      expect(stagePhase(true, 'LISTENING')).assertEqual('THINKING');
      expect(stagePhase(true, 'SPEAKING')).assertEqual('SPEAKING');
      expect(stagePhase(false, 'OFF')).assertEqual('OFF');
      expect(stagePhase(false, 'HEARING')).assertEqual('HEARING');
    });

    it('greetingFollowsThePartOfTheDay', 0, () => {
      expect(dayGreeting(1, 'Ola')).assertEqual('Hi, Ola.');
      expect(dayGreeting(4, '')).assertEqual('Hi.');
      expect(dayGreeting(5, 'Ola')).assertEqual('Morning, Ola.');
      expect(dayGreeting(11, '')).assertEqual('Good morning.');
      expect(dayGreeting(12, 'Ola')).assertEqual('Afternoon, Ola.');
      expect(dayGreeting(18, 'Ola')).assertEqual('Evening, Ola.');
      expect(dayGreeting(23, '')).assertEqual('Good evening.');
    });
  });
}
