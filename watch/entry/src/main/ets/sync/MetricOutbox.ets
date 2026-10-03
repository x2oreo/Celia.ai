import { MetricRow, MetricType } from '../model/WatchMetric';

/** Where the outbox persists itself. Preferences on the watch, in-memory in tests. */
export interface OutboxStore {
  load(): string;

  save(json: string): void;
}

export class MemoryOutboxStore implements OutboxStore {
  private data: string = '';

  load(): string {
    return this.data;
  }

  save(json: string): void {
    this.data = json;
  }
}

/**
 * FIFO queue of metrics waiting for upload. Survives app restarts and offline periods.
 * When full, the oldest `hr_live` rows are dropped first: they are the least valuable.
 * Changes stay in memory until `flush()` (energy: one storage write per sync, every 3 s, instead of one per row).
 */
export class MetricOutbox {
  private rows: MetricRow[] = [];
  private store: OutboxStore;
  private capacity: number;
  private dirty: boolean = false;

  constructor(store: OutboxStore, capacity: number) {
    this.store = store;
    this.capacity = capacity;
    this.restore();
  }

  get size(): number {
    return this.rows.length;
  }

  enqueue(row: MetricRow): void {
    this.rows.push(row);
    while (this.rows.length > this.capacity) {
      const liveIdx = this.rows.findIndex((r: MetricRow) => r.type === 'hr_live');
      this.rows.splice(liveIdx >= 0 ? liveIdx : 0, 1);
    }
    this.dirty = true;
  }

  /** True while a row of this type is still waiting for upload. */
  has(type: MetricType): boolean {
    return this.rows.some((r: MetricRow) => r.type === type);
  }

  peek(max: number): MetricRow[] {
    return this.rows.slice(0, max);
  }

  /** Removes the first `count` rows after they were uploaded successfully. */
  ack(count: number): void {
    this.rows.splice(0, count);
    this.dirty = true;
  }

  /** Writes the queue to the store if it changed since the last write. True when it wrote. */
  flush(): boolean {
    if (!this.dirty) {
      return false;
    }
    this.store.save(JSON.stringify(this.rows));
    this.dirty = false;
    return true;
  }

  private restore(): void {
    const json = this.store.load();
    if (json.length === 0) {
      return;
    }
    try {
      const parsed = JSON.parse(json) as MetricRow[];
      if (Array.isArray(parsed)) {
        this.rows = parsed.slice(-this.capacity);
      }
    } catch (e) {
      this.rows = [];
    }
  }
}
