// OWNER: Kaloyan — voice input without a microphone (the emulator has none).
//
// With LocalConfig.DEMO_VOICE_INPUT = 'on', a live voice session does not open the microphone. It streams a
// bundled clip (rawfile/voice/*.pcm, 24 kHz PCM16 mono, made with the macOS system voice) into the same
// input_audio_buffer the microphone feeds, so server VAD, input transcription, the safety gate and the tools all
// run for real. Each new session plays the next clip. The UI shows a SIMULATED VOICE INPUT badge while this is on.

import { common } from '@kit.AbilityKit';
import { Config } from '../common/Config';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('DemoVoice');

// In session order. The emergency one is last: it ends the conversation with the SOS flow.
const CLIPS: string[] = ['ondansetron', 'dentist', 'dizzy'];

export class DemoVoice {
  private static context: common.UIAbilityContext | undefined = undefined;
  private static nextIndex: number = 0;

  static init(context: common.UIAbilityContext): void {
    DemoVoice.context = context;
  }

  static enabled(): boolean {
    return Config.DEMO_VOICE_INPUT;
  }

  // The clip for this session; the following session gets the next one.
  static nextClip(): string {
    const name: string = CLIPS[DemoVoice.nextIndex % CLIPS.length];
    DemoVoice.nextIndex++;
    return name;
  }

  static async load(name: string): Promise<Uint8Array | undefined> {
    if (DemoVoice.context === undefined) {
      return undefined;
    }
    try {
      return await DemoVoice.context.resourceManager.getRawFileContent(`voice/${name}.pcm`);
    } catch (e) {
      log.warn(`clip ${name} not readable: ${String(e)}`);
      return undefined;
    }
  }
}
