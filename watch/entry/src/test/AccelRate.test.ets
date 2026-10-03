import { describe, it, expect } from '@ohos/hypium';
import { ACCEL_ACTIVE_NS, ACCEL_REST_NS, AccelRate, SLOW_AFTER_REST_MS } from '../main/ets/vitals/AccelRate';
import { MotionAnalyzer } from '../main/ets/vitals/MotionAnalyzer';

const G = 9.81;

export default function accelRateTest() {
  describe('AccelRate', () => {
    it('slows to 10 Hz only after 30 s at rest', 0, () => {
      const r = new AccelRate();
      expect(r.intervalNs).assertEqual(ACCEL_ACTIVE_NS);
      expect(r.onActivity('REST', 0)).assertFalse();
      expect(r.onActivity('REST', SLOW_AFTER_REST_MS - 1)).assertFalse();
      expect(r.onActivity('ASLEEP', SLOW_AFTER_REST_MS)).assertTrue();
      expect(r.intervalNs).assertEqual(ACCEL_REST_NS);
      expect(r.onActivity('REST', SLOW_AFTER_REST_MS + 1000)).assertFalse();
    });

    it('a short pause does not slow it down', 0, () => {
      const r = new AccelRate();
      r.onActivity('REST', 0);
      r.onActivity('ACTIVE', 20000);
      expect(r.onActivity('REST', 31000)).assertFalse();
      expect(r.intervalNs).assertEqual(ACCEL_ACTIVE_NS);
    });

    it('wakes on activity or on the first sample that moves', 0, () => {
      const r = new AccelRate();
      r.onActivity('REST', 0);
      r.onActivity('REST', SLOW_AFTER_REST_MS);
      expect(r.onSample(0, 0, G + 0.5)).assertFalse();
      expect(r.onSample(0, 0, 0.2)).assertTrue();
      expect(r.intervalNs).assertEqual(ACCEL_ACTIVE_NS);
      expect(r.onSample(0, 0, 0.2)).assertFalse();
      r.onActivity('REST', 40000);
      r.onActivity('REST', 40000 + SLOW_AFTER_REST_MS);
      expect(r.onActivity('ACTIVE', 80000)).assertTrue();
      r.reset();
      expect(r.intervalNs).assertEqual(ACCEL_ACTIVE_NS);
    });

    it('a fall from rest is still detected: free fall at 10 Hz wakes 25 Hz before the impact', 0, () => {
      const r = new AccelRate();
      const m = new MotionAnalyzer();
      r.onActivity('REST', 0);
      r.onActivity('REST', SLOW_AFTER_REST_MS);
      let t = 0;
      let step = r.intervalNs / 1000000;
      let falls = 0;
      // 5 s standing still at the slow rate.
      for (; t < 5000; t += step) {
        if (m.feed(0, 0, G, t)) {
          falls++;
        }
      }
      // 400 ms of free fall; the policy switches back to the fast rate on the first free-fall sample.
      const fallEnd = t + 400;
      for (; t < fallEnd; t += step) {
        if (r.onSample(0, 0, 0.5)) {
          step = r.intervalNs / 1000000;
        }
        m.feed(0, 0, 0.5, t);
      }
      expect(step).assertEqual(40);
      // Impact (one 40 ms sample), then lying still for 5 s.
      m.feed(0, 0, 3.2 * G, t);
      t += step;
      for (const end = t + 5000; t < end; t += step) {
        if (m.feed(0, 0, G, t)) {
          falls++;
        }
      }
      expect(falls).assertEqual(1);
    });
  });
}
