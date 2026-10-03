// CPR metronome timing. 100–120 compressions per minute (ERC / AHA); we use 110.

export const CPR_BPM: number = 110;

export function beatIntervalMs(bpm: number): number {
  return Math.round(60000 / bpm);
}
