import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { MetricRow } from '../model/WatchMetric';
import { Logger } from '../common/Logger';

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
  private url: string;
  private anonKey: string;

  constructor(supabaseUrl: string, anonKey: string) {
    this.url = `${supabaseUrl}/rest/v1/watch_metrics`;
    this.anonKey = anonKey;
  }

  async upload(rows: MetricRow[]): Promise<UploadResult> {
    if (rows.length === 0) {
      return result(true, 200, 'nothing to send');
    }
    const req = http.createHttp();
    try {
      const resp = await req.request(this.url, {
        method: http.RequestMethod.POST,
        header: {
          'apikey': this.anonKey,
          'Authorization': `Bearer ${this.anonKey}`,
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal'
        },
        extraData: JSON.stringify(rows),
        connectTimeout: 5000,
        readTimeout: 5000,
        expectDataType: http.HttpDataType.STRING
      });
      if (resp.responseCode >= 200 && resp.responseCode < 300) {
        return result(true, resp.responseCode, `sent ${rows.length}`);
      }
      Logger.warn(`upload HTTP ${resp.responseCode}: ${String(resp.result).slice(0, 200)}`);
      return result(false, resp.responseCode, `HTTP ${resp.responseCode}`);
    } catch (e) {
      const err = e as BusinessError;
      return result(false, 0, `network ${err.code}`);
    } finally {
      req.destroy();
    }
  }
}
