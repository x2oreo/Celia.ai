import { Activity, HrRecoveryValues } from '../model/WatchMetric';

const RECOVERY_MS = 60000;
const SLOW_DROP_BPM = 12;
/** Ignore short bursts of movement: a bout must last this long to count as exercise. */
const MIN_BOUT_MS = 20000;

/**
 * Heart-rate recovery after exercise: when activity stops, compare the bout's peak HR with the HR 60 s later.
 * Slow recovery is relevant for LQT1 (exercise-triggered). Pure logic.
 */
export class RecoveryTracker {
  private boutStart: number = -1;
  private peak: number = 0;
  private stopAt: number = -1;
  private stopPeak: number = 0;

  /** Returns a result exactly once, 60 s after a bout ends. */
  add(bpm: number, tsMs: number, activity: Activity): HrRecoveryValues | undefined {
    if (activity === 'ACTIVE') {
      if (this.boutStart < 0) {
        this.boutStart = tsMs;
        this.peak = 0;
      }
      this.peak = Math.max(this.peak, bpm);
      this.stopAt = -1;
      return undefined;
    }
    if (this.boutStart >= 0) {
      if (tsMs - this.boutStart >= MIN_BOUT_MS) {
        this.stopAt = tsMs;
        this.stopPeak = this.peak;
      }
      this.boutStart = -1;
    }
    if (this.stopAt >= 0 && tsMs - this.stopAt >= RECOVERY_MS) {
      this.stopAt = -1;
      const drop = this.stopPeak - bpm;
      const r: HrRecoveryValues = {
        peakBpm: this.stopPeak,
        bpmAfter60s: bpm,
        dropBpm: drop,
        slow: drop < SLOW_DROP_BPM
      };
      return r;
    }
    return undefined;
  }
}
