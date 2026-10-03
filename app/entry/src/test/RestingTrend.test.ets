import { describe, it, expect } from '@ohos/hypium';
import {
  BetaBlockerFinding, checkBetaBlocker, DailyResting, findBetaBlocker, median
} from '../main/ets/vitals/RestingTrend';
import { demoHistory } from '../main/ets/vitals/RestingHistory';
import { Medication } from '../main/ets/model/Medication';
import { DoseLog, DoseReminder, dayKey } from '../main/ets/reminders/DoseSchedule';

const DAY_MS: number = 24 * 3600 * 1000;
// Fixed "now": 3 Oct 2026, 14:00 local.
const NOW: number = new Date(2026, 9, 3, 14, 0, 0).getTime();

function med(id: number, name: string, ingredient: string): Medication {
  const m: Medication = { id: id, name: name, ingredient: ingredient, dose: '40 mg', addedAt: 0 };
  return m;
}

const NADOLOL: Medication = med(1, 'Corgard', 'nadolol');
const PARACETAMOL: Medication = med(2, 'Apap', 'paracetamol');

// bpms[0] = yesterday, bpms[1] = the day before, ...
function history(bpms: number[]): DailyResting[] {
  const out: DailyResting[] = [];
  for (let i = 0; i < bpms.length; i++) {
    const d: DailyResting = { day: dayKey(NOW - (i + 1) * DAY_MS), bpm: bpms[i], restMinutes: 300, simulated: false };
    out.push(d);
  }
  return out;
}

const RAISED: number[] = [71, 70, 58, 57, 59, 58, 56, 58, 60];

function reminder(createdAt: number): DoseReminder {
  const r: DoseReminder = { id: createdAt, medId: NADOLOL.id, medName: 'Corgard', hour: 8, minute: 0, reminderId: -1 };
  return r;
}

function taken(r: DoseReminder, daysAgo: number, status: string): DoseLog {
  const l: DoseLog = { reminderId: r.id, day: dayKey(NOW - daysAgo * DAY_MS), status: status, ts: 0 };
  return l;
}

export default function restingTrendTest() {
  describe('RestingTrend', () => {
    it('findsBetaBlockerByIngredientOrName', 0, () => {
      expect(findBetaBlocker([PARACETAMOL, NADOLOL])?.id).assertEqual(1);
      expect(findBetaBlocker([med(3, 'Propranolol 10mg', '')]) !== undefined).assertTrue();
      expect(findBetaBlocker([PARACETAMOL]) === undefined).assertTrue();
    });

    it('medianIsRobust', 0, () => {
      expect(median([58, 57, 90, 58, 59])).assertEqual(58);
      expect(median([56, 60])).assertEqual(58);
    });

    it('asksWhenTwoDaysRaised', 0, () => {
      const f: BetaBlockerFinding | undefined = checkBetaBlocker(history(RAISED), [NADOLOL], [], [], NOW);
      expect(f !== undefined).assertTrue();
      expect(f?.baselineBpm).assertEqual(58);
      expect(f?.evidence).assertEqual('NOT_TRACKED');
      expect(f?.message.includes('Did you miss any Corgard doses?')).assertTrue();
      expect(f?.message.includes('Don\'t double up')).assertTrue();
    });

    it('silentWithoutBetaBlocker', 0, () => {
      expect(checkBetaBlocker(history(RAISED), [PARACETAMOL], [], [], NOW) === undefined).assertTrue();
    });

    it('silentWhenOnlyOneDayRaised', 0, () => {
      expect(checkBetaBlocker(history([71, 59, 58, 57, 59, 58, 56]), [NADOLOL], [], [], NOW) === undefined)
        .assertTrue();
    });

    it('silentWhenRiseBelowThreshold', 0, () => {
      expect(checkBetaBlocker(history([66, 67, 58, 57, 59, 58, 56]), [NADOLOL], [], [], NOW) === undefined)
        .assertTrue();
    });

    it('silentDuringColdStart', 0, () => {
      // Only 4 baseline days.
      expect(checkBetaBlocker(history([71, 70, 58, 57, 59, 58]), [NADOLOL], [], [], NOW) === undefined).assertTrue();
    });

    it('ignoresTodayAndStaleData', 0, () => {
      const h: DailyResting[] = history(RAISED);
      const today: DailyResting = { day: dayKey(NOW), bpm: 90, restMinutes: 300, simulated: false };
      expect(checkBetaBlocker(h.concat([today]), [NADOLOL], [], [], NOW) !== undefined).assertTrue();
      // Same pattern a week ago (watch not worn since) must not trigger now.
      expect(checkBetaBlocker(h, [NADOLOL], [], [], NOW + 7 * DAY_MS) === undefined).assertTrue();
    });

    it('ignoresDaysWithTooLittleRestData', 0, () => {
      const h: DailyResting[] = history(RAISED);
      h[0].restMinutes = 20;
      expect(checkBetaBlocker(h, [NADOLOL], [], [], NOW) === undefined).assertTrue();
    });

    it('doseLogShowsMissed', 0, () => {
      const r: DoseReminder = reminder(NOW - 30 * DAY_MS);
      const logs: DoseLog[] = [taken(r, 1, 'SKIPPED'), taken(r, 2, 'TAKEN')];
      const f: BetaBlockerFinding | undefined = checkBetaBlocker(history(RAISED), [NADOLOL], [r], logs, NOW);
      expect(f?.evidence).assertEqual('MISSED_OR_SKIPPED');
      expect(f?.message.includes('wasn\'t marked as taken')).assertTrue();
    });

    it('allTakenPointsElsewhere', 0, () => {
      const r: DoseReminder = reminder(NOW - 30 * DAY_MS);
      const logs: DoseLog[] = [taken(r, 1, 'TAKEN'), taken(r, 2, 'TAKEN')];
      const f: BetaBlockerFinding | undefined = checkBetaBlocker(history(RAISED), [NADOLOL], [r], logs, NOW);
      expect(f?.evidence).assertEqual('ALL_TAKEN');
      expect(f?.message.includes('fever')).assertTrue();
      expect(f?.message.includes('Did you miss')).assertFalse();
    });

    it('reminderCreatedTodayIsNotEvidence', 0, () => {
      const r: DoseReminder = reminder(NOW - 3600 * 1000);
      const f: BetaBlockerFinding | undefined = checkBetaBlocker(history(RAISED), [NADOLOL], [r], [], NOW);
      expect(f?.evidence).assertEqual('NOT_TRACKED');
    });

    it('demoHistoryTriggersAndIsLabelled', 0, () => {
      const f: BetaBlockerFinding | undefined = checkBetaBlocker(demoHistory(NOW), [NADOLOL], [], [], NOW);
      expect(f !== undefined).assertTrue();
      expect(f?.simulated).assertTrue();
    });
  });
}
