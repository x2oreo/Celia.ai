import { describe, it, expect } from '@ohos/hypium';
import { MotionAnalyzer } from '../main/ets/vitals/MotionAnalyzer';

const G = 9.81;
const STEP_MS = 40;

/** Feeds `seconds` of samples at 25 Hz; magnitude = g + amplitude·sin. Returns how many falls were reported. */
function feed(m: MotionAnalyzer, startMs: number, seconds: number, amplitude: number): number {
  let falls = 0;
  for (let t = 0; t < seconds * 1000; t += STEP_MS) {
    const z = G + amplitude * Math.sin(t / 150);
    if (m.feed(0, 0, z, startMs + t)) {
      falls++;
    }
  }
  return falls;
}

function impact(m: MotionAnalyzer, tsMs: number): void {
  m.feed(0, 0, 3.2 * G, tsMs);
}

export default function motionAnalyzerTest() {
  describe('MotionAnalyzer', () => {
    it('is UNKNOWN before enough data', 0, () => {
      const m = new MotionAnalyzer();
      feed(m, 0, 1, 0.1);
      expect(m.activity).assertEqual('UNKNOWN');
    });

    it('detects rest when still', 0, () => {
      const m = new MotionAnalyzer();
      feed(m, 0, 6, 0.1);
      expect(m.activity).assertEqual('REST');
    });

    it('detects activity when moving', 0, () => {
      const m = new MotionAnalyzer();
      feed(m, 0, 6, 4);
      expect(m.activity).assertEqual('ACTIVE');
    });

    it('reports a fall: impact then lying still', 0, () => {
      const m = new MotionAnalyzer();
      feed(m, 0, 5, 0.1);
      impact(m, 5000);
      expect(feed(m, 5040, 6, 0.1)).assertEqual(1);
    });

    it('no fall when the wearer keeps moving after an impact (e.g. clap, bump)', 0, () => {
      const m = new MotionAnalyzer();
      feed(m, 0, 5, 3);
      impact(m, 5000);
      expect(feed(m, 5040, 6, 3)).assertEqual(0);
    });
  });
}
