import { describe, it, expect } from '@ohos/hypium';
import {
  bandText, baselineOf, buildSeries, ChartPoint, chartPoints, dayText, formatValue, levelFor, lineRuns, liveHrBand,
  MetricBand, metricBand, MetricDay, metricDay, MetricScale, metricScale, MetricSeries, MetricStatus, metricStatus,
  nearestIndex, NO_VALUE, seriesFor, smoothRun
} from '../main/ets/vitals/Metrics';
import { demoVitals } from '../main/ets/vitals/MetricHistory';
import { parseVitalsDaily } from '../main/ets/data/WatchDataClient';
import { WatchVitalsDay } from '../main/ets/model/WatchData';
import { TrendDay } from '../main/ets/vitals/Trends';

function series(values: number[]): MetricDay[] {
  return values.map((v: number, i: number) => metricDay(`2026-09-${i + 10}`, v));
}

// Ten steady days at 58, then the given last two.
function resting(last: number, beforeLast: number): MetricDay[] {
  return series([58, 57, 59, 58, 56, 58, 60, 57, 58, 59, beforeLast, last]);
}

export default function metricsTest() {
  describe('Metrics', () => {
    it('baseline is the median of the days before the last two, and needs five of them', 0, () => {
      expect(baselineOf(resting(71, 69))).assertEqual(58);
      expect(baselineOf(series([58, 57, 59, 58, 70, 71]))).assertEqual(NO_VALUE);
    });

    it('resting heart rate: near the baseline is good, 10 above is worth a look', 0, () => {
      expect(metricStatus('RESTING_HR', resting(60, 58)).level).assertEqual('GOOD');
      expect(metricStatus('RESTING_HR', resting(65, 58)).level).assertEqual('OKAY');
      const high: MetricStatus = metricStatus('RESTING_HR', resting(71, 69));
      expect(high.level).assertEqual('ATTENTION');
      expect(high.reason).assertEqual('HIGH');
      expect(high.band.personal).assertTrue();
    });

    it('without enough days the fixed reference range is used', 0, () => {
      const b: MetricBand = metricBand('RESTING_HR', series([62, 63]));
      expect(b.personal).assertFalse();
      expect(b.lo).assertEqual(50);
      expect(levelFor(62, b)).assertEqual('GOOD');
    });

    it('oxygen and breathing use fixed ranges', 0, () => {
      expect(metricStatus('SPO2', series([97])).level).assertEqual('GOOD');
      expect(metricStatus('SPO2', series([93])).level).assertEqual('OKAY');
      expect(metricStatus('SPO2', series([90])).level).assertEqual('ATTENTION');
      expect(metricStatus('BREATHING', series([14])).level).assertEqual('GOOD');
      expect(metricStatus('BREATHING', series([27])).reason).assertEqual('HIGH');
    });

    it('only a drop in HRV is flagged, and steps are never worse than okay', 0, () => {
      const base: number[] = [48, 47, 49, 48, 50, 48, 47, 49];
      expect(metricStatus('HRV', series(base.concat([48, 70]))).level).assertEqual('GOOD');
      expect(metricStatus('HRV', series(base.concat([48, 28]))).level).assertEqual('ATTENTION');
      const steps: number[] = [6000, 6200, 5900, 6100, 6000, 6300, 6000];
      expect(metricStatus('STEPS', series(steps.concat([6000, 400]))).level).assertEqual('OKAY');
    });

    it('no reading is never a level', 0, () => {
      const s: MetricStatus = metricStatus('HRV', series([NO_VALUE, NO_VALUE]));
      expect(s.level).assertEqual('NONE');
      expect(s.direction).assertEqual('NONE');
    });

    it('change compares the last 7 days with the days before', 0, () => {
      const up: MetricStatus = metricStatus('RESTING_HR', series([58, 58, 58, 58, 64, 64, 64, 64, 64, 64, 64]));
      expect(up.direction).assertEqual('UP');
      expect(up.delta).assertEqual(6);
      expect(metricStatus('RESTING_HR', series([58, 58, 58, 58, 59, 58, 59, 58, 59, 58, 59])).direction)
        .assertEqual('STEADY');
      expect(metricStatus('RESTING_HR', series([58, 58, 60, 61])).direction).assertEqual('NONE');
    });

    it('a live heart rate is judged by what the wearer is doing', 0, () => {
      expect(levelFor(72, liveHrBand(false, false))).assertEqual('GOOD');
      expect(levelFor(130, liveHrBand(false, false))).assertEqual('ATTENTION');
      expect(levelFor(130, liveHrBand(false, true))).assertEqual('GOOD');
      expect(levelFor(36, liveHrBand(true, false))).assertEqual('ATTENTION');
      expect(metricStatus('HEART_RATE', [], 165, liveHrBand(false, false)).reason).assertEqual('HIGH');
    });

    it('the scale holds the readings and the usual range on round ticks', 0, () => {
      const days: MetricDay[] = resting(71, 69);
      const scale: MetricScale = metricScale('RESTING_HR', days, metricBand('RESTING_HR', days));
      expect(scale.min <= 53).assertTrue();
      expect(scale.max >= 71).assertTrue();
      expect(scale.ticks.length >= 3 && scale.ticks.length <= 6).assertTrue();
      expect(scale.ticks[0]).assertEqual(scale.min);
      const bars: MetricScale = metricScale('SLEEP', series([7.4, 5.6]), metricBand('SLEEP', []));
      expect(bars.min).assertEqual(0);
      const oxygen: MetricScale = metricScale('SPO2', series([97, 98]), metricBand('SPO2', []));
      expect(oxygen.max).assertEqual(100);
    });

    it('the line breaks at a day without a reading', 0, () => {
      const days: MetricDay[] = series([60, 61, NO_VALUE, 62, 63, 64]);
      const scale: MetricScale = metricScale('RESTING_HR', days, metricBand('RESTING_HR', days));
      const pts: ChartPoint[] = chartPoints(days, scale, 120, 100);
      expect(pts.length).assertEqual(5);
      const runs: ChartPoint[][] = lineRuns(pts);
      expect(runs.length).assertEqual(2);
      expect(runs[0].length).assertEqual(2);
      expect(runs[1].length).assertEqual(3);
    });

    it('the smooth line passes through the readings and never overshoots them', 0, () => {
      const days: MetricDay[] = series([58, 58, 58, 71, 58, 58]);
      const scale: MetricScale = metricScale('RESTING_HR', days, metricBand('RESTING_HR', days));
      const pts: ChartPoint[] = chartPoints(days, scale, 120, 100);
      const line: Array<[number, number]> = smoothRun(pts, 8);
      expect(line.length).assertEqual(1 + 5 * 8);
      expect(Math.abs(line[8][1] - pts[1].y) < 0.001).assertTrue();
      let top: number = 1000;
      let bottom: number = 0;
      for (const p of line) {
        top = Math.min(top, p[1]);
        bottom = Math.max(bottom, p[1]);
      }
      expect(top >= pts[3].y - 0.001).assertTrue();      // the peak of the curve is the 71 reading
      expect(bottom <= pts[0].y + 0.001).assertTrue();   // and it never dips under the 58s
    });

    it('a touch picks the nearest day that has a reading', 0, () => {
      const days: MetricDay[] = series([60, NO_VALUE, NO_VALUE, 62]);
      expect(nearestIndex(days, 5, 100)).assertEqual(0);
      expect(nearestIndex(days, 60, 100)).assertEqual(3);
      expect(nearestIndex(series([NO_VALUE]), 5, 100)).assertEqual(-1);
    });

    it('values and ranges read like a person wrote them', 0, () => {
      expect(formatValue('STEPS', 6240)).assertEqual('6,240');
      expect(formatValue('SLEEP', 7.44)).assertEqual('7.4');
      expect(formatValue('HRV', NO_VALUE)).assertEqual('–');
      expect(bandText('RESTING_HR', metricBand('RESTING_HR', resting(60, 58)))).assertEqual('53–63 bpm');
      expect(bandText('HRV', metricBand('HRV', []))).assertEqual('30 ms or more');
      expect(bandText('STRESS', metricBand('STRESS', []))).assertEqual('up to 45 min');
      expect(dayText('2026-10-01', true)).assertEqual('Thu 1 Oct');
      expect(dayText('14:05:09', true)).assertEqual('14:05:09');
    });

    it('series follow the calendar days; a day without a watch row stays empty', 0, () => {
      const trend: TrendDay[] = [
        { day: '2026-10-01', restingBpm: 58, doses: 1, symptoms: 0, alerts: 0 },
        { day: '2026-10-02', restingBpm: 0, doses: 0, symptoms: 0, alerts: 0 }
      ];
      const row: WatchVitalsDay = {
        day: '2026-10-01', avgBpm: 71, minBpm: 54, maxBpm: 118, hrvMs: 48, spo2: 97.2, breathingRate: 14,
        sleepMinutes: 444, stressMinutes: 0, steps: 6400, simulated: false
      };
      const all: MetricSeries[] = buildSeries(trend, [row], false);
      expect(all.length).assertEqual(8);
      const hr: MetricSeries = seriesFor(all, 'HEART_RATE');
      expect(hr.days[0].lo).assertEqual(54);
      expect(hr.days[0].hi).assertEqual(118);
      expect(hr.days[1].value).assertEqual(NO_VALUE);
      expect(hr.simulated).assertFalse();
      expect(seriesFor(all, 'SLEEP').days[0].value).assertEqual(7.4);
      expect(seriesFor(all, 'STRESS').days[0].value).assertEqual(0);          // zero minutes is a reading
      expect(seriesFor(all, 'STRESS').days[1].value).assertEqual(NO_VALUE);
      expect(seriesFor(all, 'RESTING_HR').days[1].value).assertEqual(NO_VALUE);
      expect(seriesFor(all, 'HRV').simulated).assertTrue();                   // the watch can only simulate it
    });

    it('demo vitals are labelled simulated and tell the raised-days story', 0, () => {
      const demo: WatchVitalsDay[] = demoVitals(new Date(2026, 9, 3, 12, 0, 0).getTime());
      expect(demo.length > 50).assertTrue();
      expect(demo.every((d: WatchVitalsDay) => d.simulated)).assertTrue();
      expect(demo[1].hrvMs < demo[5].hrvMs).assertTrue();   // demo[0] is today so far
      expect(demo[1].avgBpm > demo[5].avgBpm).assertTrue();
      expect(demo.every((d: WatchVitalsDay) => d.minBpm < d.avgBpm && d.avgBpm < d.maxBpm)).assertTrue();
    });

    it('parses daily vitals and drops rows and values that make no sense', 0, () => {
      const body: string = JSON.stringify([
        { day: '2026-10-02', avg_bpm: 71, min_bpm: 54, max_bpm: 118, hrv_ms: 48, spo2: 97.24, breathing_rate: 14,
          sleep_minutes: 444, stress_minutes: 28, steps: 6400, simulated: true },
        { day: '2026-10-01', avg_bpm: null, min_bpm: null, max_bpm: null, hrv_ms: null, spo2: 140,
          breathing_rate: null, sleep_minutes: 0, stress_minutes: 0, steps: null, simulated: false },
        { day: 'yesterday', avg_bpm: 70 }
      ]);
      const rows: WatchVitalsDay[] | undefined = parseVitalsDaily(body);
      expect(rows !== undefined && rows.length === 2).assertTrue();
      if (rows !== undefined) {
        expect(rows[0].spo2).assertEqual(97.2);
        expect(rows[0].simulated).assertTrue();
        expect(rows[1].avgBpm).assertEqual(0);
        expect(rows[1].spo2).assertEqual(0);
      }
      expect(parseVitalsDaily('not json') === undefined).assertTrue();
    });
  });
}
