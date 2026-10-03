import { MetricRow } from '../model/WatchMetric';
import { Logger } from '../common/Logger';
import { RestClient } from './RestClient';

export interface UploadResult {
  ok: boolean;
  /** HTTP status, 0 for network errors. 400 means the server rejected the rows themselves. */
  status: number;
  message: string;
}

function result(ok: boolean, status: number, message: string): UploadResult {
  const r: UploadResult = { ok: ok, status: status, message: message };
  return r;
}

/** Sends a batch of metric rows; `SupabaseUploader` on the watch, a fake in tests. */
export interface MetricUploader {
  upload(rows: MetricRow[]): Promise<UploadResult>;
}

/** Inserts metric rows into Supabase via PostgREST (`POST /rest/v1/watch_metrics`). */
export class SupabaseUploader implements MetricUploader {
  private client: RestClient;

  constructor(client: RestClient) {
    this.client = client;
  }

  async upload(rows: MetricRow[]): Promise<UploadResult> {
    if (rows.length === 0) {
      return result(true, 200, 'nothing to send');
    }
    const resp = await this.client.post('/rest/v1/watch_metrics', JSON.stringify(rows), 'return=minimal');
    if (resp.status === 0) {
      return result(false, 0, `network ${resp.body}`);
    }
    if (resp.status >= 200 && resp.status < 300) {
      return result(true, resp.status, `sent ${rows.length}`);
    }
    Logger.warn(`upload HTTP ${resp.status}: ${resp.body.slice(0, 200)}`);
    return result(false, resp.status, `HTTP ${resp.status}`);
  }
}
