// When each spoken line starts, in frames local to its scene. Scenes time their on-screen lines from these, and
// the soundtrack places the audio from the same numbers, so words on screen land with the voice.
import type { SceneId } from '../copy/script';
import type { VoId } from './vo';

export interface VoCue {
  line: VoId;
  at: number;
}

export const heroVo: Partial<Record<SceneId, VoCue[]>> = {
  hook: [{ line: 'hook', at: 12 }],
  stakes: [{ line: 'stakes', at: 14 }],
  reveal: [{ line: 'reveal', at: 20 }],
  // ask: Ola and the agent speak on the conversation clock (scenes/conversation.ts), see Soundtrack.
  verdict: [{ line: 'verdict', at: 24 }],
  scan: [{ line: 'scan', at: 14 }],
  watch: [{ line: 'watch', at: 14 }],
  emergency: [{ line: 'emergency', at: 18 }],
  visit: [{ line: 'visit', at: 14 }],
  celia: [{ line: 'celia', at: 14 }],
  trust: [{ line: 'trust', at: 14 }],
  market: [{ line: 'market', at: 14 }],
  end: [{ line: 'end', at: 22 }],
};

export const vertVo: Partial<Record<SceneId, VoCue[]>> = {
  hook: [{ line: 'hook_v', at: 8 }],
  watch: [{ line: 'watch_v', at: 10 }],
  emergency: [{ line: 'emergency_v', at: 12 }],
  end: [{ line: 'end', at: 14 }],
};

/** Start frame of the first cue of `scene`, or `fallback`. */
export const voAt = (cues: Partial<Record<SceneId, VoCue[]>>, scene: SceneId, fallback = 0): number =>
  cues[scene]?.[0]?.at ?? fallback;
