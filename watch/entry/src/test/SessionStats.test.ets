import { describe, it, expect } from '@ohos/hypium';
import { SessionStats } from '../main/ets/vitals/SessionStats';

export default function sessionStatsTest() {
  describe('SessionStats', () => {
    it('returns undefined for an empty session', 0, () => {
      expect(new SessionStats().summary() === undefined).assertTrue();
    });

    it('computes avg/min/max/duration', 0, () => {
      const s = new SessionStats();
      s.add(60, 0);
      s.add(90, 1000);
      s.add(120, 30000);
      const sum = s.summary();
      expect(sum !== undefined).assertTrue();
      if (sum !== undefined) {
        expect(sum.avgBpm).assertEqual(90);
        expect(sum.minBpm).assertEqual(60);
        expect(sum.maxBpm).assertEqual(120);
        expect(sum.durationSec).assertEqual(30);
        expect(sum.samples).assertEqual(3);
      }
    });
  });
}
