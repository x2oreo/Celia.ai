// OWNER: Kaloyan - emergency pre-filter. Runs on every user utterance (typed, speech-to-text, realtime transcript)
// BEFORE any model call. A match starts the deterministic emergency flow; the LLM is never on that path.
// Patterns are deliberately broad: a false alarm costs one tap on "Cancel", a miss can cost a life.

import { normalizeText } from '../common/Text';

export type GateResult = 'EMERGENCY' | 'UNWELL' | 'OK' | 'NONE';

// Red flags for LQTS (lqts-domain skill → Emergency facts). English + Polish.
const EMERGENCY_PATTERNS: RegExp[] = [
  /\bfaint(ed|ing)?\b/,
  /\bpass(ed|ing)? out\b/,
  /\bblack(ed|ing)? out\b/,
  /\blost consciousness\b/,
  /\bcollaps(e|ed|ing)\b/,
  /\bchest pain\b/,
  /\bpain in my chest\b/,
  /\b(can'?t|cannot|can not) breathe\b/,
  /\btrouble breathing\b/,
  /\bseizure|\bconvuls/,
  /\bheart (is )?(racing|pounding)\b.*\bdizz/,
  /\bdizz(y|iness)\b.*\b(heart|palpitation|racing)\b/,
  /\bpalpitations?\b.*\bdizz/,
  /\bcall (an )?(ambulance|112|911|999)\b/,
  /\b(i need help|please help|help,? i)\b/,
  /\b(sos|it'?s an emergency|this is an emergency|medical emergency)\b/,
  // Polish: \b is ASCII-only in JS regex, so match on plain substrings.
  /zemdla|omdla|ból w klatce|nie mogę oddychać|wezwij pogotowie|ratunku/
];

// Only meaningful as an answer to a proactive check-in ("Are you OK?").
const UNWELL_PATTERNS: RegExp[] = [
  /\b(not|don'?t feel) (ok|okay|good|well|great)\b/,
  /\bunwell\b/,
  /\bdizz(y|iness)\b/,
  /\bpalpitation/,
  /\bweak\b/,
  /\bsick\b/,
  /źle|słabo/
];

const OK_PATTERNS: RegExp[] = [
  /^\s*(i'?m |i am )?(ok|okay|fine|good|alright|all right)\b/,
  /\bfalse alarm\b/,
  /\bi was (exercising|running|working out|at the gym)\b/,
  /^\s*(wszystko )?(ok|dobrze)\b/
];

function matchesAny(text: string, patterns: RegExp[]): boolean {
  for (const p of patterns) {
    if (p.test(text)) {
      return true;
    }
  }
  return false;
}

export class SafetyGate {
  // checkInPending: true while a proactive "Are you OK?" is waiting for an answer.
  static classify(text: string, checkInPending: boolean): GateResult {
    const t: string = normalizeText(text);
    if (matchesAny(t, EMERGENCY_PATTERNS)) {
      return 'EMERGENCY';
    }
    if (checkInPending) {
      if (matchesAny(t, UNWELL_PATTERNS)) {
        return 'UNWELL';
      }
      if (matchesAny(t, OK_PATTERNS)) {
        return 'OK';
      }
    }
    return 'NONE';
  }
}
