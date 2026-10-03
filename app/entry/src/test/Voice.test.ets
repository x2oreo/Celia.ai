// Voice helpers: the WAV wrapper must produce a header the transcription API accepts.

import { describe, it, expect } from '@ohos/hypium';
import { concatChunks, pcmDurationMs, pcmLevel, pcmToWav } from '../main/ets/voice/Wav';
import { DemoScript, demoScripts, parseScript } from '../main/ets/voice/DemoVoice';

function ascii(bytes: Uint8Array, start: number, len: number): string {
  let s: string = '';
  for (let i = start; i < start + len; i++) {
    s += String.fromCharCode(bytes[i]);
  }
  return s;
}

export default function voiceTest() {
  describe('DemoVoice', () => {
    it('parsesPlainAndBargeInScripts', 0, () => {
      expect(parseScript('doses').first).assertEqual('doses');
      expect(parseScript('doses').interrupt).assertEqual('');
      const b: DemoScript = parseScript('ondansetron+doses');
      expect(b.first).assertEqual('ondansetron');
      expect(b.interrupt).assertEqual('doses');
    });

    it('firstSessionIsAPlainQuestionAndOneScriptBargesIn', 0, () => {
      const all: DemoScript[] = demoScripts();
      expect(all[0].interrupt).assertEqual('');
      expect(all.filter((s: DemoScript) => s.interrupt !== '').length).assertEqual(1);
      for (const s of all) {
        expect(s.first.length > 0).assertTrue();
      }
    });
  });

  describe('Wav', () => {
    it('wrapsPcmInRiffHeader', 0, () => {
      const pcm: Uint8Array = new Uint8Array(32000); // 1 s at 16 kHz, 16-bit mono
      const wav: Uint8Array = pcmToWav(pcm, 16000);
      const view: DataView = new DataView(wav.buffer);
      expect(wav.length).assertEqual(44 + 32000);
      expect(ascii(wav, 0, 4)).assertEqual('RIFF');
      expect(ascii(wav, 8, 4)).assertEqual('WAVE');
      expect(ascii(wav, 36, 4)).assertEqual('data');
      expect(view.getUint32(4, true)).assertEqual(36 + 32000);
      expect(view.getUint32(24, true)).assertEqual(16000);
      expect(view.getUint32(28, true)).assertEqual(32000);
      expect(view.getUint16(34, true)).assertEqual(16);
      expect(view.getUint32(40, true)).assertEqual(32000);
    });

    it('concatenatesChunksInOrder', 0, () => {
      const a: ArrayBuffer = new ArrayBuffer(2);
      new Uint8Array(a).set([1, 2]);
      const b: ArrayBuffer = new ArrayBuffer(1);
      new Uint8Array(b).set([3]);
      const out: Uint8Array = concatChunks([a, b]);
      expect(Array.from(out).join(',')).assertEqual('1,2,3');
    });

    it('computesDuration', 0, () => {
      expect(pcmDurationMs(32000, 16000)).assertEqual(1000);
      expect(pcmDurationMs(48000, 24000)).assertEqual(1000);
    });

    it('levelIsZeroForSilenceAndRisesWithLoudness', 0, () => {
      const tone = (amplitude: number): Uint8Array => {
        const pcm: Uint8Array = new Uint8Array(960);   // 20 ms at 24 kHz
        const view: DataView = new DataView(pcm.buffer);
        for (let i = 0; i < 480; i++) {
          view.setInt16(i * 2, i % 2 === 0 ? amplitude : -amplitude, true);
        }
        return pcm;
      };
      expect(pcmLevel(new Uint8Array(0))).assertEqual(0);
      expect(pcmLevel(new Uint8Array(960))).assertEqual(0);
      const quiet: number = pcmLevel(tone(600));
      const loud: number = pcmLevel(tone(12000));
      expect(quiet > 0).assertTrue();
      expect(loud > quiet).assertTrue();
      expect(pcmLevel(tone(32767)) <= 1).assertTrue();
    });
  });
}
