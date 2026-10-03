// OWNER: Kaloyan — push-to-talk speech input.
//   ON_DEVICE: Core Speech Kit speechRecognizer (en-US) — preferred, audio never leaves the phone.
//   CLOUD:     AudioCapturer PCM16 16 kHz → WAV → /transcribe (Core Speech samples are zh-CN only; English
//              support is unverified on our devices, so this is the fallback).
// Usage: await VoiceInput.get().init(ctx) once; begin() on press; const text = await end() on release.

import { speechRecognizer } from '@kit.CoreSpeechKit';
import { audio } from '@kit.AudioKit';
import { abilityAccessCtrl, common, Permissions, PermissionRequestResult } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { Logger } from '../common/Logger';
import { BackendClient } from '../agent/BackendClient';
import { MIC_SAMPLE_RATE, concatChunks, pcmDurationMs, pcmToWav } from './Wav';

const log: Logger = new Logger('VoiceInput');

export type VoiceMode = 'ON_DEVICE' | 'CLOUD' | 'UNAVAILABLE';

const MIC: Permissions = 'ohos.permission.MICROPHONE';
const MAX_RECORD_MS: number = 30000;
const MIN_RECORD_MS: number = 300;
const FINAL_RESULT_TIMEOUT_MS: number = 5000;

interface TranscribeRequest {
  audioBase64: string;
  language: string;
}

interface TranscribeResponse {
  text: string;
}

export class VoiceInput {
  private static instance: VoiceInput | undefined = undefined;

  private mode: VoiceMode = 'UNAVAILABLE';
  private asr: speechRecognizer.SpeechRecognitionEngine | undefined = undefined;
  private capturer: audio.AudioCapturer | undefined = undefined;
  private chunks: ArrayBuffer[] = [];
  private sessionId: string = '';
  private partial: string = '';
  private finalResolver: ((text: string) => void) | undefined = undefined;
  private recording: boolean = false;
  private language: string = ''; // '' = auto-detect (EN/PL users)

  static get(): VoiceInput {
    if (VoiceInput.instance === undefined) {
      VoiceInput.instance = new VoiceInput();
    }
    return VoiceInput.instance;
  }

  getMode(): VoiceMode {
    return this.mode;
  }

  isRecording(): boolean {
    return this.recording;
  }

  // Asks for the microphone permission and picks the best available engine. Safe to call more than once.
  async init(ctx: common.UIAbilityContext, preferCloud: boolean): Promise<VoiceMode> {
    if (!(await this.ensureMicPermission(ctx))) {
      this.mode = 'UNAVAILABLE';
      return this.mode;
    }
    if (!preferCloud && (await this.createOnDeviceEngine())) {
      this.mode = 'ON_DEVICE';
    } else {
      this.mode = BackendClient.available() ? 'CLOUD' : 'UNAVAILABLE';
    }
    log.info(`voice input mode: ${this.mode}`);
    return this.mode;
  }

  async begin(): Promise<boolean> {
    if (this.recording || this.mode === 'UNAVAILABLE') {
      return false;
    }
    this.partial = '';
    this.chunks = [];
    this.sessionId = `ptt-${Date.now()}`;
    try {
      if (this.mode === 'ON_DEVICE' && this.asr !== undefined) {
        const extra: Record<string, Object> = { 'recognitionMode': 0, 'vadBegin': 2000, 'vadEnd': 3000,
          'maxAudioDuration': MAX_RECORD_MS };
        const audioInfo: speechRecognizer.AudioInfo = { audioType: 'pcm', sampleRate: MIC_SAMPLE_RATE,
          soundChannel: 1, sampleBit: 16 };
        const params: speechRecognizer.StartParams = { sessionId: this.sessionId, audioInfo: audioInfo,
          extraParams: extra };
        this.asr.startListening(params);
      } else {
        await this.startCapturer();
      }
      this.recording = true;
      return true;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      log.error(`begin failed: ${err.code} ${err.message}`);
      return false;
    }
  }

  // Stops recording and returns the transcript ('' if nothing usable was heard or recognition failed).
  async end(): Promise<string> {
    if (!this.recording) {
      return '';
    }
    this.recording = false;
    if (this.mode === 'ON_DEVICE' && this.asr !== undefined) {
      return await this.finishOnDevice();
    }
    return await this.finishCloud();
  }

  cancel(): void {
    this.recording = false;
    try {
      if (this.asr !== undefined && this.sessionId !== '') {
        this.asr.cancel(this.sessionId);
      }
      if (this.capturer !== undefined) {
        this.capturer.stop().catch((): void => {});
      }
    } catch (e) {
      log.warn(`cancel: ${String(e)}`);
    }
    this.chunks = [];
  }

  // ---- on-device (Core Speech) -------------------------------------------------------------------------------

  private createOnDeviceEngine(): Promise<boolean> {
    if (this.asr !== undefined) {
      return Promise.resolve(true);
    }
    return new Promise<boolean>((resolve: (ok: boolean) => void) => {
      const extra: Record<string, Object> = { 'locate': 'CN', 'recognizerMode': 'short' };
      const params: speechRecognizer.CreateEngineParams = { language: 'en-US', online: 1, extraParams: extra };
      try {
        speechRecognizer.createEngine(params,
          (err: BusinessError, engine: speechRecognizer.SpeechRecognitionEngine) => {
            if (err) {
              // 1002200001 = language/mode not supported → cloud fallback.
              log.warn(`Core Speech en-US unavailable: ${err.code} ${err.message}`);
              resolve(false);
              return;
            }
            this.asr = engine;
            this.attachListener(engine);
            resolve(true);
          });
      } catch (e) {
        log.warn(`Core Speech createEngine threw: ${String(e)}`);
        resolve(false);
      }
    });
  }

  private attachListener(engine: speechRecognizer.SpeechRecognitionEngine): void {
    const listener: speechRecognizer.RecognitionListener = {
      onStart: (sessionId: string, eventMessage: string): void => {
        log.debug(`asr start ${sessionId}`);
      },
      onEvent: (sessionId: string, eventCode: number, eventMessage: string): void => {
      },
      onResult: (sessionId: string, result: speechRecognizer.SpeechRecognitionResult): void => {
        this.partial = result.result;
        if (result.isLast) {
          this.resolveFinal(result.result);
        }
      },
      onComplete: (sessionId: string, eventMessage: string): void => {
        this.resolveFinal(this.partial);
      },
      onError: (sessionId: string, errorCode: number, errorMessage: string): void => {
        log.warn(`asr error ${errorCode} ${errorMessage}`);
        this.resolveFinal(this.partial);
      }
    };
    engine.setListener(listener);
  }

  private resolveFinal(text: string): void {
    const r: ((text: string) => void) | undefined = this.finalResolver;
    this.finalResolver = undefined;
    if (r !== undefined) {
      r(text.trim());
    }
  }

  private finishOnDevice(): Promise<string> {
    return new Promise<string>((resolve: (text: string) => void) => {
      this.finalResolver = resolve;
      setTimeout(() => this.resolveFinal(this.partial), FINAL_RESULT_TIMEOUT_MS);
      try {
        (this.asr as speechRecognizer.SpeechRecognitionEngine).finish(this.sessionId);
      } catch (e) {
        log.warn(`asr finish failed: ${String(e)}`);
        this.resolveFinal(this.partial);
      }
    });
  }

  // ---- cloud (AudioCapturer → /transcribe) ---------------------------------------------------------------------

  private async startCapturer(): Promise<void> {
    if (this.capturer === undefined) {
      const streamInfo: audio.AudioStreamInfo = {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      };
      const capturerInfo: audio.AudioCapturerInfo = { source: audio.SourceType.SOURCE_TYPE_MIC, capturerFlags: 0 };
      const options: audio.AudioCapturerOptions = { streamInfo: streamInfo, capturerInfo: capturerInfo };
      const capturer: audio.AudioCapturer = await audio.createAudioCapturer(options);
      try {
        capturer.on('readData', (buffer: ArrayBuffer) => {
          if (this.recording && pcmDurationMs(this.totalBytes(), MIC_SAMPLE_RATE) < MAX_RECORD_MS) {
            this.chunks.push(buffer.slice(0));
          }
        });
      } catch (e) {
        await capturer.release();
        throw new Error(`readData listener failed: ${String(e)}`);
      }
      this.capturer = capturer;
    }
    await this.capturer.start();
  }

  private totalBytes(): number {
    let n: number = 0;
    for (const c of this.chunks) {
      n += c.byteLength;
    }
    return n;
  }

  private async finishCloud(): Promise<string> {
    try {
      if (this.capturer !== undefined) {
        await this.capturer.stop();
      }
    } catch (e) {
      log.warn(`capturer stop failed: ${String(e)}`);
    }
    const pcm: Uint8Array = concatChunks(this.chunks);
    this.chunks = [];
    if (pcmDurationMs(pcm.length, MIC_SAMPLE_RATE) < MIN_RECORD_MS) {
      return '';
    }
    const wav: Uint8Array = pcmToWav(pcm, MIC_SAMPLE_RATE);
    const req: TranscribeRequest = {
      audioBase64: new util.Base64Helper().encodeToStringSync(wav),
      language: this.language
    };
    const raw: string | undefined = await BackendClient.postJson('transcribe', JSON.stringify(req), 20000);
    if (raw === undefined) {
      return '';
    }
    try {
      const res: TranscribeResponse = JSON.parse(raw) as TranscribeResponse;
      return typeof res.text === 'string' ? res.text.trim() : '';
    } catch (e) {
      return '';
    }
  }

  // ---- permission ------------------------------------------------------------------------------------------------

  private async ensureMicPermission(ctx: common.UIAbilityContext): Promise<boolean> {
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const result: PermissionRequestResult =
        await atManager.requestPermissionsFromUser(ctx, [MIC]);
      return result.authResults.length > 0 && result.authResults[0] === 0;
    } catch (e) {
      log.warn(`mic permission request failed: ${String(e)}`);
      return false;
    }
  }
}
