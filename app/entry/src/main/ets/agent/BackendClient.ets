// HTTP to our Supabase Edge Functions (NetworkKit). Returns undefined on ANY failure so callers have one
// failure path. No secrets: only the public anon key; the OpenAI key lives in Edge Function secrets.

import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Config } from '../common/Config';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('Backend');

export class BackendClient {
  static available(): boolean {
    return Config.hasBackend();
  }

  // POST JSON, expect a JSON/text body. fn: Edge Function name, e.g. 'agent'.
  static async postJson(fn: string, body: string, timeoutMs: number): Promise<string | undefined> {
    const res: http.HttpResponse | undefined =
      await BackendClient.post(fn, body, timeoutMs, http.HttpDataType.STRING);
    return res !== undefined ? res.result as string : undefined;
  }

  // POST JSON, expect binary (e.g. PCM audio from /speak).
  static async postForBinary(fn: string, body: string, timeoutMs: number): Promise<ArrayBuffer | undefined> {
    const res: http.HttpResponse | undefined =
      await BackendClient.post(fn, body, timeoutMs, http.HttpDataType.ARRAY_BUFFER);
    return res !== undefined ? res.result as ArrayBuffer : undefined;
  }

  private static async post(fn: string, body: string, timeoutMs: number,
    expect: http.HttpDataType): Promise<http.HttpResponse | undefined> {
    if (!Config.hasBackend()) {
      return undefined;
    }
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${Config.SUPABASE_ANON_KEY}`,
      'apikey': Config.SUPABASE_ANON_KEY
    };
    const req: http.HttpRequest = http.createHttp();
    const started: number = Date.now();
    try {
      const res: http.HttpResponse = await req.request(`${Config.BACKEND_URL}/functions/v1/${fn}`, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: body,
        expectDataType: expect,
        connectTimeout: Math.min(timeoutMs, 10000),
        readTimeout: timeoutMs
      });
      if (res.responseCode !== 200) {
        log.warn(`${fn} HTTP ${res.responseCode} after ${Date.now() - started} ms`);
        return undefined;
      }
      return res;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      log.warn(`${fn} failed after ${Date.now() - started} ms: ${err.code} ${err.message}`);
      return undefined;
    } finally {
      req.destroy();
    }
  }
}
