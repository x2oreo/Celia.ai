import { describe, it, expect } from '@ohos/hypium';
import { SCENARIOS, activeAt, bpmAt, findScenario } from '../main/ets/vitals/Scenarios';

export default function scenariosTest() {
  describe('Scenarios', () => {
    it('interpolates within a segment', 0, () => {
      const s = findScenario('lqt1_exercise');
      expect(bpmAt(s, 0)).assertEqual(75);
      expect(bpmAt(s, 10)).assertEqual(80);
    });

    it('holds the last value after the script ends', 0, () => {
      const s = findScenario('lqt3_night_brady');
      expect(bpmAt(s, 10000)).assertEqual(40);
    });

    it('unknown id falls back to the first scenario', 0, () => {
      expect(findScenario('nope').id).assertEqual(SCENARIOS[0].id);
    });

    it('normal workout stays under the exercise limit while active', 0, () => {
      const s = findScenario('workout');
      expect(activeAt(s, 40)).assertTrue();
      expect(bpmAt(s, 40) < 140).assertTrue();
    });

    it('LQT2 startle happens at rest, LQT1 while active', 0, () => {
      expect(activeAt(findScenario('lqt2_startle'), 20)).assertFalse();
      expect(activeAt(findScenario('lqt1_exercise'), 40)).assertTrue();
    });

    it('faint scenario has a fall after the racing heart', 0, () => {
      const s = findScenario('faint');
      expect(s.fallAtSec > 12).assertTrue();
      expect(bpmAt(s, 12) > 180).assertTrue();
    });

    it('each LQT scenario crosses the default limits (45-140)', 0, () => {
      expect(bpmAt(findScenario('lqt1_exercise'), 60) > 140).assertTrue();
      expect(bpmAt(findScenario('lqt2_startle'), 20) > 140).assertTrue();
      expect(bpmAt(findScenario('lqt3_night_brady'), 40) < 45).assertTrue();
    });
  });
}
