import { describe, it, expect } from '@ohos/hypium';
import { AlarmRules } from '../main/ets/vitals/AlarmRules';
import { HrAlertValues } from '../main/ets/model/WatchMetric';

function rules(): AlarmRules {
  return new AlarmRules({ highBpm: 140, lowBpm: 45, sustainSec: 10, cooldownSec: 60 });
}

/** Feeds one sample per second from `startSec` for `seconds`, returns the alerts raised. */
function feed(r: AlarmRules, bpm: number, startSec: number, seconds: number): HrAlertValues[] {
  const out: HrAlertValues[] = [];
  for (let s = startSec; s < startSec + seconds; s++) {
    const a = r.evaluate(bpm, s * 1000);
    if (a !== undefined) {
      out.push(a);
    }
  }
  return out;
}

export default function alarmRulesTest() {
  describe('AlarmRules', () => {
    it('stays quiet inside limits', 0, () => {
      expect(feed(rules(), 90, 0, 120).length).assertEqual(0);
    });

    it('ignores a short spike (motion artefact)', 0, () => {
      const r = rules();
      expect(feed(r, 160, 0, 5).length).assertEqual(0);
      expect(feed(r, 80, 5, 30).length).assertEqual(0);
    });

    it('alerts once when high is sustained, then respects cooldown', 0, () => {
      const r = rules();
      const alerts = feed(r, 155, 0, 40);
      expect(alerts.length).assertEqual(1);
      expect(alerts[0].direction).assertEqual('high');
      expect(alerts[0].limitBpm).assertEqual(140);
      expect(alerts[0].sustainedSec).assertEqual(10);
    });

    it('alerts again after the cooldown', 0, () => {
      const r = rules();
      expect(feed(r, 155, 0, 75).length).assertEqual(2);
    });

    it('alerts on sustained low heart rate (LQT3 night)', 0, () => {
      const alerts = feed(rules(), 38, 0, 15);
      expect(alerts.length).assertEqual(1);
      expect(alerts[0].direction).assertEqual('low');
    });

    it('resets the timer when HR returns to range', 0, () => {
      const r = rules();
      feed(r, 150, 0, 8);
      feed(r, 100, 8, 2);
      expect(feed(r, 150, 10, 9).length).assertEqual(0);
    });
  });
}
