import { describe, it, expect } from '@ohos/hypium';
import { AlertKind, HeartRules, Reading, RulesHost } from '../main/ets/controller/HeartRules';
import { Activity, HrAlertValues, MetricPayload, MetricType, VitalsValues } from '../main/ets/model/WatchMetric';
import { HrLimits } from '../main/ets/vitals/Limits';

/** Remembers every call so a test can read back the rows, alerts and vibrations in order. */
class FakeHost implements RulesHost {
  rows: MetricType[] = [];
  payloads: MetricPayload[] = [];
  alerts: string[] = [];
  vibrations: number[] = [];

  record(type: MetricType, payload: MetricPayload, tsMs: number): void {
    this.rows.push(type);
    this.payloads.push(payload);
  }

  showAlert(kind: AlertKind, value: number, detail: string): void {
    this.alerts.push(`${kind} ${value} ${detail}`);
  }

  vibrate(durationMs: number): void {
    this.vibrations.push(durationMs);
  }

  vitalsSnapshot(): VitalsValues {
    const v: VitalsValues = {
      bpm: 0, restingBpm: 0, activity: 'REST', stress: false, steps: 0, hrvMs: 0, spo2: 0, breathingRate: 0,
      irregularRhythm: false, highLimitBpm: 0, lowLimitBpm: 0, genotype: 'UNKNOWN', riskyDrug: '', mocked: []
    };
    return v;
  }

  count(type: MetricType): number {
    return this.rows.filter((t: MetricType) => t === type).length;
  }
}

const T0 = 1700000000000;

function limits(high: number, low: number, reason: string): HrLimits {
  const l: HrLimits = { high: high, low: low, reason: reason };
  return l;
}

function reading(sec: number, bpm: number, activity: Activity, l: HrLimits, drug: string): Reading {
  const r: Reading = {
    nowMs: T0 + sec * 1000, logicMs: T0 + sec * 1000, bpm: bpm, activity: activity, limits: l, riskyDrug: drug
  };
  return r;
}

/** Fixed "random" so simulated vitals are normal and repeatable. */
function rules(host: FakeHost): HeartRules {
  const r = new HeartRules(host, () => 0.5);
  r.configure(5, 60);
  r.start(T0);
  return r;
}

export default function heartRulesTest() {
  describe('HeartRules', () => {
    it('sends hr_live every 5 s and vitals every 30 s', 0, () => {
      const host = new FakeHost();
      const r = rules(host);
      expect(r.restingBpm).assertEqual(60);
      for (let s = 0; s <= 30; s++) {
        r.process(reading(s, 70, 'REST', limits(120, 45, 'rest'), ''));
      }
      expect(host.count('hr_live')).assertEqual(7);
      expect(host.count('vitals')).assertEqual(1);
      expect(host.alerts.length).assertEqual(0);
      expect(r.hrvMs > 0).assertTrue();
      expect(r.spo2 > 0).assertTrue();
    });

    it('a high heart rate held for the sustain time raises one alert', 0, () => {
      const host = new FakeHost();
      const r = rules(host);
      for (let s = 0; s <= 8; s++) {
        r.process(reading(s, 150, 'ACTIVE', limits(140, 45, 'active'), ''));
      }
      expect(host.count('hr_alert')).assertEqual(1);
      expect(host.alerts.length).assertEqual(1);
      expect(host.alerts[0]).assertEqual('HIGH 150 Limit 140 · active');
      expect(host.vibrations[host.vibrations.length - 1]).assertEqual(1200);
      const a = host.payloads[host.rows.indexOf('hr_alert')] as HrAlertValues;
      expect(a.direction).assertEqual('high');
    });

    it('a lowered high limit names the drug, and a low alert asleep vibrates gently', 0, () => {
      const host = new FakeHost();
      const r = rules(host);
      for (let s = 0; s <= 6; s++) {
        r.process(reading(s, 125, 'REST', limits(110, 45, 'rest · drug'), 'clarithromycin'));
      }
      expect(host.alerts[0]).assertEqual('HIGH 125 Limit 110 · lowered for Clarithromycin');
      const h2 = new FakeHost();
      const r2 = rules(h2);
      for (let s = 0; s <= 6; s++) {
        r2.process(reading(s, 35, 'ASLEEP', limits(100, 40, 'asleep'), 'clarithromycin'));
      }
      expect(h2.alerts[0]).assertEqual('LOW 35 Limit 40 · asleep');
      expect(h2.vibrations[h2.vibrations.length - 1]).assertEqual(400);
    });

    it('wear changes reset the sustain timer', 0, () => {
      const host = new FakeHost();
      const r = rules(host);
      for (let s = 0; s <= 3; s++) {
        r.process(reading(s, 150, 'ACTIVE', limits(140, 45, 'active'), ''));
      }
      r.resetAlarm();
      for (let s = 4; s <= 7; s++) {
        r.process(reading(s, 150, 'ACTIVE', limits(140, 45, 'active'), ''));
      }
      expect(host.count('hr_alert')).assertEqual(0);
    });

    it('slow recovery after exercise is recorded and alerted', 0, () => {
      const host = new FakeHost();
      const r = rules(host);
      for (let s = 0; s <= 30; s++) {
        r.process(reading(s, 130, 'ACTIVE', limits(200, 30, 'active'), ''));
      }
      for (let s = 31; s <= 92; s++) {
        r.process(reading(s, 125, 'REST', limits(200, 30, 'rest'), ''));
      }
      expect(host.count('hr_recovery')).assertEqual(1);
      expect(r.lastRecovery).assertEqual('130→125 (−5) slow');
      expect(host.alerts[0].startsWith('RECOVERY 125 Only −5 bpm')).assertTrue();
    });

    it('a tapped SpO2 anomaly drifts down and alerts once', 0, () => {
      const host = new FakeHost();
      const r = rules(host);
      r.startAnomaly('spo2', T0);
      expect(r.anomaly).assertEqual('spo2');
      expect(r.anomalyRamping(T0 + 2000, 2500)).assertTrue();
      for (let ms = 0; ms <= 6000; ms += 250) {
        r.updateMockedVitals(70, 'REST', T0 + ms);
      }
      expect(r.spo2 < 92).assertTrue();
      expect(host.count('vitals_alert')).assertEqual(1);
      expect(host.alerts[0].startsWith('SPO2')).assertTrue();
      expect(r.anomalyRamping(T0 + 5000, 2500)).assertFalse();
      r.updateMockedVitals(70, 'REST', T0 + 20000);
      expect(r.anomaly).assertEqual('none');
    });

    it('the summary window closes after 5 min and only with samples', 0, () => {
      const host = new FakeHost();
      const r = rules(host);
      r.flushWindow(T0);
      expect(host.count('hr_session')).assertEqual(0);
      r.process(reading(1, 70, 'REST', limits(120, 45, 'rest'), ''));
      expect(r.windowDue(T0 + 299000)).assertFalse();
      expect(r.windowDue(T0 + 300000)).assertTrue();
      r.flushWindow(T0 + 300000);
      expect(host.count('hr_session')).assertEqual(1);
      expect(r.windowDue(T0 + 300000)).assertFalse();
    });
  });
}
