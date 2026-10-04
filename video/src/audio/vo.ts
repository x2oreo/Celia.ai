// Typed access to the spoken lines: length, live-caption word timing and loudness, from vo-timing.json
// (written by scripts/audio/vo.py). Frames are local to the line's start.
import spec from '../copy/vo.json';
import timing from './vo-timing.json';

export type VoId = (typeof spec.lines)[number]['id'];

interface LineTiming {
  seconds: number;
  frames: number;
  words: number[];
  env: number[];
}

const line = (id: VoId): LineTiming => {
  const t = (timing as Record<string, LineTiming | undefined>)[id];
  if (t === undefined) throw new Error(`No timing for VO line "${id}". Run npm run audio:vo.`);
  return t;
};

export const voText = (id: VoId): string => spec.lines.find((l) => l.id === id)?.text ?? '';

/** Length of the line in frames. */
export const voFrames = (id: VoId): number => line(id).frames;

/** Loudness 0..1 at local frame `f` (0 outside the line). */
export const voLevel = (id: VoId, f: number): number => {
  const env = line(id).env;
  const i = Math.floor(f);
  return i < 0 || i >= env.length ? 0 : env[i] ?? 0;
};

/** How many words have started by local frame `f`, with the newest word's 0..1 fade (for live captions). */
export const voWords = (id: VoId, f: number): number => {
  const starts = line(id).words;
  const s = f / 30;
  let n = 0;
  for (let i = 0; i < starts.length; i++) {
    const w = starts[i] ?? 0;
    if (s >= w) n = i + Math.min(1, (s - w) / 0.12);
  }
  return s < (starts[0] ?? 0) ? 0 : n;
};

export const voWordCount = (id: VoId): number => line(id).words.length;

/** Local frame at which word `i` of the line starts. */
export const voWordAt = (id: VoId, i: number): number => Math.round((line(id).words[i] ?? 0) * 30);
