// OWNER: Kaloyan - voice input without a microphone (the emulator has none).
//
// With LocalConfig.DEMO_VOICE_INPUT = 'on', a live voice session does not open the microphone. It streams a
// bundled clip (rawfile/voice/*.pcm, 24 kHz PCM16 mono, made with the macOS system voice) into the same
// input_audio_buffer the microphone feeds, so server VAD, input transcription, the safety gate and the tools all
// run for real. Each new session plays the next clip. The UI shows a SIMULATED VOICE INPUT badge while this is on.

import { common } from '@kit.AbilityKit';
import { Config } from '../common/Config';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('DemoVoice');

// In session order. The emergency one ends a conversation with the SOS flow, so it comes after the questions.
// "a+b" is a barge-in session: clip a asks, and clip b is played over the agent's spoken answer.
const CLIPS: string[] = ['ondansetron', 'dentist', 'doses', 'trends', 'symptoms', 'reminders', 'tookdose', 'dizzy',
  'ondansetron+doses'];

export interface DemoScript {
  first: string;       // the clip that opens the session
  interrupt: string;   // played while the agent is speaking; '' = no barge-in
}

export function parseScript(entry: string): DemoScript {
  const at: number = entry.indexOf('+');
  const s: DemoScript = {
    first: at < 0 ? entry : entry.substring(0, at),
    interrupt: at < 0 ? '' : entry.substring(at + 1)
  };
  return s;
}

export function demoScripts(): DemoScript[] {
  return CLIPS.map((c: string) => parseScript(c));
}

// What each clip says, for the log and the tests (the audio is the source of truth).
//   ondansetron  "Can I take ondansetron?"            → check_drug
//   dentist      a dentist visit is coming up          → prepare_doctor_visit
//   doses        "Did I take my nadolol today?"        → get_dose_status
//   trends       "How has my heart been over the last two weeks?" → get_trends
//   symptoms     "Show me the symptoms I logged recently."        → open_symptom_log
//   reminders    "Open my medicine reminders."         → open_reminders
//   tookdose     "I just took my nadolol."             → log_dose (confirm card)
//   dizzy        a dizzy spell                         → safety gate / emergency flow
//   ondansetron+doses   the dose question interrupts the ondansetron answer (barge-in)

export class DemoVoice {
  private static context: common.UIAbilityContext | undefined = undefined;
  private static nextIndex: number = 0;

  static init(context: common.UIAbilityContext): void {
    DemoVoice.context = context;
  }

  static enabled(): boolean {
    return Config.DEMO_VOICE_INPUT;
  }

  // The script for this session; the following session gets the next one.
  static nextScript(): DemoScript {
    const s: DemoScript = parseScript(CLIPS[DemoVoice.nextIndex % CLIPS.length]);
    DemoVoice.nextIndex++;
    return s;
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
