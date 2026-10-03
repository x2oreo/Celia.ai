import { describe, it, expect } from '@ohos/hypium';
import { buildFeeling, FEELING_NOTE_MAX, FeelingEntry, isLowMood, parseFeeling } from '../main/ets/diary/Diary';
import { dailyCounts, DiaryDay } from '../main/ets/diary/DailyCounts';
import { diaryLine } from '../main/ets/doctor/DoctorPrep';
import { AppEvent } from '../main/ets/model/AppEvent';
import { dayKey } from '../main/ets/reminders/DoseSchedule';

const DAY: number = 86400000;
const NOW: number = new Date(2026, 9, 3, 18, 0, 0).getTime();   // 3 Oct 2026, 18:00 local

function feeling(id: number, ts: number, mood: string): AppEvent {
  const e: AppEvent = { id: id, ts: ts, kind: 'FEELING', detail: `{"mood":"${mood}","note":""}` };
  return e;
}

function symptom(id: number, ts: number): AppEvent {
  const e: AppEvent = { id: id, ts: ts, kind: 'SYMPTOM',
    detail: '{"symptom":"DIZZINESS","severity":2,"activity":"resting","note":"","hrMin":-1,"hrMax":-1}' };
  return e;
}

export default function diaryTest() {
  describe('Diary', () => {
    it('buildTrimsAndClipsNote', 0, () => {
      const e: FeelingEntry = buildFeeling('LOW', `  tired   ${'z'.repeat(200)}`);
      expect(e.note.length).assertEqual(FEELING_NOTE_MAX);
      expect(e.note.startsWith('tired z')).assertTrue();
    });

    it('parseRejectsBrokenOrUnknown', 0, () => {
      expect(parseFeeling('{"mood":"GOOD","note":"walk"}')?.note).assertEqual('walk');
      expect(parseFeeling('{"mood":"GOOD"}')?.note).assertEqual('');
      expect(parseFeeling('{"mood":"ECSTATIC"}') === undefined).assertTrue();
      expect(parseFeeling('nope') === undefined).assertTrue();
      expect(parseFeeling('null') === undefined).assertTrue();
    });

    it('lowMoods', 0, () => {
      expect(isLowMood('UNWELL')).assertTrue();
      expect(isLowMood('LOW')).assertTrue();
      expect(isLowMood('OKAY')).assertFalse();
    });
  });

  describe('DailyCounts', () => {
    it('oneRowPerDayOldestFirst', 0, () => {
      const rows: DiaryDay[] = dailyCounts([], NOW, 7);
      expect(rows.length).assertEqual(7);
      expect(rows[6].day).assertEqual(dayKey(NOW));
      expect(rows[0].day).assertEqual(dayKey(NOW - 6 * DAY));
      expect(rows[0].feelings + rows[0].symptoms).assertEqual(0);
      expect(dailyCounts([], NOW, 0).length).assertEqual(0);
    });

    it('countsFeelingsLowAndSymptoms', 0, () => {
      const events: AppEvent[] = [
        feeling(1, NOW - 2 * 3600000, 'GOOD'),
        feeling(2, NOW - 3600000, 'UNWELL'),
        symptom(3, NOW - 1000),
        feeling(4, NOW - 2 * DAY, 'LOW'),
        feeling(5, NOW - 2 * DAY, 'BROKEN'),
        symptom(6, NOW - 30 * DAY),            // outside the window
        feeling(7, NOW + 5 * DAY, 'GOOD'),     // future: ignored
        { id: 8, ts: NOW, kind: 'DOSE', detail: '{}' } as AppEvent
      ];
      const rows: DiaryDay[] = dailyCounts(events, NOW, 7);
      const today: DiaryDay = rows[6];
      expect(today.feelings).assertEqual(2);
      expect(today.lowFeelings).assertEqual(1);
      expect(today.symptoms).assertEqual(1);
      expect(rows[4].feelings).assertEqual(1);
      expect(rows[4].lowFeelings).assertEqual(1);
      let total: number = 0;
      rows.forEach((r: DiaryDay) => {
        total += r.feelings + r.symptoms;
      });
      expect(total).assertEqual(4);
    });

    it('briefDiaryLineIsCountsOnly', 0, () => {
      const events: AppEvent[] = [feeling(1, NOW - DAY, 'GOOD'), feeling(2, NOW - DAY, 'GOOD'),
        feeling(3, NOW - DAY, 'LOW'),
        { id: 4, ts: NOW - DAY, kind: 'FEELING', detail: '{"mood":"OKAY","note":"my sister Ewa"}' } as AppEvent];
      const line: string = diaryLine(events, NOW - 90 * DAY);
      expect(line).assertEqual('4 entries: 2 good, 1 okay, 1 low.');
      expect(diaryLine([], NOW - 90 * DAY)).assertEqual('');
    });
  });
}
