import { describe, it, expect } from '@ohos/hypium';
import { SCENARIOS, bpmAt, findScenario, stateAt } from '../main/ets/vitals/Scenarios';

export default function scenariosTest() {
  describe('Scenarios', () => {
    it('interpolates within a segment', 0, () => {
      const s = findScenario('lqt1_exercise');
      expect(bpmAt(s, 0)).assertEqual(75);
      expect(bpmAt(s, 5)).assertEqual(78);
    });

    it('holds the last value after the script ends', 0, () => {
      const s = findScenario('lqt3_night_brady');
      expect(bpmAt(s, 10000)).assertEqual(38);
    });

    it('unknown id falls back to the first scenario', 0, () => {
      expect(findScenario('nope').id).assertEqual(SCENARIOS[0].id);
      expect(SCENARIOS[0].id).assertEqual('tour');
    });

    it('normal workout stays under the exercise limit while active', 0, () => {
      const s = findScenario('workout');
      expect(stateAt(s, 40)).assertEqual('ACTIVE');
      expect(bpmAt(s, 40) < 140).assertTrue();
    });

    it('LQT2 startle happens at rest, LQT1 while active', 0, () => {
      expect(stateAt(findScenario('lqt2_startle'), 20)).assertEqual('REST');
      expect(stateAt(findScenario('lqt1_exercise'), 40)).assertEqual('ACTIVE');
      expect(stateAt(findScenario('lqt3_night_brady'), 20)).assertEqual('ASLEEP');
    });

    it('faint scenario has a fall after the racing heart', 0, () => {
      const s = findScenario('faint');
      expect(s.fallAtSec > 12).assertTrue();
      expect(bpmAt(s, 12) > 180).assertTrue();
    });

    it('full demo covers exercise, recovery, startle, sleep, rhythm and a fall', 0, () => {
      const s = findScenario('tour');
      expect(stateAt(s, 30)).assertEqual('ACTIVE');
      expect(bpmAt(s, 40) > 140).assertTrue();
      expect(bpmAt(s, 43) - bpmAt(s, 103) < 12).assertTrue();
      expect(bpmAt(s, 140) > 140).assertTrue();
      expect(stateAt(s, 180)).assertEqual('ASLEEP');
      expect(bpmAt(s, 180) < 40).assertTrue();
      expect(bpmAt(s, 224) >= 170).assertTrue();
      expect(s.fallAtSec).assertEqual(234);
    });

    it('each LQT scenario crosses the default limits (45-140)', 0, () => {
      expect(bpmAt(findScenario('lqt1_exercise'), 40) > 140).assertTrue();
      expect(bpmAt(findScenario('lqt2_startle'), 20) > 140).assertTrue();
      expect(bpmAt(findScenario('lqt3_night_brady'), 40) < 45).assertTrue();
    });
  });
}
