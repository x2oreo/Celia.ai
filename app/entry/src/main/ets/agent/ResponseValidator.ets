// OWNER: Kaloyan - every byte from the model passes through here before the user sees it.
//   1. parseRelay: the /agent response must match the contract, otherwise → fallback.
//   2. parseArgs: tool arguments must be a JSON object, otherwise the tool returns an error to the model.
//   3. checkFinalText: the model's words must not contradict the deterministic verdicts of this turn.
// Pure functions only (no I/O) so they run in local unit tests.

import { VerdictCardPayload } from '../model/AgentTypes';
import { verdictText } from './VerdictText';
import { normalizeText } from '../common/Text';

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

// Reassurance about taking a medicine, English + Polish. Text is normalised first (lower case, ASCII apostrophes).
// Negated forms ("is not safe", "isn't fine to take", "nie jest bezpieczny") are ignored.
// Polish: \b is ASCII-only in JS regex, so Polish patterns avoid it next to non-ASCII letters.
const REASSURANCE: RegExp[] = [
  /\b(is|are|it's|its|be|perfectly|completely|totally|generally|should be)\s+(safe|fine|ok|okay|harmless)\b/g,
  /\b(safe|fine|ok|okay) (for you )?to (take|use)\b/g,
  /\bno (qt |real |known )?risk\b/g,
  /\bharmless\b/g,
  /\b(jest|są)\s+(całkowicie\s+|zupełnie\s+|w pełni\s+)?bezpieczn/g,
  /bezpieczn\S*\s+(dla ciebie|dla pana|dla pani|do (przyjęcia|stosowania|wzięcia))/g,
  /\bmożna\s+(go\s+|ją\s+|je\s+)?bezpiecznie/g,
  /\bbez (żadnego )?ryzyka/g,
  /\bnie ma (żadnego )?ryzyka/g
];

// The words right before a match negate it ("not safe", "nie jest bezpieczny").
const NEGATION: RegExp = /(not|n't|never|no longer|(^|\s)nie)\s*((jest|są)\s*)?$/;
// "That does not mean it is safe." - the match is inside a clause that denies it. Checked up to the sentence end.
const DENIAL: RegExp = /((not|n't)\s+(necessarily\s+)?(mean|means|guarantee|guarantees)|\bnie\s+(oznacza|znaczy|gwarantuje))\b[^.!?;]*$/;

const RISK_WORDS: RegExp =
  /\b(risk|risky|avoid|danger|dangerous|caution|careful|not recommended|check with)\b|ryzyk|unik|ostrożn|niebezpieczn|uważ/;
const ASK_WORDS: RegExp = /\b(pharmacist|doctor|cardiologist)\b|lekarz|farmaceut|kardiolog/;
const MEDICINE_WORDS: RegExp =
  /\b(medicine|medicines|medication|drug|drugs|tablet|tablets|pill|pills|take|taking)\b|\blek(i|u|ów|iem|ami)?(?![a-ząćęłńóśźż])|tabletk|wziąć|brać|przyjmowa|przyjąć/;

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

// True if the text talks about taking a medicine (English or Polish). Shared with the realtime streaming check.
export function mentionsMedicine(text: string): boolean {
  return MEDICINE_WORDS.test(normalizeText(text));
}

export function hasReassurance(text: string): boolean {
  const t: string = normalizeText(text);
  for (const pattern of REASSURANCE) {
    pattern.lastIndex = 0;
    let m: RegExpExecArray | null = pattern.exec(t);
    while (m !== null) {
      const before: string = t.slice(Math.max(0, m.index - 14), m.index);
      const clause: string = t.slice(Math.max(0, m.index - 80), m.index);
      if (!NEGATION.test(before) && !DENIAL.test(clause)) {
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
  // The model must never reassure about a medicine - not after a verdict, and not without one ("X is safe" from
  // its own knowledge). Reassurance about other things ("your heart rate is fine") is allowed.
  const lower: string = normalizeText(trimmed);
  const aboutMedicine: boolean = verdicts.length > 0 || mentionsMedicine(lower);
  if (aboutMedicine && hasReassurance(trimmed)) {
    const r: TextCheck = { issue: 'REASSURES_RISKY', text: replacement(verdicts) };
    return r;
  }
  for (const v of verdicts) {
    const downplayed: boolean =
      ((v.combinedRisk === 'KNOWN_RISK' || v.combinedRisk === 'POSSIBLE_RISK' || v.combinedRisk === 'CONDITIONAL_RISK') &&
        !RISK_WORDS.test(lower)) ||
        (v.combinedRisk === 'UNKNOWN_DRUG' && !ASK_WORDS.test(lower));
    if (downplayed) {
      const r: TextCheck = { issue: 'DOWNPLAYS_VERDICT', text: replacement(verdicts) };
      return r;
    }
  }
  const ok: TextCheck = { issue: 'NONE', text: trimmed };
  return ok;
}
