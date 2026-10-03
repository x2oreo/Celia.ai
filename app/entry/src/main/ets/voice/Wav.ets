// PCM helpers for the voice path. Pure functions (unit-tested).

export const MIC_SAMPLE_RATE: number = 16000;   // AudioCapturer → /transcribe
export const TTS_SAMPLE_RATE: number = 24000;   // /speak returns 24 kHz PCM16 mono

// Concatenate captured chunks into one buffer.
export function concatChunks(chunks: ArrayBuffer[]): Uint8Array {
  let total: number = 0;
  for (const c of chunks) {
    total += c.byteLength;
  }
  const out: Uint8Array = new Uint8Array(total);
  let offset: number = 0;
  for (const c of chunks) {
    out.set(new Uint8Array(c), offset);
    offset += c.byteLength;
  }
  return out;
}

// Wrap 16-bit little-endian mono PCM in a 44-byte RIFF/WAVE header.
export function pcmToWav(pcm: Uint8Array, sampleRate: number): Uint8Array {
  const channels: number = 1;
  const bitsPerSample: number = 16;
  const byteRate: number = sampleRate * channels * bitsPerSample / 8;
  const out: Uint8Array = new Uint8Array(44 + pcm.length);
  const view: DataView = new DataView(out.buffer);
  const ascii = (offset: number, s: string): void => {
    for (let i = 0; i < s.length; i++) {
      view.setUint8(offset + i, s.charCodeAt(i));
    }
  };
  ascii(0, 'RIFF');
  view.setUint32(4, 36 + pcm.length, true);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  view.setUint32(16, 16, true);              // fmt chunk size
  view.setUint16(20, 1, true);               // PCM
  view.setUint16(22, channels, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, byteRate, true);
  view.setUint16(32, channels * bitsPerSample / 8, true);
  view.setUint16(34, bitsPerSample, true);
  ascii(36, 'data');
  view.setUint32(40, pcm.length, true);
  out.set(pcm, 44);
  return out;
}

// Duration in ms of 16-bit mono PCM.
export function pcmDurationMs(byteLength: number, sampleRate: number): number {
  return Math.round(byteLength / 2 / sampleRate * 1000);
}
