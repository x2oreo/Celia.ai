// OWNER: Kaloyan — every byte from the model passes through here before the user sees it.
//   1. parseRelay: the /agent response must match the contract, otherwise → fallback.
//   2. parseArgs: tool arguments must be a JSON object, otherwise the tool returns an error to the model.
//   3. checkFinalText: the model's words must not contradict the deterministic verdicts of this turn.
// Pure functions only (no I/O) so they run in local unit tests.

import { VerdictCardPayload } from '../model/AgentTypes';
import { verdictText } from './VerdictText';

export interface RelayToolCall {
  callId: string;
  name: string;
  arguments: string;
}

export interface RelayResponse {
  promptVersion: string;
  responseId: string;
  toolCalls: RelayToolCall[];
  text: string;
}

export type TextIssue = 'NONE' | 'EMPTY' | 'REASSURES_RISKY' | 'DOWNPLAYS_VERDICT';

export interface TextCheck {
  issue: TextIssue;
  text: string;        // text to show: the model's (trimmed) or the deterministic replacement
}

const MAX_TEXT: number = 1500;

// Reassurance about taking a medicine. Negated forms ("is not safe", "isn't fine to take") are ignored.
const REASSURANCE: RegExp[] = [
  /\b(is|are|it's|its|be|perfectly|completely|totally|generally|should be)\s+(safe|fine|ok|okay|harmless)\b/g,
  /\b(safe|fine|ok|okay) (for you )?to (take|use)\b/g,
  /\bno (qt |real |known )?risk\b/g,
  /\bharmless\b/g
];

const NEGATION: RegExp = /(not|n't|never|no longer)\s*$/;

const RISK_WORDS: RegExp = /\b(risk|risky|avoid|danger|dangerous|caution|careful|not recommended|check with)\b/;
const ASK_WORDS: RegExp = /\b(pharmacist|doctor|cardiologist)\b/;
const MEDICINE_WORDS: RegExp = /\b(medicine|medicines|medication|drug|drugs|tablet|tablets|pill|pills|take|taking)\b/;

function isObj(v: Object | null | undefined): boolean {
  return v !== null && v !== undefined && typeof v === 'object' && !Array.isArray(v);
}

export function parseRelay(body: string): RelayResponse | undefined {
  let raw: Record<string, Object>;
  try {
    raw = JSON.parse(body) as Record<string, Object>;
  } catch (e) {
    return undefined;
  }
  if (!isObj(raw) || typeof raw['responseId'] !== 'string' || typeof raw['text'] !== 'string' ||
    !Array.isArray(raw['toolCalls'])) {
    return undefined;
  }
  const calls: RelayToolCall[] = [];
  for (const item of raw['toolCalls'] as Object[]) {
    const c: Record<string, Object> = item as Record<string, Object>;
    if (!isObj(item) || typeof c['callId'] !== 'string' || typeof c['name'] !== 'string' ||
      typeof c['arguments'] !== 'string') {
      return undefined;
    }
    const call: RelayToolCall = {
      callId: c['callId'] as string,
      name: c['name'] as string,
      arguments: c['arguments'] as string
    };
    calls.push(call);
  }
  const res: RelayResponse = {
    promptVersion: typeof raw['promptVersion'] === 'string' ? raw['promptVersion'] as string : '',
    responseId: raw['responseId'] as string,
    toolCalls: calls,
    text: raw['text'] as string
  };
  return res;
}

// Returns the parsed object, or undefined if the arguments are not a JSON object.
export function parseArgs(json: string): Record<string, Object> | undefined {
  try {
    const v: Object = JSON.parse(json) as Object;
    return isObj(v) ? v as Record<string, Object> : undefined;
  } catch (e) {
    return undefined;
  }
}

export function argString(args: Record<string, Object>, key: string, maxLen: number): string {
  const v: Object | undefined = args[key];
  if (typeof v !== 'string') {
    return '';
  }
  return (v as string).trim().slice(0, maxLen);
}

export function hasReassurance(text: string): boolean {
  const t: string = text.toLowerCase();
  for (const pattern of REASSURANCE) {
    pattern.lastIndex = 0;
    let m: RegExpExecArray | null = pattern.exec(t);
    while (m !== null) {
      const before: string = t.slice(Math.max(0, m.index - 14), m.index);
      if (!NEGATION.test(before)) {
        return true;
      }
      m = pattern.exec(t);
    }
  }
  return false;
}

function replacement(verdicts: VerdictCardPayload[]): string {
  if (verdicts.length === 0) {
    return 'I can only judge a medicine after checking it against my list. Tell me its name, or show me the box. ' +
      'Please confirm with your doctor or pharmacist.';
  }
  return verdicts.map((v: VerdictCardPayload) => verdictText(v)).join(' ');
}

// verdicts: deterministic verdicts produced by check_drug during this turn.
export function checkFinalText(text: string, verdicts: VerdictCardPayload[]): TextCheck {
  const trimmed: string = text.trim().slice(0, MAX_TEXT);
  if (trimmed.length === 0) {
    const r: TextCheck = { issue: 'EMPTY', text: replacement(verdicts) };
    return r;
  }
  // The model must never reassure about a medicine — not after a verdict, and not without one ("X is safe" from
  // its own knowledge). Reassurance about other things ("your heart rate is fine") is allowed.
  const aboutMedicine: boolean = verdicts.length > 0 || MEDICINE_WORDS.test(trimmed.toLowerCase());
  if (aboutMedicine && hasReassurance(trimmed)) {
    const r: TextCheck = { issue: 'REASSURES_RISKY', text: replacement(verdicts) };
    return r;
  }
  const lower: string = trimmed.toLowerCase();
  for (const v of verdicts) {
    const downplayed: boolean =
      ((v.combinedRisk === 'KNOWN_RISK' || v.combinedRisk === 'POSSIBLE_RISK') && !RISK_WORDS.test(lower)) ||
        (v.combinedRisk === 'UNKNOWN_DRUG' && !ASK_WORDS.test(lower));
    if (downplayed) {
      const r: TextCheck = { issue: 'DOWNPLAYS_VERDICT', text: replacement(verdicts) };
      return r;
    }
  }
  const ok: TextCheck = { issue: 'NONE', text: trimmed };
  return ok;
}
