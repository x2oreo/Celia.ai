import { HrSessionValues } from '../model/WatchMetric';

/** Running avg/min/max of a monitoring session. Pure logic. */
export class SessionStats {
  private count: number = 0;
  private sum: number = 0;
  private min: number = Number.MAX_VALUE;
  private max: number = 0;
  private startMs: number = -1;
  private lastMs: number = -1;

  add(bpm: number, tsMs: number): void {
    if (this.startMs < 0) {
      this.startMs = tsMs;
    }
    this.lastMs = tsMs;
    this.count++;
    this.sum += bpm;
    this.min = Math.min(this.min, bpm);
    this.max = Math.max(this.max, bpm);
  }

  get samples(): number {
    return this.count;
  }

  get durationSec(): number {
    return this.startMs < 0 ? 0 : Math.round((this.lastMs - this.startMs) / 1000);
  }

  /** Undefined when nothing was recorded (no point uploading an empty session). */
  summary(): HrSessionValues | undefined {
    if (this.count === 0) {
      return undefined;
    }
    const s: HrSessionValues = {
      avgBpm: Math.round(this.sum / this.count),
      maxBpm: this.max,
      minBpm: this.min,
      durationSec: this.durationSec,
      samples: this.count
    };
    return s;
  }
}
