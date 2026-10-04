import { describe, it, expect } from '@ohos/hypium';
import { RestingHr } from '../main/ets/vitals/RestingHr';
import { RecoveryTracker } from '../main/ets/vitals/RecoveryTracker';
import { isAsleep } from '../main/ets/vitals/SleepDetector';
import { ANOMALY_RAMP_MS, anomalyProgress, applyAnomaly, mockVitals, vitalAlertFor, hrAnomalyBpm, HR_ANOMALY_ABOVE_LIMIT } from '../main/ets/vitals/MockedVitals';
import { Activity, HrRecoveryValues } from '../main/ets/model/WatchMetric';

function runRecovery(peak: number, after: number): HrRecoveryValues | undefined {
  const t = new RecoveryTracker();
  let res: HrRecoveryValues | undefined = undefined;
  for (let s = 0; s < 30; s++) {
    t.add(peak, s * 1000, 'ACTIVE');
  }
  for (let s = 30; s <= 95; s++) {
    const r = t.add(after, s * 1000, 'REST');
    if (r !== undefined) {
      res = r;
    }
  }
  return res;
}

const half = (): number => 0.5;

export default function trackersTest() {
  describe('Trackers', () => {
    it('resting HR = lowest stable minute at rest', 0, () => {
      const r = new RestingHr(65);
      expect(r.measured).assertFalse();
      for (let s = 0; s <= 61; s++) {
        r.add(58, s * 1000, 'REST');
      }
      for (let s = 62; s <= 130; s++) {
        r.add(120, s * 1000, 'ACTIVE');
      }
      expect(r.measured).assertTrue();
      expect(r.value).assertEqual(58);
    });

    it('normal recovery after exercise', 0, () => {
      const r = runRecovery(150, 110);
      expect(r !== undefined).assertTrue();
      if (r !== undefined) {
        expect(r.dropBpm).assertEqual(40);
        expect(r.slow).assertFalse();
      }
    });

    it('slow recovery (< 12 bpm in 1 min) is flagged', 0, () => {
      const r = runRecovery(150, 142);
      expect(r !== undefined && r.slow).assertTrue();
    });

    it('asleep needs night, stillness, wrist and low HR', 0, () => {
      expect(isAsleep({ onWrist: true, stillSec: 900, bpm: 58, restingBpm: 60, hour: 2 })).assertTrue();
      expect(isAsleep({ onWrist: true, stillSec: 900, bpm: 58, restingBpm: 60, hour: 14 })).assertFalse();
      expect(isAsleep({ onWrist: false, stillSec: 900, bpm: 58, restingBpm: 60, hour: 2 })).assertFalse();
      expect(isAsleep({ onWrist: true, stillSec: 60, bpm: 58, restingBpm: 60, hour: 2 })).assertFalse();
      expect(isAsleep({ onWrist: true, stillSec: 900, bpm: 95, restingBpm: 60, hour: 2 })).assertFalse();
    });

    it('anomalies push one signal abnormal and the rule picks it up', 0, () => {
      expect(vitalAlertFor(mockVitals(70, 'REST', half), 'REST') === undefined).assertTrue();
      const early = applyAnomaly(mockVitals(70, 'REST', half), 'hrv', anomalyProgress(1000), half);
      expect(vitalAlertFor(early, 'REST') === undefined).assertTrue();
      expect(anomalyProgress(ANOMALY_RAMP_MS / 2)).assertEqual(0.5);
      const hrv = applyAnomaly(mockVitals(70, 'REST', half), 'hrv', 1, half);
      expect(vitalAlertFor(hrv, 'REST')).assertEqual('hrv');
      expect(vitalAlertFor(hrv, 'ACTIVE') === undefined).assertTrue();
      const spo2 = applyAnomaly(mockVitals(70, 'REST', half), 'spo2', 1, half);
      expect(vitalAlertFor(spo2, 'REST')).assertEqual('spo2');
      expect(applyAnomaly(mockVitals(70, 'REST', half), 'rhythm', 1, half).irregularRhythm).assertTrue();
      expect(applyAnomaly(mockVitals(70, 'REST', half), 'rhythm', 0.3, half).irregularRhythm).assertFalse();
    });

    it('mocked vitals: plausible ranges, irregular only for very fast HR at rest', 0, () => {
      const states: Activity[] = ['REST', 'ACTIVE', 'ASLEEP'];
      for (const a of states) {
        const v = mockVitals(70, a, half);
        expect(v.spo2 >= 90 && v.spo2 <= 100).assertTrue();
        expect(v.hrvMs > 0).assertTrue();
        expect(v.irregularRhythm).assertFalse();
      }
      expect(mockVitals(185, 'REST', half).irregularRhythm).assertTrue();
      expect(mockVitals(185, 'ACTIVE', half).irregularRhythm).assertFalse();
      expect(mockVitals(70, 'ACTIVE', half).hrvMs < mockVitals(70, 'REST', half).hrvMs).assertTrue();
    });

    it('heartTileDriftsAboveTheCurrentLimitAndBack', 0, () => {
      expect(hrAnomalyBpm(72, 120, 0)).assertEqual(72);
      expect(hrAnomalyBpm(72, 120, 1)).assertEqual(120 + HR_ANOMALY_ABOVE_LIMIT);
      expect(hrAnomalyBpm(72, 110, 0.5)).assertEqual(Math.round(72 + (125 - 72) * 0.5));
      // Already above the target: never pulls the real reading down.
      expect(hrAnomalyBpm(150, 120, 1)).assertEqual(150);
    });
  });
}
