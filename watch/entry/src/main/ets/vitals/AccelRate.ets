import { Activity } from '../model/WatchMetric';

const G = 9.81;
/** 25 Hz: activity and impact detection while the wearer moves. */
export const ACCEL_ACTIVE_NS = 40000000;
/**
 * 10 Hz at rest or asleep. A smaller interval means more reports and more power (Sensor Service Kit guide); the
 * sensor clamps it to its own min/max sample period (`getSingleSensor`).
 */
export const ACCEL_REST_NS = 100000000;
/** Rest must last this long before slowing down, so short pauses don't flip the rate back and forth. */
export const SLOW_AFTER_REST_MS = 30000;
/**
 * Any sample this far from 1 g switches straight back to 25 Hz. A fall from standing starts with near free fall
 * (|a| ≈ 0) for a few hundred ms, which 10 Hz still sees before the impact.
 */
const WAKE_DEVIATION = 0.3 * G;

/**
 * Accelerometer rate policy (energy): 25 Hz while moving, 10 Hz after 30 s at rest or asleep, 25 Hz again on the
 * first sample that moves. Pure logic; `SensorHub` applies the interval.
 */
export class AccelRate {
  private slow: boolean = false;
  private restSinceMs: number = -1;

  get intervalNs(): number {
    return this.slow ? ACCEL_REST_NS : ACCEL_ACTIVE_NS;
  }

  /** Once a second with the current state. True when the interval changed. */
  onActivity(activity: Activity, nowMs: number): boolean {
    if (activity === 'REST' || activity === 'ASLEEP') {
      if (this.restSinceMs < 0) {
        this.restSinceMs = nowMs;
      }
      if (!this.slow && nowMs - this.restSinceMs >= SLOW_AFTER_REST_MS) {
        this.slow = true;
        return true;
      }
      return false;
    }
    this.restSinceMs = -1;
    return this.wake();
  }

  /** Every accelerometer sample. True when the interval changed (movement at the slow rate). */
  onSample(x: number, y: number, z: number): boolean {
    if (!this.slow) {
      return false;
    }
    const mag = Math.sqrt(x * x + y * y + z * z);
    if (Math.abs(mag - G) <= WAKE_DEVIATION) {
      return false;
    }
    this.restSinceMs = -1;
    return this.wake();
  }

  /** Monitoring (re)started: full rate. */
  reset(): void {
    this.slow = false;
    this.restSinceMs = -1;
  }

  private wake(): boolean {
    if (!this.slow) {
      return false;
    }
    this.slow = false;
    return true;
  }
}
