import { describe, it, expect } from '@ohos/hypium';
import { AlarmRules } from '../main/ets/vitals/AlarmRules';
import { HrLimits } from '../main/ets/vitals/Limits';
import { HrAlertValues } from '../main/ets/model/WatchMetric';

function rules(): AlarmRules {
  return new AlarmRules({ sustainSec: 10, cooldownSec: 60 });
}

function limits(high: number, low: number): HrLimits {
  const l: HrLimits = { high: high, low: low, reason: 'test' };
  return l;
}

/** Feeds one sample per second from `startSec` for `seconds`, returns the alerts raised. */
function feed(r: AlarmRules, bpm: number, startSec: number, seconds: number, l: HrLimits): HrAlertValues[] {
  const out: HrAlertValues[] = [];
  for (let s = startSec; s < startSec + seconds; s++) {
    const a = r.evaluate(bpm, s * 1000, l, 'REST');
    if (a !== undefined) {
      out.push(a);
    }
  }
  return out;
}

export default function alarmRulesTest() {
  describe('AlarmRules', () => {
    const l = limits(140, 45);

    it('stays quiet inside limits', 0, () => {
      expect(feed(rules(), 90, 0, 120, l).length).assertEqual(0);
    });

    it('ignores a short spike (motion artefact)', 0, () => {
      const r = rules();
      expect(feed(r, 160, 0, 5, l).length).assertEqual(0);
      expect(feed(r, 80, 5, 30, l).length).assertEqual(0);
    });

    it('alerts once when high is sustained, then respects cooldown', 0, () => {
      const alerts = feed(rules(), 155, 0, 40, l);
      expect(alerts.length).assertEqual(1);
      expect(alerts[0].direction).assertEqual('high');
      expect(alerts[0].limitBpm).assertEqual(140);
      expect(alerts[0].sustainedSec).assertEqual(10);
    });

    it('alerts again after the cooldown', 0, () => {
      expect(feed(rules(), 155, 0, 75, l).length).assertEqual(2);
    });

    it('alerts on sustained low heart rate', 0, () => {
      const alerts = feed(rules(), 38, 0, 15, l);
      expect(alerts.length).assertEqual(1);
      expect(alerts[0].direction).assertEqual('low');
    });

    it('uses whatever limit it is given (state-dependent)', 0, () => {
      expect(feed(rules(), 130, 0, 15, limits(120, 45)).length).assertEqual(1);
      expect(feed(rules(), 130, 0, 15, limits(140, 45)).length).assertEqual(0);
    });

    it('resets the timer when HR returns to range', 0, () => {
      const r = rules();
      feed(r, 150, 0, 8, l);
      feed(r, 100, 8, 2, l);
      expect(feed(r, 150, 10, 9, l).length).assertEqual(0);
    });
  });
}
