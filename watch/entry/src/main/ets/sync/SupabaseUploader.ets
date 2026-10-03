import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { MetricRow } from '../model/WatchMetric';
import { Logger } from '../common/Logger';

export interface UploadResult {
  ok: boolean;
  message: string;
}

function result(ok: boolean, message: string): UploadResult {
  const r: UploadResult = { ok: ok, message: message };
  return r;
}

/** Inserts metric rows into Supabase via PostgREST (`POST /rest/v1/watch_metrics`). */
export class SupabaseUploader {
  private url: string;
  private anonKey: string;

  constructor(supabaseUrl: string, anonKey: string) {
    this.url = `${supabaseUrl}/rest/v1/watch_metrics`;
    this.anonKey = anonKey;
  }

  async upload(rows: MetricRow[]): Promise<UploadResult> {
    if (rows.length === 0) {
      return result(true, 'nothing to send');
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
        return result(true, `sent ${rows.length}`);
      }
      Logger.warn(`upload HTTP ${resp.responseCode}: ${String(resp.result).slice(0, 200)}`);
      return result(false, `HTTP ${resp.responseCode}`);
    } catch (e) {
      const err = e as BusinessError;
      return result(false, `network ${err.code}`);
    } finally {
      req.destroy();
    }
  }
}
