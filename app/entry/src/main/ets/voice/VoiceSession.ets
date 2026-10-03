// Push-to-talk facade for the UI: press → startTalking(), release → stopTalking() returns transcript + reply.
// Speech goes through the same AgentCore turn as typed text (SafetyGate first), and replies are spoken.

import { common } from '@kit.AbilityKit';
import { AgentCore } from '../agent/AgentCore';
import { AgentReply } from '../model/AgentTypes';
import { Logger } from '../common/Logger';
import { VoiceInput, VoiceMode } from './VoiceInput';
import { VoiceOutput, SpeakMode } from './VoiceOutput';

const log: Logger = new Logger('VoiceSession');

export interface VoiceTurn {
  transcript: string;          // '' if nothing was recognised
  reply: AgentReply | undefined;
}

export interface VoiceStatus {
  input: VoiceMode;
  output: SpeakMode;
}

export class VoiceSession {
  private static instance: VoiceSession | undefined = undefined;
  private speakProactive: boolean = false;

  static get(): VoiceSession {
    if (VoiceSession.instance === undefined) {
      VoiceSession.instance = new VoiceSession();
    }
    return VoiceSession.instance;
  }

  // preferCloud = true skips Core Speech (e.g. if on-device English recognition is poor on a device).
  async init(ctx: common.UIAbilityContext, preferCloud: boolean): Promise<VoiceStatus> {
    const status: VoiceStatus = {
      input: await VoiceInput.get().init(ctx, preferCloud),
      output: await VoiceOutput.get().init(preferCloud)
    };
    if (!this.speakProactive) {
      this.speakProactive = true;
      AgentCore.get().onProactive((r: AgentReply) => {
        VoiceOutput.get().speak(r.text);
      });
    }
    return status;
  }

  async startTalking(): Promise<boolean> {
    await VoiceOutput.get().stop();   // barge-in
    return await VoiceInput.get().begin();
  }

  async stopTalking(): Promise<VoiceTurn> {
    const transcript: string = await VoiceInput.get().end();
    if (transcript.length === 0) {
      const empty: VoiceTurn = { transcript: '', reply: undefined };
      return empty;
    }
    log.info(`heard ${transcript.length} chars via ${VoiceInput.get().getMode()}`);
    const reply: AgentReply = await AgentCore.get().send(transcript);
    VoiceOutput.get().speak(reply.text);
    const turn: VoiceTurn = { transcript: transcript, reply: reply };
    return turn;
  }

  cancel(): void {
    VoiceInput.get().cancel();
  }
}
