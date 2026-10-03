import { describe, it, expect } from '@ohos/hypium';
import { dayKey } from '../main/ets/reminders/DoseSchedule';
import {
  fillDays, TrendDay, TrendPoint, trendPoints, trendScale, TrendScale, trendsRoute, trendStats, TrendStats
} from '../main/ets/vitals/Trends';

const NOW: number = new Date(2026, 9, 3, 12, 0, 0).getTime();
const DAY_MS: number = 24 * 60 * 60 * 1000;

function day(daysAgo: number, bpm: number, doses: number, symptoms: number): TrendDay {
  const d: TrendDay = { day: dayKey(NOW - daysAgo * DAY_MS), restingBpm: bpm, doses: doses, symptoms: symptoms, alerts: 0 };
  return d;
}

export default function trendsTest() {
  describe('Trends', () => {
    it('fills every calendar day, oldest first, leaving gaps empty', 0, () => {
      const days: TrendDay[] = fillDays([day(0, 60, 1, 0), day(2, 58, 1, 0)], NOW, 4);
      expect(days.length).assertEqual(4);
      expect(days[3].day).assertEqual(dayKey(NOW));
      expect(days[3].restingBpm).assertEqual(60);
      expect(days[2].restingBpm).assertEqual(0);
      expect(days[1].restingBpm).assertEqual(58);
      expect(days[0].restingBpm).assertEqual(0);
    });

    it('compares the last week with the days before it', 0, () => {
      const rows: TrendDay[] = [];
      for (let i = 0; i < 14; i++) {
        rows.push(day(i, i < 7 ? 70 : 58, i < 7 ? 0 : 1, i === 1 ? 1 : 0));
      }
      const s: TrendStats = trendStats(fillDays(rows, NOW, 14));
      expect(s.hasChange).assertTrue();
      expect(s.change).assertEqual(12);
      expect(s.avgResting).assertEqual(64);
      expect(s.doseDays).assertEqual(7);
      expect(s.symptomDays).assertEqual(1);
    });

    it('reports no change without enough days on both sides', 0, () => {
      const s: TrendStats = trendStats(fillDays([day(0, 60, 0, 0), day(1, 61, 0, 0)], NOW, 14));
      expect(s.hasChange).assertFalse();
      expect(s.change).assertEqual(0);
    });

    it('keeps the scale at least 30 bpm tall and around the data', 0, () => {
      const sc: TrendScale = trendScale([day(0, 58, 0, 0), day(1, 60, 0, 0)]);
      expect(sc.max - sc.min >= 30).assertTrue();
      expect(sc.min <= 53).assertTrue();
      expect(sc.max >= 65).assertTrue();
      const none: TrendScale = trendScale([]);
      expect(none.max > none.min).assertTrue();
    });

    it('skips days without a value and keeps points inside the plot', 0, () => {
      const days: TrendDay[] = fillDays([day(0, 70, 0, 0), day(3, 56, 0, 0)], NOW, 4);
      const pts: TrendPoint[] = trendPoints(days, 200, 100);
      expect(pts.length).assertEqual(2);
      expect(pts[0].index).assertEqual(0);
      expect(pts[1].index).assertEqual(3);
      expect(pts[0].y > pts[1].y).assertTrue();   // lower bpm is drawn lower
      for (const p of pts) {
        expect(p.x > 0 && p.x < 200 && p.y >= 0 && p.y <= 100).assertTrue();
      }
    });

    it('reads the app backend when it is the Supabase project', 0, () => {
      expect(trendsRoute(true, true, 'https://p.supabase.co', 'k', 'k')).assertEqual('BACKEND');
    });

    it('reads the deployed project when the AI backend is local and the project key is set', 0, () => {
      expect(trendsRoute(false, true, 'https://p.supabase.co', 'project-key', 'local-dev')).assertEqual('SHARE');
    });

    it('stays on labelled demo data without a backend or without a project key', 0, () => {
      expect(trendsRoute(false, false, 'https://p.supabase.co', 'project-key', '')).assertEqual('DEMO');
      expect(trendsRoute(false, true, 'https://p.supabase.co', 'local-dev', 'local-dev')).assertEqual('DEMO');
      expect(trendsRoute(false, true, 'https://p.supabase.co', '', 'local-dev')).assertEqual('DEMO');
      expect(trendsRoute(false, true, '', 'project-key', 'local-dev')).assertEqual('DEMO');
    });
  });
}
