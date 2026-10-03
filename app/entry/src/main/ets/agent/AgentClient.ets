// HTTP client for the /agent Edge Function (NetworkKit). Returns undefined on ANY failure — network down,
// timeout, non-200, malformed body — so AgentCore has exactly one failure path: the deterministic fallback.

import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Config } from '../common/Config';
import { Logger } from '../common/Logger';
import { RelayResponse, parseRelay } from './ResponseValidator';

const log: Logger = new Logger('AgentClient');

export interface RelayContext {
  condition: string;
  genotype: string;
  meds: string[];
  vitals: string;
  emergencyNumber: string;
  locale: string;
}

export interface RelayMessage {
  role: string;
  text: string;
}

export interface RelayToolOutput {
  callId: string;
  output: string;
}

export interface RelayContinuation {
  previousResponseId: string;
  toolOutputs: RelayToolOutput[];
}

export interface RelayRequest {
  context: RelayContext;
  messages: RelayMessage[];
  continuation: RelayContinuation | null;
}

export class AgentClient {
  // Debug switch for the demo: replace the model's reply with garbage to show the validator + fallback.
  static forceGarbage: boolean = false;

  async step(body: RelayRequest, timeoutMs: number): Promise<RelayResponse | undefined> {
    if (!Config.hasBackend()) {
      return undefined;
    }
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${Config.SUPABASE_ANON_KEY}`,
      'apikey': Config.SUPABASE_ANON_KEY
    };
    const req: http.HttpRequest = http.createHttp();
    try {
      const res: http.HttpResponse = await req.request(`${Config.BACKEND_URL}/functions/v1/agent`, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: JSON.stringify(body),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: Math.min(timeoutMs, 10000),
        readTimeout: timeoutMs
      });
      if (res.responseCode !== 200) {
        log.warn(`agent HTTP ${res.responseCode}`);
        return undefined;
      }
      const text: string = AgentClient.forceGarbage ? '{"oops": <<not json>>' : res.result as string;
      const parsed: RelayResponse | undefined = parseRelay(text);
      if (parsed === undefined) {
        log.warn('agent response failed schema validation');
      }
      return parsed;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      log.warn(`agent request failed: ${err.code} ${err.message}`);
      return undefined;
    } finally {
      req.destroy();
    }
  }
}
