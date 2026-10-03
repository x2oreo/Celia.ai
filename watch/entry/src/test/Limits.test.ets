import { describe, it, expect } from '@ohos/hypium';
import { defaultBaseLimits, isStressed, limitsFor } from '../main/ets/vitals/Limits';

export default function limitsTest() {
  describe('Limits', () => {
    const base = defaultBaseLimits();

    it('max depends on state: rest < active, asleep lowest', 0, () => {
      expect(limitsFor('REST', 'UNKNOWN', false, base).high).assertEqual(120);
      expect(limitsFor('ACTIVE', 'UNKNOWN', false, base).high).assertEqual(140);
      expect(limitsFor('ASLEEP', 'UNKNOWN', false, base).high).assertEqual(100);
      expect(limitsFor('ASLEEP', 'UNKNOWN', false, base).low).assertEqual(40);
    });

    it('genotype adjusts the risky state', 0, () => {
      expect(limitsFor('ACTIVE', 'LQT1', false, base).high).assertEqual(130);
      expect(limitsFor('REST', 'LQT2', false, base).high).assertEqual(110);
      expect(limitsFor('REST', 'LQT3', false, base).low).assertEqual(50);
      expect(limitsFor('REST', 'LQT1', false, base).high).assertEqual(120);
    });

    it('recent risky drug lowers high limits', 0, () => {
      const l = limitsFor('REST', 'LQT2', true, base);
      expect(l.high).assertEqual(100);
      expect(l.reason).assertEqual('LQT2 · rest · drug');
    });

    it('stress = HR > resting × 1.35 at rest', 0, () => {
      expect(isStressed(90, 65, 'REST', 0)).assertTrue();
      expect(isStressed(80, 65, 'REST', 0)).assertFalse();
      expect(isStressed(120, 65, 'ACTIVE', 0)).assertFalse();
      expect(isStressed(90, 65, 'REST', 50)).assertFalse();
    });
  });
}
