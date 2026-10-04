// The agent conversation as a pure function of the frame, shared by the Ask and Verdict scenes and the vertical
// cut. Orb states follow DESIGN §6.6a, the stage §10.1a (02 → 03). Ola's and the agent's lines are the real voice
// lines (vo.json), so captions and the orb follow the audio.
import { interpolate } from 'remotion';
import { voFrames, voLevel, voWordCount, voWords } from '../audio/vo';
import { chat } from '../copy/script';
import { clampOpts, easeInOut, progress, reveal, sheet } from '../theme/motion';
import type { OrbPhase } from '../ui/SilkOrb';

export interface Timeline {
  listen: number; // the orb is tapped: Connecting, then Listening
  hear: number; // Ola starts speaking (ask_user)
  toolDone: number; // tool step finished
  speak: number; // the agent starts speaking (ask_agent)
  verdict: number; // verdict card slides in under the captions
  sheet: number; // "Details" opens the full verdict sheet (hero only)
  traceStart: number;
  traceEnd: number;
}

const USER = voFrames('ask_user');
const AGENT = voFrames('ask_agent');

const timeline = (listen: number, hear: number, think: number, verdictLead: number, sheetAt: number): Timeline => {
  const speak = hear + USER + think;
  return {
    listen,
    hear,
    toolDone: speak - 10,
    speak,
    verdict: speak + AGENT - verdictLead,
    sheet: sheetAt,
    traceStart: sheetAt + 40,
    traceEnd: sheetAt + 90,
  };
};

// Hero: Ask scene (420) then the Verdict scene continues the same clock from 405.
export const heroTimeline = timeline(16, 34, 52, 24, 430);
// Vertical: quicker think, the card lands while the last words are spoken; no sheet.
export const tallTimeline = timeline(8, 16, 30, 40, 100000);

export const heard = (t: Timeline): number => t.hear + USER;
export const spoken = (t: Timeline): number => t.speak + AGENT;

export interface ConversationState {
  frame: number;
  started: boolean; // header shows VOICE · m:ss
  elapsed: number; // seconds since the session started
  phaseAt: (f: number) => OrbPhase;
  levelAt: (f: number) => number;
  phase: OrbPhase;
  level: number;
  label: string;
  intro: number; // 1 → 0: the empty stage content fades out
  waiting: number; // 0..1 "I'm listening" stands alone before the first words
  user: { visible: number; words: number } | null;
  tool: { visible: number; done: boolean } | null;
  agent: { words: number; total: number } | null;
  verdict: { opacity: number; y: number; badge: number } | null;
  details: { y: number; scrim: number; badge: number; traceOpen: number } | null;
  scrollY: number;
}

export const phaseAt = (t: Timeline) => (f: number): OrbPhase => {
  if (f < t.listen) return 'OFF';
  if (f < t.listen + 10) return 'CONNECTING';
  if (f < t.hear) return 'LISTENING';
  if (f < heard(t) + 4) return 'HEARING';
  if (f < t.speak) return 'THINKING';
  if (f < spoken(t) + 6) return 'SPEAKING';
  return 'LISTENING';
};

export const levelAt = (t: Timeline) => (f: number): number => {
  if (f >= t.hear && f < heard(t)) return voLevel('ask_user', f - t.hear);
  if (f >= t.speak && f < spoken(t)) return voLevel('ask_agent', f - t.speak);
  return f >= t.listen ? 0.2 : 0;
};

const labelFor = (phase: OrbPhase): string => {
  switch (phase) {
    case 'OFF':
      return chat.orbLabels.off;
    case 'CONNECTING':
      return 'Connecting…';
    case 'HEARING':
      return chat.orbLabels.hearing;
    case 'THINKING':
      return chat.orbLabels.thinking;
    case 'SPEAKING':
      return chat.orbLabels.speaking;
    default:
      return chat.orbLabels.listening;
  }
};

export const conversationAt = (f: number, t: Timeline): ConversationState => {
  const pa = phaseAt(t);
  const la = levelAt(t);
  const phase = pa(f);
  const r = reveal(f, t.verdict);
  const sh = sheet(f, t.sheet);
  const sb = reveal(f, t.sheet + 6);
  // Keep the newest content clear of the floating dock (tuned against rendered stills).
  const scrollY = interpolate(f, [t.verdict - 6, t.verdict + 14], [0, 64], { ...clampOpts, easing: easeInOut });
  return {
    frame: f,
    started: f >= t.listen,
    elapsed: Math.max(0, (f - t.listen) / 30),
    phaseAt: pa,
    levelAt: la,
    phase,
    level: la(f),
    label: labelFor(phase),
    intro: 1 - progress(f, t.listen, 12),
    waiting: progress(f, t.listen + 4, 10) * (1 - progress(f, t.hear, 8)),
    user: f >= t.hear ? { visible: progress(f, t.hear, 8), words: voWords('ask_user', f - t.hear) } : null,
    tool: f >= heard(t) + 6 ? { visible: progress(f, heard(t) + 6, 8), done: f >= t.toolDone } : null,
    agent: f >= t.speak ? { words: voWords('ask_agent', f - t.speak), total: voWordCount('ask_agent') } : null,
    verdict: f >= t.verdict ? { opacity: r.opacity, y: r.y, badge: r.badge } : null,
    details:
      f >= t.sheet
        ? { y: sh.y, scrim: sh.scrim, badge: sb.badge, traceOpen: interpolate(f, [t.traceStart, t.traceEnd], [0, 1], clampOpts) }
        : null,
    scrollY,
  };
};
