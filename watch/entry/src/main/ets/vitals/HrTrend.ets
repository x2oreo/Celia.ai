/**
 * The last minutes of heart rate for the watch's trend page: fixed time buckets with the lowest, highest and average
 * reading. Pure and unit-tested. Bucketed on the controller's logic clock, so a sped-up demo fills the chart at the
 * same pace as its rules. Never a trace: one range mark per bucket.
 */

export const TREND_BUCKET_MS: number = 30 * 1000;
export const TREND_BUCKETS: number = 20;

export class HrBucket {
  /** Start of the bucket on the logic clock. */
  startMs: number = 0;
  min: number = 0;
  max: number = 0;
  sum: number = 0;
  count: number = 0;

  avg(): number {
    return this.count > 0 ? Math.round(this.sum / this.count) : 0;
  }
}

export interface TrendSummary {
  min: number;
  max: number;
  avg: number;
  /** Buckets with at least one reading. */
  filled: number;
}

export class HrTrend {
  private buckets: HrBucket[] = [];

  /** Adds one reading; returns true when a new bucket was opened. */
  add(bpm: number, logicMs: number): boolean {
    if (bpm <= 0) {
      return false;
    }
    const start = Math.floor(logicMs / TREND_BUCKET_MS) * TREND_BUCKET_MS;
    let last = this.buckets.length > 0 ? this.buckets[this.buckets.length - 1] : undefined;
    if (last !== undefined && start < last.startMs) {
      // The clock went back (a new demo scenario restarts its clock): start over.
      this.buckets = [];
      last = undefined;
    }
    if (last !== undefined && last.startMs === start) {
      last.min = Math.min(last.min, bpm);
      last.max = Math.max(last.max, bpm);
      last.sum += bpm;
      last.count += 1;
      return false;
    }
    const b = new HrBucket();
    b.startMs = start;
    b.min = bpm;
    b.max = bpm;
    b.sum = bpm;
    b.count = 1;
    this.buckets.push(b);
    // Drop everything older than the window (also after a gap, e.g. the watch was off the wrist).
    const oldest = start - (TREND_BUCKETS - 1) * TREND_BUCKET_MS;
    this.buckets = this.buckets.filter((x: HrBucket) => x.startMs >= oldest);
    return true;
  }

  clear(): void {
    this.buckets = [];
  }

  /**
   * Exactly TREND_BUCKETS slots ending at the newest bucket, oldest first; empty slots have count 0 so a gap stays a
   * gap and is never bridged.
   */
  slots(): HrBucket[] {
    const out: HrBucket[] = [];
    if (this.buckets.length === 0) {
      return out;
    }
    const newest = this.buckets[this.buckets.length - 1].startMs;
    for (let i = TREND_BUCKETS - 1; i >= 0; i--) {
      const start = newest - i * TREND_BUCKET_MS;
      const found = this.buckets.find((x: HrBucket) => x.startMs === start);
      if (found !== undefined) {
        out.push(found);
      } else {
        const empty = new HrBucket();
        empty.startMs = start;
        out.push(empty);
      }
    }
    return out;
  }

  summary(): TrendSummary {
    let min = 0;
    let max = 0;
    let sum = 0;
    let count = 0;
    let filled = 0;
    for (const b of this.buckets) {
      if (b.count === 0) {
        continue;
      }
      min = filled === 0 ? b.min : Math.min(min, b.min);
      max = Math.max(max, b.max);
      sum += b.sum;
      count += b.count;
      filled += 1;
    }
    const s: TrendSummary = { min: min, max: max, avg: count > 0 ? Math.round(sum / count) : 0, filled: filled };
    return s;
  }
}

/** Chart scale: the readings and both limits fit, padded to a multiple of 10. */
export interface TrendScale {
  lo: number;
  hi: number;
}

export function trendScale(slots: HrBucket[], limitLow: number, limitHigh: number): TrendScale {
  let lo = limitLow;
  let hi = limitHigh;
  for (const b of slots) {
    if (b.count > 0) {
      lo = Math.min(lo, b.min);
      hi = Math.max(hi, b.max);
    }
  }
  const s: TrendScale = { lo: Math.floor((lo - 5) / 10) * 10, hi: Math.ceil((hi + 5) / 10) * 10 };
  return s;
}

/** 0 at the bottom of the plot, 1 at the top. */
export function trendY(bpm: number, scale: TrendScale): number {
  const span = scale.hi - scale.lo;
  if (span <= 0) {
    return 0;
  }
  return Math.max(0, Math.min(1, (bpm - scale.lo) / span));
}
