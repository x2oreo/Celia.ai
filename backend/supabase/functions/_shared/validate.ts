// Request validation for /agent. Anything unexpected is rejected with 400 — the app then uses its fallback.

import { AgentContext } from './prompt.ts';

export interface TurnMessage {
  role: 'user' | 'assistant';
  text: string;
}

export interface ToolOutput {
  callId: string;
  output: string; // JSON string produced by the on-device executor
}

export interface AgentRequest {
  context: AgentContext;
  messages: TurnMessage[];
  continuation: { previousResponseId: string; toolOutputs: ToolOutput[] } | null;
}

const MAX_MESSAGES = 30;
const MAX_TEXT = 4000;
const MAX_TOOL_OUTPUT = 8000;
const GENOTYPES = ['LQT1', 'LQT2', 'LQT3', 'UNKNOWN'];

function isObj(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

function str(v: unknown, field: string, max: number): string {
  if (typeof v !== 'string') throw new Error(`${field} must be a string`);
  if (v.length > max) throw new Error(`${field} too long`);
  return v;
}

export function parseContext(c: unknown): AgentContext {
  if (!isObj(c)) throw new Error('context must be an object');
  const genotype = str(c.genotype, 'context.genotype', 16);
  if (!GENOTYPES.includes(genotype)) throw new Error('context.genotype invalid');
  if (!Array.isArray(c.meds) || c.meds.length > 50) throw new Error('context.meds must be an array (<=50)');
  const context: AgentContext = {
    condition: str(c.condition, 'context.condition', 32),
    genotype,
    meds: c.meds.map((m, i) => str(m, `context.meds[${i}]`, 80)),
    vitals: str(c.vitals, 'context.vitals', 300),
    emergencyNumber: str(c.emergencyNumber, 'context.emergencyNumber', 8),
    locale: str(c.locale, 'context.locale', 16),
  };
  return context;
}

export function parseAgentRequest(raw: unknown): AgentRequest {
  if (!isObj(raw)) throw new Error('body must be an object');
  const context = parseContext(raw.context);

  if (!Array.isArray(raw.messages) || raw.messages.length > MAX_MESSAGES) {
    throw new Error(`messages must be an array (<=${MAX_MESSAGES})`);
  }
  const messages: TurnMessage[] = raw.messages.map((m, i) => {
    if (!isObj(m) || (m.role !== 'user' && m.role !== 'assistant')) throw new Error(`messages[${i}] invalid`);
    return { role: m.role, text: str(m.text, `messages[${i}].text`, MAX_TEXT) };
  });

  let continuation: AgentRequest['continuation'] = null;
  if (raw.continuation !== undefined && raw.continuation !== null) {
    const k = raw.continuation;
    if (!isObj(k) || !Array.isArray(k.toolOutputs) || k.toolOutputs.length === 0 || k.toolOutputs.length > 8) {
      throw new Error('continuation invalid');
    }
    continuation = {
      previousResponseId: str(k.previousResponseId, 'continuation.previousResponseId', 128),
      toolOutputs: k.toolOutputs.map((o, i) => {
        if (!isObj(o)) throw new Error(`toolOutputs[${i}] invalid`);
        return {
          callId: str(o.callId, `toolOutputs[${i}].callId`, 128),
          output: str(o.output, `toolOutputs[${i}].output`, MAX_TOOL_OUTPUT),
        };
      }),
    };
  } else if (messages.length === 0 || messages[messages.length - 1].role !== 'user') {
    throw new Error('last message must be from the user');
  }

  return { context, messages, continuation };
}
