// Plays a stream of PCM16 mono chunks (24 kHz) as they arrive — used for realtime speech. clear() drops queued
// audio instantly (barge-in, or when a model response is cancelled by the safety checks).

import { audio } from '@kit.AudioKit';
import { Logger } from '../common/Logger';
import { pcmLevel } from './Wav';

const log: Logger = new Logger('PcmStreamPlayer');

export class PcmStreamPlayer {
  private renderer: audio.AudioRenderer | undefined = undefined;
  private queue: Uint8Array[] = [];
  private head: Uint8Array = new Uint8Array(0);
  private headOffset: number = 0;
  private levelCb: ((level: number, playing: boolean) => void) | undefined = undefined;

  // Called once per renderer buffer with the loudness of what is being played (0 when silent).
  onLevel(cb: (level: number, playing: boolean) => void): void {
    this.levelCb = cb;
  }

  async open(): Promise<void> {
    if (this.renderer !== undefined) {
      return;
    }
    const streamInfo: audio.AudioStreamInfo = {
      samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_24000,
      channels: audio.AudioChannel.CHANNEL_1,
      sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
      encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
    };
    const rendererInfo: audio.AudioRendererInfo = { usage: audio.StreamUsage.STREAM_USAGE_VOICE_COMMUNICATION,
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
    await renderer.start();
  }

  enqueue(chunk: Uint8Array): void {
    if (chunk.length > 0) {
      this.queue.push(chunk);
    }
  }

  clear(): void {
    this.queue = [];
    this.head = new Uint8Array(0);
    this.headOffset = 0;
  }

  isPlaying(): boolean {
    return this.queue.length > 0 || this.headOffset < this.head.length;
  }

  async close(): Promise<void> {
    this.clear();
    const r: audio.AudioRenderer | undefined = this.renderer;
    this.renderer = undefined;
    if (r !== undefined) {
      try {
        await r.stop();
        await r.release();
      } catch (e) {
        log.warn(`close failed: ${String(e)}`);
      }
    }
  }

  // Renderer pulls audio; silence when the queue is empty keeps the stream open between responses.
  private fill(buffer: ArrayBuffer): audio.AudioDataCallbackResult {
    const out: Uint8Array = new Uint8Array(buffer);
    let written: number = 0;
    while (written < out.length) {
      if (this.headOffset >= this.head.length) {
        const next: Uint8Array | undefined = this.queue.shift();
        if (next === undefined) {
          break;
        }
        this.head = next;
        this.headOffset = 0;
      }
      const n: number = Math.min(out.length - written, this.head.length - this.headOffset);
      out.set(this.head.subarray(this.headOffset, this.headOffset + n), written);
      this.headOffset += n;
      written += n;
    }
    if (written < out.length) {
      out.fill(0, written);
    }
    const cb: ((level: number, playing: boolean) => void) | undefined = this.levelCb;
    if (cb !== undefined) {
      cb(written > 0 ? pcmLevel(out.subarray(0, written)) : 0, written > 0);
    }
    return audio.AudioDataCallbackResult.VALID;
  }
}
