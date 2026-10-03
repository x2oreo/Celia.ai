import { Activity } from '../model/WatchMetric';

const G = 9.81;
/** Impact threshold: ~2.5 g. */
const IMPACT = 2.5 * G;
/** Std-dev of |acceleration| (m/s²) above which the wearer is moving, and below which they are still. */
const ACTIVE_STD = 1.5;
const STILL_STD = 0.8;
const ACTIVITY_WINDOW_MS = 4000;
/** After an impact, ignore 1 s of bounce, then require stillness until 4 s after the impact. */
const FALL_SETTLE_MS = 1000;
const FALL_STILL_UNTIL_MS = 4000;
const SILENT_MS = 2000;

interface MagSample {
  ts: number;
  mag: number;
}

function std(values: number[]): number {
  if (values.length < 2) {
    return 0;
  }
  let sum = 0;
  for (const v of values) {
    sum += v;
  }
  const mean = sum / values.length;
  let sq = 0;
  for (const v of values) {
    sq += (v - mean) * (v - mean);
  }
  return Math.sqrt(sq / values.length);
}

/**
 * Turns raw accelerometer samples into (a) rest/active and (b) fall events (hard impact, then lying still).
 * Pure logic, testable without a device. Heuristic, not a medical-grade fall detector.
 */
export class MotionAnalyzer {
  private samples: MagSample[] = [];
  private current: Activity = 'UNKNOWN';
  private impactAt: number = -1;

  get activity(): Activity {
    return this.current;
  }

  /**
   * Activity at `nowMs`, given that an accelerometer is running. Some sensors (incl. the emulator's) report only on
   * change, so silence for 2 s means nothing is moving: rest.
   */
  activityAt(nowMs: number): Activity {
    const last = this.samples.length > 0 ? this.samples[this.samples.length - 1].ts : -1;
    if (last < 0 || nowMs - last > SILENT_MS) {
      return 'REST';
    }
    return this.current;
  }

  /** Returns true exactly once per detected fall. */
  feed(x: number, y: number, z: number, tsMs: number): boolean {
    const mag = Math.sqrt(x * x + y * y + z * z);
    this.samples.push({ ts: tsMs, mag: mag });
    while (this.samples.length > 0 && tsMs - this.samples[0].ts > ACTIVITY_WINDOW_MS) {
      this.samples.shift();
    }
    this.updateActivity(tsMs);

    if (mag > IMPACT) {
      this.impactAt = tsMs;
      return false;
    }
    if (this.impactAt >= 0 && tsMs - this.impactAt >= FALL_STILL_UNTIL_MS) {
      const after: number[] = [];
      for (const s of this.samples) {
        if (s.ts >= this.impactAt + FALL_SETTLE_MS) {
          after.push(s.mag);
        }
      }
      this.impactAt = -1;
      return after.length >= 5 && std(after) < STILL_STD;
    }
    return false;
  }

  private updateActivity(tsMs: number): void {
    if (this.samples.length < 10 || tsMs - this.samples[0].ts < ACTIVITY_WINDOW_MS / 2) {
      return;
    }
    const mags: number[] = [];
    for (const s of this.samples) {
      mags.push(s.mag);
    }
    const sd = std(mags);
    // Hysteresis so the label doesn't flicker around one threshold.
    if (sd > ACTIVE_STD) {
      this.current = 'ACTIVE';
    } else if (sd < STILL_STD) {
      this.current = 'REST';
    }
  }
}
