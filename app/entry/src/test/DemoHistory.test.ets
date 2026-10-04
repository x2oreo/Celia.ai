import { describe, it, expect } from '@ohos/hypium';
import { WatchVitalsDay } from '../main/ets/model/WatchData';
import { Medication } from '../main/ets/model/Medication';
import { dayKey } from '../main/ets/reminders/DoseSchedule';
import { DEMO_DAYS, demoRestingDays, demoTrendDays, demoVitalsDays } from '../main/ets/vitals/DemoHistory';
import { BetaBlockerFinding, checkBetaBlocker, DailyResting } from '../main/ets/vitals/RestingTrend';
import { fillDays, TrendDay } from '../main/ets/vitals/Trends';

const DAY_MS: number = 24 * 60 * 60 * 1000;
// Fixed "now": Sunday 4 Oct 2026, 13:00 local.
const NOW: number = new Date(2026, 9, 4, 13, 0, 0).getTime();
const NADOLOL: Medication = { id: 1, name: 'Corgard', ingredient: 'nadolol', dose: '40 mg', addedAt: 0 };

function byDay(rows: TrendDay[], daysAgo: number): TrendDay | undefined {
  const key: string = dayKey(NOW - daysAgo * DAY_MS);
  return rows.find((r: TrendDay) => r.day === key);
}

export default function demoHistoryTest() {
  describe('DemoHistory', () => {
    it('covers 60 days ending today, newest first, with a few days the watch was not worn', 0, () => {
      const v: WatchVitalsDay[] = demoVitalsDays(NOW);
      expect(DEMO_DAYS).assertEqual(60);
      expect(v[0].day).assertEqual(dayKey(NOW));
      expect(v[v.length - 1].day).assertEqual(dayKey(NOW - 59 * DAY_MS));
      expect(v.length > 50 && v.length < 60).assertTrue();
      for (let i = 1; i < v.length; i++) {
        expect(v[i].day < v[i - 1].day).assertTrue();
      }
    });

    it('is labelled simulated and every value is in a believable range', 0, () => {
      const v: WatchVitalsDay[] = demoVitalsDays(NOW);
      expect(v.every((d: WatchVitalsDay) => d.simulated)).assertTrue();
      expect(v.every((d: WatchVitalsDay) => d.minBpm < d.avgBpm && d.avgBpm < d.maxBpm)).assertTrue();
      expect(v.every((d: WatchVitalsDay) => d.spo2 >= 93 && d.spo2 <= 100)).assertTrue();
      expect(v.every((d: WatchVitalsDay) => d.hrvMs >= 15 && d.breathingRate >= 10 && d.sleepMinutes >= 240))
        .assertTrue();
      expect(demoRestingDays(NOW).every((d: DailyResting) => d.simulated && d.restMinutes >= 60)).assertTrue();
    });

    it('tells the missed-dose story on the last two full days', 0, () => {
      const v: WatchVitalsDay[] = demoVitalsDays(NOW);
      expect(v[1].hrvMs < v[5].hrvMs).assertTrue();
      expect(v[1].avgBpm > v[5].avgBpm).assertTrue();
      const t: TrendDay[] = demoTrendDays(NOW);
      expect(byDay(t, 1)?.doses).assertEqual(0);
      expect(byDay(t, 2)?.doses).assertEqual(0);
      expect(byDay(t, 1)?.symptoms).assertEqual(1);
      expect(byDay(t, 3)?.doses).assertEqual(1);
      expect(byDay(t, 0)?.doses).assertEqual(1);
    });

    it('asks about missed beta-blocker doses whatever weekday today is', 0, () => {
      for (let i = 0; i < 7; i++) {
        const now: number = NOW + i * DAY_MS;
        const f: BetaBlockerFinding | undefined = checkBetaBlocker(demoRestingDays(now), [NADOLOL], [], [], now);
        expect(f !== undefined && f.simulated).assertTrue();
      }
    });

    it('fills a 30-day trend with only the unworn day empty', 0, () => {
      const days: TrendDay[] = fillDays(demoTrendDays(NOW), NOW, 30);
      expect(days.length).assertEqual(30);
      expect(days.filter((d: TrendDay) => d.restingBpm === 0).length).assertEqual(1);
    });
  });
}
