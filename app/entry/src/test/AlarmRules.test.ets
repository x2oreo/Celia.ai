import { describe, it, expect } from '@ohos/hypium';
import { AlarmRules, DEBOUNCE_MS } from '../main/ets/vitals/AlarmRules';
import { ScenarioName, scenarioSample } from '../main/ets/vitals/SimulatedSource';
import { VitalsAlert, VitalsSample } from '../main/ets/model/Vitals';
import { Genotype } from '../main/ets/model/Profile';

// Plays a scenario second by second and returns every alert fired.
function play(name: ScenarioName, genotype: Genotype, seconds: number): VitalsAlert[] {
  const rules: AlarmRules = new AlarmRules(genotype);
  const out: VitalsAlert[] = [];
  for (let t = 0; t < seconds; t++) {
    const s: VitalsSample | undefined = scenarioSample(name, t, t * 1000);
    if (s === undefined) {
      continue;
    }
    const a: VitalsAlert | undefined = rules.evaluate(s);
    if (a !== undefined) {
      out.push(a);
    }
  }
  return out;
}

function sample(hr: number, ts: number): VitalsSample {
  const s: VitalsSample = { ts: ts, hr: hr, source: 'SIMULATED' };
  return s;
}

export default function alarmRulesTest() {
  describe('AlarmRules', () => {
    it('normalScenarioIsQuiet', 0, () => {
      expect(play('normal', 'LQT2', 120).length).assertEqual(0);
    });

    it('lqt2StartleIsCriticalTachy', 0, () => {
      const alerts: VitalsAlert[] = play('lqt2_startle_tachy', 'LQT2', 30);
      expect(alerts.length > 0).assertTrue();
      expect(alerts[0].kind).assertEqual('TACHY_AT_REST');
      expect(alerts[0].severity).assertEqual('CRITICAL');
      expect(alerts[0].message.includes('LQT2')).assertTrue();
    });

    it('lqt3NightBradyIsCriticalForLqt3', 0, () => {
      const alerts: VitalsAlert[] = play('lqt3_night_brady', 'LQT3', 40);
      const brady: VitalsAlert | undefined = alerts.find((a: VitalsAlert) => a.kind === 'BRADY');
      expect(brady !== undefined && brady.severity === 'CRITICAL').assertTrue();
    });

    it('lqt1ExerciseWarnsOnExertion', 0, () => {
      const alerts: VitalsAlert[] = play('lqt1_exercise', 'LQT1', 40);
      const ex: VitalsAlert | undefined = alerts.find((a: VitalsAlert) => a.kind === 'HIGH_HR_EXERTION');
      expect(ex !== undefined && ex.severity === 'CRITICAL').assertTrue();
      expect(alerts.some((a: VitalsAlert) => a.kind === 'TACHY_AT_REST')).assertFalse();
    });

    it('irregularRhythmWarns', 0, () => {
      const alerts: VitalsAlert[] = play('irregular_rhythm', 'UNKNOWN', 20);
      expect(alerts.some((a: VitalsAlert) => a.kind === 'IRREGULAR_RHYTHM')).assertTrue();
    });

    it('disconnectStopsSamples', 0, () => {
      expect(scenarioSample('watch_disconnect', 10, 10000) === undefined).assertTrue();
      const rules: AlarmRules = new AlarmRules('UNKNOWN');
      const a: VitalsAlert | undefined = rules.disconnected(20000);
      expect(a !== undefined && a.kind === 'WATCH_DISCONNECTED').assertTrue();
      expect(rules.disconnected(21000) === undefined).assertTrue();
    });

    it('debounceSuppressesRepeats', 0, () => {
      const rules: AlarmRules = new AlarmRules('UNKNOWN');
      expect(rules.evaluate(sample(160, 0)) !== undefined).assertTrue();
      expect(rules.evaluate(sample(160, 1000)) === undefined).assertTrue();
      expect(rules.evaluate(sample(160, DEBOUNCE_MS + 1)) !== undefined).assertTrue();
    });

    it('moderateTachyIsWarnForUnknownGenotype', 0, () => {
      const rules: AlarmRules = new AlarmRules('UNKNOWN');
      const a: VitalsAlert | undefined = rules.evaluate(sample(130, 0));
      expect(a !== undefined && a.severity === 'WARN').assertTrue();
    });
  });
}
