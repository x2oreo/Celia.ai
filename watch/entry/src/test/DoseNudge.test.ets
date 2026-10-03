import { describe, it, expect } from '@ohos/hypium';
import { DoseState, dayKey, emptyDoseState, forToday, shouldNudge } from '../main/ets/vitals/DoseNudge';

function at(h: number, m: number): number {
  const d = new Date(2026, 9, 3, h, m, 0, 0);
  return d.getTime();
}

export default function doseNudgeTest() {
  describe('DoseNudge', () => {
    it('not before reminder + 2 h', 0, () => {
      expect(shouldNudge(emptyDoseState(), at(9, 59), '08:00')).assertFalse();
      expect(shouldNudge(emptyDoseState(), at(10, 0), '08:00')).assertTrue();
    });

    it('not when a dose was logged today; again the next day', 0, () => {
      const s: DoseState = emptyDoseState();
      s.lastDoseDay = dayKey(at(7, 30));
      expect(shouldNudge(s, at(11, 0), '08:00')).assertFalse();
      expect(shouldNudge(s, at(11, 0) + 24 * 3600 * 1000, '08:00')).assertTrue();
    });

    it('snooze 1 h, at most 3 shows a day', 0, () => {
      let s: DoseState = forToday(emptyDoseState(), at(10, 0));
      s.timesShown = 1;
      s.snoozeUntilMs = at(11, 0);
      expect(shouldNudge(s, at(10, 30), '08:00')).assertFalse();
      expect(shouldNudge(s, at(11, 0), '08:00')).assertTrue();
      s.timesShown = 3;
      expect(shouldNudge(s, at(13, 0), '08:00')).assertFalse();
      s = forToday(s, at(13, 0) + 24 * 3600 * 1000);
      expect(s.timesShown).assertEqual(0);
    });

    it('empty or invalid reminder time turns the nudge off', 0, () => {
      expect(shouldNudge(emptyDoseState(), at(20, 0), '')).assertFalse();
      expect(shouldNudge(emptyDoseState(), at(20, 0), '25:00')).assertFalse();
    });
  });
}
