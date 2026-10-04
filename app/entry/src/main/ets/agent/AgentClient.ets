// Client for the /agent Edge Function. Returns undefined on ANY failure - network down,
// timeout, non-200, malformed body - so AgentCore has exactly one failure path: the deterministic fallback.

import { Logger } from '../common/Logger';
import { BackendClient } from './BackendClient';
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
    const raw: string | undefined = await BackendClient.postJson('agent', JSON.stringify(body), timeoutMs);
    if (raw === undefined) {
      return undefined;
    }
    const parsed: RelayResponse | undefined = parseRelay(AgentClient.forceGarbage ? '{"oops": <<not json>>' : raw);
    if (parsed === undefined) {
      log.warn('agent response failed schema validation');
    }
    return parsed;
  }
}
