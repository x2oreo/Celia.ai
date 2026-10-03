import { Logger } from '../common/Logger';
import { MetricRow, MetricType } from '../model/WatchMetric';
import { MemoryOutboxStore, MetricOutbox } from '../sync/MetricOutbox';
import { MetricUploader, UploadResult } from '../sync/SupabaseUploader';

export type SyncState = 'OFF' | 'OK' | 'PENDING' | 'ERROR';

const BATCH = 50;
/** Rows kept while offline; the oldest `hr_live` rows go first when it is full. */
export const OUTBOX_CAPACITY = 500;

/**
 * Outbox → uploader. Rows are queued as they are recorded and sent in batches of 50; a batch the server rejects
 * (HTTP 400) is retried one row at a time so a single bad row is dropped instead of blocking the queue.
 */
@ObservedV2
export class SyncEngine {
  @Trace syncState: SyncState = 'OFF';
  @Trace pending: number = 0;

  private outbox: MetricOutbox = new MetricOutbox(new MemoryOutboxStore(), OUTBOX_CAPACITY);
  private uploader: MetricUploader | undefined = undefined;
  private syncing: boolean = false;
  private batchSize: number = BATCH;

  /**
   * No outbox = keep the in-memory one (persistent storage unavailable). No uploader = Supabase not configured:
   * rows stay queued and the state stays OFF.
   */
  configure(outbox: MetricOutbox | undefined, uploader: MetricUploader | undefined): void {
    if (outbox !== undefined) {
      this.outbox = outbox;
    }
    this.uploader = uploader;
    this.pending = this.outbox.size;
    if (uploader !== undefined) {
      this.syncState = this.pending > 0 ? 'PENDING' : 'OK';
    }
  }

  record(row: MetricRow): void {
    this.outbox.enqueue(row);
    this.pending = this.outbox.size;
    if (this.uploader !== undefined) {
      this.syncState = 'PENDING';
    }
  }

  /** True while a row of this type is still waiting for upload. */
  has(type: MetricType): boolean {
    return this.outbox.has(type);
  }

  /** Sends one batch. True when rows were uploaded (not when nothing was sent or the upload failed). */
  async syncNow(): Promise<boolean> {
    if (this.uploader === undefined || this.syncing || this.outbox.size === 0) {
      return false;
    }
    this.syncing = true;
    const batch = this.outbox.peek(this.batchSize);
    const res: UploadResult = await this.uploader.upload(batch);
    if (res.ok) {
      this.outbox.ack(batch.length);
      this.batchSize = BATCH;
      this.syncState = this.outbox.size > 0 ? 'PENDING' : 'OK';
    } else if (res.status === 400) {
      // The server rejected a row (e.g. a type the DB doesn't know yet). Find it by sending one at a time and drop
      // only that row, so one bad row can't block the queue forever.
      if (this.batchSize > 1) {
        this.batchSize = 1;
      } else {
        Logger.error(`dropping row rejected by server: type=${batch[0].type}`);
        this.outbox.ack(1);
      }
      this.syncState = this.outbox.size > 0 ? 'PENDING' : 'OK';
    } else {
      this.syncState = 'ERROR';
      Logger.warn(`sync failed: ${res.message}`);
    }
    this.pending = this.outbox.size;
    this.syncing = false;
    return res.ok;
  }
}
