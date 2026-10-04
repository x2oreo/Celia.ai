import { describe, it, expect } from '@ohos/hypium';
import { DoseCard, doseCard } from '../main/ets/widget/WidgetDose';
import { applyDose, WidgetSnapshot } from '../main/ets/widget/WidgetSnapshot';
import { buildSnapshot, recentChecks, riskCode, WidgetInputs } from '../main/ets/widget/WidgetModel';
import { DoseLog, DoseReminder, dayKey } from '../main/ets/reminders/DoseSchedule';
import { ScanRecord } from '../main/ets/model/ScanRecord';
import { RiskLevel } from '../main/ets/model/DrugVerdict';
import { AppEvent } from '../main/ets/model/AppEvent';
import { Profile } from '../main/ets/model/Profile';
import { Medication } from '../main/ets/model/Medication';
import { TrendDay } from '../main/ets/vitals/Trends';

const DAY: number = 86400000;
const NOW: number = new Date(2026, 9, 4, 14, 20, 0).getTime();   // 4 Oct 2026, 14:20 local
const CREATED: number = new Date(2026, 8, 1).getTime();          // reminders made long before today

function rem(id: number, name: string, hour: number, minute: number): DoseReminder {
  const r: DoseReminder = { id: CREATED + id, medId: id, medName: name, hour: hour, minute: minute, reminderId: -1 };
  return r;
}

function taken(r: DoseReminder): DoseLog {
  const l: DoseLog = { reminderId: r.id, day: dayKey(NOW), status: 'TAKEN', ts: NOW };
  return l;
}

function scan(id: number, ts: number, query: string, risk: RiskLevel): ScanRecord {
  const s: ScanRecord = { id: id, ts: ts, via: 'TEXT', query: query, ingredient: '', risk: risk, combo: 'NONE' };
  return s;
}

function day(i: number, bpm: number): TrendDay {
  const d: TrendDay = { day: dayKey(NOW - (13 - i) * DAY), restingBpm: bpm, doses: 0, symptoms: 0, alerts: 0 };
  return d;
}

const MORNING: DoseReminder = rem(1, 'Nadolol', 8, 0);
const AFTERNOON: DoseReminder = rem(2, 'Potassium', 14, 0);
const EVENING: DoseReminder = rem(3, 'Nadolol', 20, 0);

export default function widgetsTest() {
  describe('Widgets', () => {
    it('doseCardWithoutRemindersIsNone', 0, () => {
      const c: DoseCard = doseCard([], [], NOW);
      expect(c.state).assertEqual('NONE');
      expect(c.total).assertEqual(0);
      expect(c.dots).assertEqual('');
    });

    it('doseCardShowsTheDueDoseFirst', 0, () => {
      const c: DoseCard = doseCard([EVENING, AFTERNOON, MORNING], [taken(MORNING)], NOW);
      expect(c.state).assertEqual('DUE');
      expect(c.name).assertEqual('Potassium');
      expect(c.when).assertEqual('Due at 14:00');
      expect(c.taken).assertEqual(1);
      expect(c.total).assertEqual(3);
      expect(c.dots).assertEqual('100');   // time order, not list order
    });

    it('doseCardSaysMissedInWords', 0, () => {
      const c: DoseCard = doseCard([MORNING, EVENING], [], NOW);
      expect(c.state).assertEqual('MISSED');
      expect(c.when).assertEqual('Missed at 08:00');
    });

    it('doseCardMovesOnToTheNextDose', 0, () => {
      const c: DoseCard = doseCard([MORNING, AFTERNOON, EVENING], [taken(MORNING), taken(AFTERNOON)], NOW);
      expect(c.state).assertEqual('UPCOMING');
      expect(c.when).assertEqual('Next at 20:00');
      expect(c.dots).assertEqual('110');
    });

    it('doseCardIsDoneAfterTheLastDose', 0, () => {
      const c: DoseCard = doseCard([MORNING], [taken(MORNING)], NOW);
      expect(c.state).assertEqual('DONE');
      expect(c.dots).assertEqual('1');
    });

    it('applyDoseRewritesTheAgentLineByTheClock', 0, () => {
      const s: WidgetSnapshot = new WidgetSnapshot();
      s.agentRest = 'Hi, Ola. Everything looks calm.';
      applyDose(s, [AFTERNOON], [], NOW);
      expect(s.agentLine).assertEqual('Your 14:00 potassium is due now. Want me to log it with you?');
      // Two hours later the same schedule reads as missed; once taken the calm line comes back.
      applyDose(s, [AFTERNOON], [], NOW + 2 * 3600000);
      expect(s.agentLine).assertEqual("Your 14:00 potassium hasn't been logged. Want to log it with me now?");
      applyDose(s, [AFTERNOON], [taken(AFTERNOON)], NOW);
      expect(s.agentLine).assertEqual('Hi, Ola. Everything looks calm.');
    });

    it('riskCodesCoverEveryLevel', 0, () => {
      expect(riskCode('KNOWN_RISK')).assertEqual('KNOWN');
      expect(riskCode('POSSIBLE_RISK')).assertEqual('POSSIBLE');
      expect(riskCode('CONDITIONAL_RISK')).assertEqual('CONDITIONAL');
      expect(riskCode('NOT_LISTED')).assertEqual('OK');
      expect(riskCode('UNKNOWN_DRUG')).assertEqual('UNKNOWN');
    });

    it('recentChecksAreNewestFirstAndDistinct', 0, () => {
      const r: ScanRecord[] = recentChecks([
        scan(1, NOW - 5000, 'ibuprofen', 'NOT_LISTED'),
        scan(2, NOW - 4000, 'Klacid', 'KNOWN_RISK'),
        scan(3, NOW - 3000, 'IBUPROFEN ', 'NOT_LISTED'),
        scan(4, NOW - 2000, 'loratadine', 'NOT_LISTED'),
        scan(5, NOW - 1000, 'ondansetron', 'KNOWN_RISK')
      ]);
      expect(r.length).assertEqual(3);
      expect(r[0].query).assertEqual('ondansetron');
      expect(r[1].query).assertEqual('loratadine');
      expect(r[2].query).assertEqual('IBUPROFEN ');
    });

    it('emptyInputsGiveSafeDefaults', 0, () => {
      const s: WidgetSnapshot = buildSnapshot(new WidgetInputs(), NOW);
      expect(s.condition).assertEqual('Long QT syndrome');
      expect(s.number).assertEqual('112');
      expect(s.doseState).assertEqual('NONE');
      expect(s.hrAvg).assertEqual(0);
      expect(s.hrSource).assertEqual('');
      expect(s.chk0Name).assertEqual('');
      expect(s.feelLast).assertEqual('');
      expect(s.wide).assertFalse();
    });

    it('snapshotCarriesHeartChecksAndFeeling', 0, () => {
      const i: WidgetInputs = new WidgetInputs();
      const p: Profile = { condition: 'LQTS', genotype: 'LQT2', hasIcd: false, notes: '', contacts: [] };
      i.profile = p;
      const m: Medication = { id: 1, name: 'Corgard', ingredient: 'nadolol', dose: '40 mg', addedAt: 0 };
      i.meds = [m];
      i.ambulance = '999';
      const days: TrendDay[] = [];
      for (let d = 0; d < 14; d++) {
        days.push(day(d, d === 10 ? 0 : (d < 7 ? 60 : 58)));   // day 10 has no reading
      }
      i.trend = days;
      i.trendSimulated = false;
      i.scans = [scan(1, NOW - 1000, 'klacid', 'KNOWN_RISK')];
      const e: AppEvent = { id: 1, ts: new Date(2026, 9, 3, 20, 14).getTime(), kind: 'FEELING',
        detail: '{"mood":"GOOD","note":""}' };
      i.events = [e];
      const s: WidgetSnapshot = buildSnapshot(i, NOW);
      expect(s.condition).assertEqual('Long QT syndrome, type 2');
      expect(s.facts).assertEqual('No ICD · Corgard (nadolol) 40 mg');
      expect(s.number).assertEqual('999');
      expect(s.hrAvg).assertEqual(58);
      expect(s.hrChange).assertEqual('2 lower than last week');
      expect(s.hrSource).assertEqual('WATCH');
      expect(s.hd3).assertEqual(-1);   // the gap stays a gap
      expect(s.hd6 >= 0 && s.hd6 <= 100).assertTrue();
      expect(s.hbHi > s.hbLo).assertTrue();
      expect(s.chk0Name).assertEqual('Klacid');
      expect(s.chk0Risk).assertEqual('KNOWN');
      expect(s.feelLast).assertEqual('Last: Good · 3 Oct 20:14');
    });
  });
}
