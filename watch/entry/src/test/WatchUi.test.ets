import { describe, it, expect } from '@ohos/hypium';
import { HrBucket, HrTrend, TREND_BUCKETS, TREND_BUCKET_MS, trendScale, trendY } from '../main/ets/vitals/HrTrend';
import {
  beatPeriodMs,
  breathingLevel,
  hrvLevel,
  levelWord,
  restingLevel,
  rhythmLevel,
  ringRatio,
  spo2Level,
  zoneFor,
  zoneWord
} from '../main/ets/vitals/WatchStatus';

const T0 = 1791050000000 - (1791050000000 % TREND_BUCKET_MS);

export default function watchUiTest() {
  describe('HrTrend', () => {
    it('keepsMinMaxAvgPerBucket', 0, () => {
      const t = new HrTrend();
      expect(t.add(70, T0)).assertTrue();
      expect(t.add(90, T0 + 1000)).assertFalse();
      expect(t.add(80, T0 + 2000)).assertFalse();
      const s = t.slots();
      expect(s.length).assertEqual(TREND_BUCKETS);
      const last: HrBucket = s[s.length - 1];
      expect(last.min).assertEqual(70);
      expect(last.max).assertEqual(90);
      expect(last.avg()).assertEqual(80);
      expect(s[0].count).assertEqual(0);
    });

    it('ignoresMissingReadings', 0, () => {
      const t = new HrTrend();
      expect(t.add(0, T0)).assertFalse();
      expect(t.slots().length).assertEqual(0);
      expect(t.summary().filled).assertEqual(0);
    });

    it('dropsBucketsOutsideTheWindowAndKeepsGaps', 0, () => {
      const t = new HrTrend();
      t.add(60, T0);
      t.add(62, T0 + 2 * TREND_BUCKET_MS);
      let s = t.slots();
      expect(s[s.length - 2].count).assertEqual(0);
      expect(s[s.length - 3].count).assertEqual(1);
      t.add(64, T0 + (TREND_BUCKETS + 5) * TREND_BUCKET_MS);
      s = t.slots();
      expect(t.summary().filled).assertEqual(1);
      expect(t.summary().avg).assertEqual(64);
    });

    it('summarisesTheWindow', 0, () => {
      const t = new HrTrend();
      t.add(60, T0);
      t.add(100, T0 + TREND_BUCKET_MS);
      t.add(80, T0 + TREND_BUCKET_MS + 1);
      const sum = t.summary();
      expect(sum.min).assertEqual(60);
      expect(sum.max).assertEqual(100);
      expect(sum.avg).assertEqual(80);
      expect(sum.filled).assertEqual(2);
    });

    it('scaleFitsReadingsAndLimits', 0, () => {
      const t = new HrTrend();
      t.add(150, T0);
      const sc = trendScale(t.slots(), 45, 120);
      expect(sc.lo).assertEqual(40);
      expect(sc.hi).assertEqual(160);
      expect(trendY(40, sc)).assertEqual(0);
      expect(trendY(160, sc)).assertEqual(1);
      expect(trendY(500, sc)).assertEqual(1);
    });
  });

  describe('WatchStatus', () => {
    it('levelsUseTheSameWordsAsThePhone', 0, () => {
      expect(levelWord(hrvLevel(15))).assertEqual('Worth a look');
      expect(levelWord(hrvLevel(25))).assertEqual('Okay');
      expect(levelWord(hrvLevel(45))).assertEqual('Good');
      expect(levelWord(hrvLevel(0))).assertEqual('No data');
      expect(spo2Level(91)).assertEqual('LOOK');
      expect(spo2Level(93)).assertEqual('OKAY');
      expect(spo2Level(98)).assertEqual('GOOD');
      expect(breathingLevel(16)).assertEqual('GOOD');
      expect(breathingLevel(22)).assertEqual('OKAY');
      expect(breathingLevel(30)).assertEqual('LOOK');
      expect(restingLevel(62)).assertEqual('GOOD');
      expect(restingLevel(47)).assertEqual('OKAY');
      expect(rhythmLevel(true, true)).assertEqual('LOOK');
      expect(rhythmLevel(false, false)).assertEqual('NONE');
    });

    it('zonesFollowTheLimits', 0, () => {
      expect(zoneFor(0, 45, 120, false)).assertEqual('WAITING');
      expect(zoneFor(70, 45, 120, false)).assertEqual('CALM');
      expect(zoneFor(110, 45, 120, false)).assertEqual('NEAR');
      expect(zoneFor(70, 45, 120, true)).assertEqual('NEAR');
      expect(zoneFor(121, 45, 120, false)).assertEqual('ABOVE');
      expect(zoneFor(40, 45, 120, false)).assertEqual('BELOW');
      expect(zoneWord('ABOVE')).assertEqual('Above your max');
    });

    it('ringAndBeatFollowTheZone', 0, () => {
      expect(ringRatio(0, 45, 120)).assertEqual(0);
      expect(ringRatio(45, 45, 120)).assertEqual(0.03);
      expect(ringRatio(200, 45, 120)).assertEqual(1);
      expect(beatPeriodMs('CALM')).assertEqual(1100);
      expect(beatPeriodMs('ABOVE')).assertEqual(500);
    });
  });
}
