// OWNER: Kaloyan — speaks agent replies.
//   ON_DEVICE: Core Speech Kit textToSpeech (en-US) when the engine supports it.
//   CLOUD:     /speak → PCM16 24 kHz mono → AudioRenderer.
// Speech is best-effort: the text is always on screen, so any failure is logged and ignored.

import { textToSpeech } from '@kit.CoreSpeechKit';
import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '../common/Logger';
import { BackendClient } from '../agent/BackendClient';

const log: Logger = new Logger('VoiceOutput');

export type SpeakMode = 'ON_DEVICE' | 'CLOUD' | 'OFF';

interface SpeakRequest {
  text: string;
}

export class VoiceOutput {
  private static instance: VoiceOutput | undefined = undefined;

  private mode: SpeakMode = 'OFF';
  private tts: textToSpeech.TextToSpeechEngine | undefined = undefined;
  private renderer: audio.AudioRenderer | undefined = undefined;
  private pcm: Uint8Array = new Uint8Array(0);
  private readOffset: number = 0;
  private requestSeq: number = 0;

  static get(): VoiceOutput {
    if (VoiceOutput.instance === undefined) {
      VoiceOutput.instance = new VoiceOutput();
    }
    return VoiceOutput.instance;
  }

  getMode(): SpeakMode {
    return this.mode;
  }

  async init(preferCloud: boolean): Promise<SpeakMode> {
    if (!preferCloud && (await this.createOnDeviceEngine())) {
      this.mode = 'ON_DEVICE';
    } else {
      this.mode = BackendClient.available() ? 'CLOUD' : 'OFF';
    }
    log.info(`voice output mode: ${this.mode}`);
    return this.mode;
  }

  async speak(text: string): Promise<void> {
    const clean: string = text.trim();
    if (clean.length === 0 || this.mode === 'OFF') {
      return;
    }
    await this.stop();
    try {
      if (this.mode === 'ON_DEVICE' && this.tts !== undefined) {
        const extra: Record<string, Object> = { 'queueMode': 0, 'speed': 1, 'volume': 2, 'pitch': 1,
          'languageContext': 'en-US', 'audioType': 'pcm', 'soundChannel': 3, 'playType': 1 };
        const params: textToSpeech.SpeakParams = { requestId: `say-${Date.now()}-${this.requestSeq++}`,
          extraParams: extra };
        this.tts.speak(clean, params);
        return;
      }
      const req: SpeakRequest = { text: clean };
      const pcm: ArrayBuffer | undefined = await BackendClient.postForBinary('speak', JSON.stringify(req), 20000);
      if (pcm !== undefined && pcm.byteLength > 0) {
        await this.playPcm(new Uint8Array(pcm));
      }
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      log.warn(`speak failed: ${err.code} ${err.message}`);
    }
  }

  // Barge-in: stop talking as soon as the user presses the mic.
  async stop(): Promise<void> {
    try {
      if (this.tts !== undefined && this.tts.isBusy()) {
        this.tts.stop();
      }
      if (this.renderer !== undefined && this.renderer.state === audio.AudioState.STATE_RUNNING) {
        await this.renderer.stop();
      }
    } catch (e) {
      log.warn(`stop failed: ${String(e)}`);
    }
    this.pcm = new Uint8Array(0);
    this.readOffset = 0;
  }

  private createOnDeviceEngine(): Promise<boolean> {
    if (this.tts !== undefined) {
      return Promise.resolve(true);
    }
    return new Promise<boolean>((resolve: (ok: boolean) => void) => {
      const extra: Record<string, Object> = { 'style': 'interaction-broadcast', 'locate': 'CN', 'name': 'CeliaTts' };
      const params: textToSpeech.CreateEngineParams = { language: 'en-US', person: 0, online: 1, extraParams: extra };
      try {
        textToSpeech.createEngine(params, (err: BusinessError, engine: textToSpeech.TextToSpeechEngine) => {
          if (err) {
            log.warn(`Core Speech TTS en-US unavailable: ${err.code} ${err.message}`);
            resolve(false);
            return;
          }
          this.tts = engine;
          resolve(true);
        });
      } catch (e) {
        log.warn(`Core Speech TTS createEngine threw: ${String(e)}`);
        resolve(false);
      }
    });
  }

  private async playPcm(pcm: Uint8Array): Promise<void> {
    if (this.renderer === undefined) {
      const streamInfo: audio.AudioStreamInfo = {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_24000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      };
      const rendererInfo: audio.AudioRendererInfo = { usage: audio.StreamUsage.STREAM_USAGE_VOICE_ASSISTANT,
        rendererFlags: 0 };
      const options: audio.AudioRendererOptions = { streamInfo: streamInfo, rendererInfo: rendererInfo };
      const renderer: audio.AudioRenderer = await audio.createAudioRenderer(options);
      try {
        renderer.on('writeData', (buffer: ArrayBuffer): audio.AudioDataCallbackResult => this.fill(buffer));
      } catch (e) {
        await renderer.release();
        throw new Error(`writeData listener failed: ${String(e)}`);
      }
      this.renderer = renderer;
    }
    this.pcm = pcm;
    this.readOffset = 0;
    await (this.renderer as audio.AudioRenderer).start();
  }

  // Copies the next slice of PCM into the renderer buffer; pads with silence and stops at the end.
  private fill(buffer: ArrayBuffer): audio.AudioDataCallbackResult {
    const out: Uint8Array = new Uint8Array(buffer);
    const remaining: number = this.pcm.length - this.readOffset;
    if (remaining <= 0) {
      out.fill(0);
      const r: audio.AudioRenderer | undefined = this.renderer;
      if (r !== undefined) {
        setTimeout(() => {
          r.stop().catch((): void => {});
        }, 0);
      }
      return audio.AudioDataCallbackResult.INVALID;
    }
    const n: number = Math.min(remaining, out.length);
    out.set(this.pcm.subarray(this.readOffset, this.readOffset + n));
    if (n < out.length) {
      out.fill(0, n);
    }
    this.readOffset += n;
    return audio.AudioDataCallbackResult.VALID;
  }
}
