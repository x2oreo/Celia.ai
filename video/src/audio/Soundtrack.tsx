// The film's sound: the score (one file per cut), the narrator, Ola's and the agent's voices on the conversation
// clock, and interface sounds on the scene frames that cause them. Music ducks −12 dB under every voice.
import React from 'react';
import { Audio, Sequence, interpolate, staticFile } from 'remotion';
import type { SceneId } from '../copy/script';
import { heroTimeline, tallTimeline, type Timeline } from '../scenes/conversation';
import { emergencyTimes } from '../scenes/Emergency';
import { SCAN } from '../scenes/Scan';
import { TRUST_ROWS } from '../scenes/Trust';
import { watchTimes } from '../scenes/WatchGuard';
import { clampOpts } from '../theme/motion';
import { heroVo, vertVo, type VoCue } from './cues';
import { voFrames, type VoId } from './vo';

export type Sfx =
  | 'tap'
  | 'orb_on'
  | 'tool_done'
  | 'card_in'
  | 'sheet'
  | 'whoosh'
  | 'scan_lock'
  | 'haptic'
  | 'watch_alert'
  | 'sos_tick'
  | 'chime'
  | 'ledger_tick';

interface SfxCue {
  sfx: Sfx;
  at: number;
  gain: number;
}

interface Placed {
  id: SceneId;
  from: number;
  frames: number;
}

const DUCK = Math.pow(10, -12 / 20);
const MUSIC = 0.42;
const VOICE = 1.0;

const conversationSfx = (t: Timeline, offset: number, sheet: boolean): SfxCue[] => [
  { sfx: 'tap', at: t.listen - 2 - offset, gain: 0.35 },
  { sfx: 'orb_on', at: t.listen - offset, gain: 0.4 },
  { sfx: 'tool_done', at: t.toolDone - offset, gain: 0.35 },
  { sfx: 'card_in', at: t.verdict - offset, gain: 0.45 },
  ...(sheet ? [{ sfx: 'tap' as const, at: t.sheet - 3 - offset, gain: 0.3 }, { sfx: 'sheet' as const, at: t.sheet - offset, gain: 0.35 }] : []),
];

/** Interface sounds per scene, in scene frames. */
const sfxFor = (id: SceneId, fast: boolean, askFrames: number, xfade: number): SfxCue[] => {
  switch (id) {
    case 'ask':
      return conversationSfx(fast ? tallTimeline : heroTimeline, 0, false).filter((c) => c.at < askFrames);
    case 'verdict':
      return conversationSfx(heroTimeline, askFrames - xfade, true).filter((c) => c.at >= 0);
    case 'scan':
      return [
        { sfx: 'whoosh', at: 0, gain: 0.18 },
        { sfx: 'scan_lock', at: SCAN.LOCK, gain: 0.4 },
        { sfx: 'sheet', at: SCAN.SHEET, gain: 0.3 },
        { sfx: 'card_in', at: SCAN.SHEET + 6, gain: 0.35 },
      ];
    case 'watch': {
      const w = watchTimes(fast);
      return [
        { sfx: 'whoosh', at: 0, gain: 0.18 },
        { sfx: 'haptic', at: w.ALERT, gain: 0.5 },
        { sfx: 'watch_alert', at: w.ALERT + 2, gain: 0.4 },
        { sfx: 'sheet', at: w.SHEET, gain: 0.3 },
      ];
    }
    case 'emergency': {
      const e = emergencyTimes(fast);
      // A soft tick each time the countdown's number changes (30 → 26 over COUNT..SKIP).
      const ticks = [0, 1, 2, 3, 4].map((i) => ({ sfx: 'sos_tick' as const, at: Math.round(e.COUNT + ((e.SKIP - e.COUNT) / 4) * i), gain: 0.28 }));
      return [
        { sfx: 'tap', at: e.PRESS, gain: 0.35 },
        ...ticks,
        { sfx: 'chime', at: e.QR, gain: 0.3 },
        { sfx: 'whoosh', at: e.SECOND, gain: 0.22 },
      ];
    }
    case 'trust':
      return TRUST_ROWS.slice(0, 4).map((at) => ({ sfx: 'ledger_tick' as const, at, gain: 0.22 }));
    default:
      return [];
  }
};

/** Voice cues per scene, in scene frames (the conversation lines ride the conversation clock). */
const voiceFor = (id: SceneId, fast: boolean): VoCue[] => {
  if (id === 'ask') {
    const t = fast ? tallTimeline : heroTimeline;
    return [
      { line: 'ask_user', at: t.hear },
      { line: 'ask_agent', at: t.speak },
    ];
  }
  return (fast ? vertVo : heroVo)[id] ?? [];
};

export const Soundtrack: React.FC<{ placed: Placed[]; total: number; cut: 'hero' | 'vertical'; xfade: number }> = ({
  placed,
  total,
  cut,
  xfade,
}) => {
  const fast = cut === 'vertical';
  const askFrames = placed.find((p) => p.id === 'ask')?.frames ?? 0;
  const voices = placed.flatMap((p) => voiceFor(p.id, fast).map((c) => ({ line: c.line as VoId, from: p.from + c.at })));
  const sfx = placed.flatMap((p) => sfxFor(p.id, fast, askFrames, xfade).map((c) => ({ ...c, from: p.from + c.at })));

  // Duck: 120 ms down before a voice, 400 ms back up after it.
  const duck = (f: number): number => {
    let g = 1;
    for (const v of voices) {
      const end = v.from + voFrames(v.line);
      const into = interpolate(f, [v.from - 6, v.from], [0, 1], clampOpts);
      const out = interpolate(f, [end, end + 12], [1, 0], clampOpts);
      g = Math.min(g, 1 - (1 - DUCK) * Math.min(into, out));
    }
    return g;
  };

  return (
    <>
      <Audio src={staticFile(`audio/music-${cut}.mp3`)} volume={(f) => MUSIC * duck(f) * interpolate(f, [total - 8, total], [1, 0], clampOpts)} />
      {voices.map((v, i) => (
        <Sequence key={`v${i}`} from={v.from} durationInFrames={voFrames(v.line) + 6} name={`vo:${v.line}`} layout="none">
          <Audio src={staticFile(`audio/vo/${v.line}.mp3`)} volume={VOICE} />
        </Sequence>
      ))}
      {sfx.map((s, i) => (
        <Sequence key={`s${i}`} from={Math.max(0, Math.round(s.from))} durationInFrames={60} name={`sfx:${s.sfx}`} layout="none">
          <Audio src={staticFile(`audio/sfx/${s.sfx}.mp3`)} volume={s.gain} />
        </Sequence>
      ))}
    </>
  );
};
