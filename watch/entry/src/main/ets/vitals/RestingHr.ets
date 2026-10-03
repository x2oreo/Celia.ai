import { Activity } from '../model/WatchMetric';

const WINDOW_MS = 60000;
const KEEP_MS = 24 * 3600 * 1000;

interface MinuteAvg {
  ts: number;
  avg: number;
}

/**
 * Resting heart rate = lowest stable (1-minute average) HR while at rest or asleep, over the last 24 h.
 * Starts from `initialBpm` until the first full minute at rest.
 */
export class RestingHr {
  private minutes: MinuteAvg[] = [];
  private windowStart: number = -1;
  private sum: number = 0;
  private count: number = 0;
  private initial: number;

  constructor(initialBpm: number) {
    this.initial = initialBpm;
  }

  get value(): number {
    if (this.minutes.length === 0) {
      return this.initial;
    }
    let min = Number.MAX_VALUE;
    for (const m of this.minutes) {
      min = Math.min(min, m.avg);
    }
    return Math.round(min);
  }

  /** True once at least one real resting minute was measured (otherwise `value` is the initial estimate). */
  get measured(): boolean {
    return this.minutes.length > 0;
  }

  add(bpm: number, tsMs: number, activity: Activity): void {
    if (activity !== 'REST' && activity !== 'ASLEEP') {
      this.windowStart = -1;
      return;
    }
    if (this.windowStart < 0) {
      this.windowStart = tsMs;
      this.sum = 0;
      this.count = 0;
    }
    this.sum += bpm;
    this.count++;
    if (tsMs - this.windowStart >= WINDOW_MS) {
      this.minutes.push({ ts: tsMs, avg: this.sum / this.count });
      this.windowStart = -1;
      while (this.minutes.length > 0 && tsMs - this.minutes[0].ts > KEEP_MS) {
        this.minutes.shift();
      }
    }
  }
}
