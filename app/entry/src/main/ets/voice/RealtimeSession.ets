// OWNER: Kaloyan — hands-free speech-to-speech with the OpenAI Realtime API, on the SAME on-device tools.
//
//   mic (AudioCapturer 24 kHz) ─► input_audio_buffer.append ─► OpenAI Realtime (server VAD)
//   response.output_audio.delta ─► PcmStreamPlayer
//   response.function_call_arguments.done ─► AgentCore.runTool (on device) ─► function_call_output ─► response.create
//   input transcription ─► SafetyGate: emergency → cancel response, deterministic emergency flow
//   output transcript (streaming) ─► reassurance about a medicine → cancel + say the deterministic verdict instead
//
// The OpenAI key never reaches the phone: /realtime-session mints a 2-minute client secret.
// Any failure → status 'FAILED'; the UI falls back to push-to-talk (VoiceSession).

import { webSocket } from '@kit.NetworkKit';
import { audio } from '@kit.AudioKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '../common/Logger';
import { Listener, Listeners } from '../common/Listeners';
import { AgentCore } from '../agent/AgentCore';
import { BackendClient } from '../agent/BackendClient';
import { RelayContext } from '../agent/AgentClient';
import { TurnState } from '../agent/ToolTypes';
import { hasReassurance } from '../agent/ResponseValidator';
import { verdictText } from '../agent/VerdictText';
import { GateResult } from '../safety/SafetyGate';
import { AgentReply, VerdictCardPayload } from '../model/AgentTypes';
import { VoiceOutput } from './VoiceOutput';
import { PcmStreamPlayer } from './PcmStreamPlayer';

const log: Logger = new Logger('Realtime');

const REALTIME_URL: string = 'wss://api.openai.com/v1/realtime';
const MEDICINE_WORDS: RegExp = /\b(medicine|medication|drug|tablet|pill|take|taking)\b/i;

export type RealtimeStatus = 'IDLE' | 'CONNECTING' | 'LIVE' | 'CLOSED' | 'FAILED';

interface SessionRequest {
  context: RelayContext;
}

interface SessionResponse {
  clientSecret: string;
  expiresAt: number;
  model: string;
  promptVersion: string;
}

// Union of the server event fields we read. Unused fields stay undefined.
interface ServerEvent {
  type: string;
  delta?: string;
  transcript?: string;
  call_id?: string;
  name?: string;
  arguments?: string;
  error?: ServerError;
}

interface ServerError {
  message?: string;
  code?: string;
}

interface AppendEvent {
  type: string;
  audio: string;
}

interface SimpleEvent {
  type: string;
}

interface FunctionOutputItem {
  type: string;
  call_id: string;
  output: string;
}

interface ItemCreateEvent {
  type: string;
  item: FunctionOutputItem;
}

export class RealtimeSession {
  private static instance: RealtimeSession | undefined = undefined;

  private ws: webSocket.WebSocket | undefined = undefined;
  private capturer: audio.AudioCapturer | undefined = undefined;
  private player: PcmStreamPlayer = new PcmStreamPlayer();
  private base64: util.Base64Helper = new util.Base64Helper();
  private status: RealtimeStatus = 'IDLE';
  private turn: TurnState | undefined = undefined;
  private turnReady: Promise<TurnState> | undefined = undefined;
  private transcript: string = '';
  private toolsThisResponse: number = 0;   // tool calls in the current model response
  private toolsRunning: number = 0;        // of those, still executing on the device
  private continueWhenToolsDone: boolean = false;
  private suppressed: boolean = false;   // current response was cancelled by a safety check
  private muted: boolean = false;

  private statusListeners: Listeners<RealtimeStatus> = new Listeners<RealtimeStatus>();
  private replyListeners: Listeners<AgentReply> = new Listeners<AgentReply>();
  private userListeners: Listeners<string> = new Listeners<string>();

  static get(): RealtimeSession {
    if (RealtimeSession.instance === undefined) {
      RealtimeSession.instance = new RealtimeSession();
    }
    return RealtimeSession.instance;
  }

  onStatus(cb: Listener<RealtimeStatus>): () => void {
    return this.statusListeners.add(cb);
  }

  // Agent replies (text + cards) for the chat UI.
  onReply(cb: Listener<AgentReply>): () => void {
    return this.replyListeners.add(cb);
  }

  // What the user said (final transcript), for the chat UI.
  onUserTranscript(cb: Listener<string>): () => void {
    return this.userListeners.add(cb);
  }

  getStatus(): RealtimeStatus {
    return this.status;
  }

  setMuted(muted: boolean): void {
    this.muted = muted;
  }

  // Microphone permission must already be granted (VoiceSession.init asks for it).
  async start(): Promise<boolean> {
    if (this.status === 'CONNECTING' || this.status === 'LIVE') {
      return true;
    }
    this.setStatus('CONNECTING');
    const req: SessionRequest = { context: await AgentCore.get().contextForVoice() };
    const raw: string | undefined = await BackendClient.postJson('realtime-session', JSON.stringify(req), 15000);
    if (raw === undefined) {
      return this.fail('no voice session from backend');
    }
    let session: SessionResponse;
    try {
      session = JSON.parse(raw) as SessionResponse;
    } catch (e) {
      return this.fail('invalid session response');
    }
    if (typeof session.clientSecret !== 'string' || session.clientSecret.length === 0) {
      return this.fail('missing client secret');
    }

    const ws: webSocket.WebSocket = webSocket.createWebSocket();
    this.ws = ws;
    ws.on('message', (err: BusinessError, value: string | ArrayBuffer) => {
      if (!err && typeof value === 'string') {
        this.onServerEvent(value);
      }
    });
    ws.on('close', () => {
      log.info('socket closed');
      this.teardown('CLOSED');
    });
    ws.on('error', (err: BusinessError) => {
      log.warn(`socket error ${err.code} ${err.message}`);
      this.teardown('FAILED');
    });
    try {
      const headers: Record<string, string> = { 'Authorization': `Bearer ${session.clientSecret}` };
      const options: webSocket.WebSocketRequestOptions = { header: headers };
      const ok: boolean = await ws.connect(`${REALTIME_URL}?model=${encodeURIComponent(session.model)}`, options);
      if (!ok) {
        return this.fail('connect returned false');
      }
      await this.player.open();
      await this.startMic();
      this.setStatus('LIVE');
      log.info(`realtime live (${session.model}, prompt ${session.promptVersion})`);
      return true;
    } catch (e) {
      return this.fail(`connect failed: ${String(e)}`);
    }
  }

  async stop(): Promise<void> {
    const ws: webSocket.WebSocket | undefined = this.ws;
    this.ws = undefined;
    if (ws !== undefined) {
      try {
        await ws.close();
      } catch (e) {
        log.warn(`close failed: ${String(e)}`);
      }
    }
    await this.teardown('CLOSED');
  }

  // ---- server events -------------------------------------------------------------------------------------------

  private onServerEvent(raw: string): void {
    let ev: ServerEvent;
    try {
      ev = JSON.parse(raw) as ServerEvent;
    } catch (e) {
      return;
    }
    switch (ev.type) {
      case 'input_audio_buffer.speech_started':
        this.player.clear();        // barge-in: the server also interrupts the response
        break;
      case 'conversation.item.input_audio_transcription.completed':
        this.onUserSaid(ev.transcript ?? '');
        break;
      case 'response.created':
        this.suppressed = false;
        this.transcript = '';
        break;
      case 'response.output_audio.delta':
        if (!this.suppressed && ev.delta !== undefined) {
          this.player.enqueue(this.base64.decodeSync(ev.delta));
        }
        break;
      case 'response.output_audio_transcript.delta':
        this.onModelWords(ev.delta ?? '');
        break;
      case 'response.function_call_arguments.done':
        this.onToolCall(ev.call_id ?? '', ev.name ?? '', ev.arguments ?? '{}');
        break;
      case 'response.done':
        this.onResponseDone();
        break;
      case 'error':
        log.warn(`server error: ${ev.error?.code ?? ''} ${ev.error?.message ?? ''}`);
        break;
      default:
        break;
    }
  }

  private onUserSaid(text: string): void {
    const t: string = text.trim();
    if (t.length === 0) {
      return;
    }
    this.userListeners.emit(t);
    const gate: GateResult = AgentCore.get().noteUserUtterance(t);
    if (gate === 'EMERGENCY' || gate === 'UNWELL') {
      // Deterministic path wins: stop the model, show + say the emergency flow.
      this.cancelResponse();
      AgentCore.get().triggerEmergency(t).then((r: AgentReply) => {
        this.replyListeners.emit(r);
        VoiceOutput.get().speak(r.text);
      });
    }
  }

  // Streaming check of what the model is saying. Audio playback lags the transcript, so cancelling here
  // usually stops the sentence before it is heard.
  private onModelWords(delta: string): void {
    if (this.suppressed) {
      return;
    }
    this.transcript += delta;
    const turn: TurnState | undefined = this.turn;
    const aboutMedicine: boolean = (turn !== undefined && turn.verdicts.length > 0) ||
      MEDICINE_WORDS.test(this.transcript);
    if (aboutMedicine && hasReassurance(this.transcript)) {
      log.warn('realtime: model reassured about a medicine — cancelling response');
      this.cancelResponse();
      const verdicts: VerdictCardPayload[] = turn !== undefined ? turn.verdicts : [];
      const fix: string = verdicts.length > 0
        ? verdicts.map((v: VerdictCardPayload) => verdictText(v)).join(' ')
        : 'I can only judge a medicine after checking it against my list. Tell me its name.';
      const fallbackReply: AgentReply = { text: fix, actions: [], fallback: true };
      const reply: AgentReply = turn !== undefined ? AgentCore.get().finishExternalTurn(turn, fix) : fallbackReply;
      this.resetTurn();
      this.replyListeners.emit(reply);
      VoiceOutput.get().speak(fix);
    }
  }

  private async onToolCall(callId: string, name: string, args: string): Promise<void> {
    if (callId === '' || name === '') {
      return;
    }
    // Counted synchronously so response.done (which can arrive while the tool runs) waits for it.
    this.toolsThisResponse++;
    this.toolsRunning++;
    let output: string;
    try {
      if (this.turnReady === undefined) {
        this.turnReady = AgentCore.get().beginExternalTurn();
      }
      const turn: TurnState = await this.turnReady;
      this.turn = turn;
      output = await AgentCore.get().runTool(name, args, turn);
    } catch (e) {
      output = '{"error":"tool failed on the device"}';
    }
    const item: FunctionOutputItem = { type: 'function_call_output', call_id: callId, output: output };
    const ev: ItemCreateEvent = { type: 'conversation.item.create', item: item };
    this.send(JSON.stringify(ev));
    this.toolsRunning--;
    if (this.toolsRunning === 0 && this.continueWhenToolsDone) {
      this.continueWhenToolsDone = false;
      this.continueAfterTools();
    }
  }

  // Tools ran during this response: ask the model to continue with their results.
  private continueAfterTools(): void {
    this.toolsThisResponse = 0;
    const ev: SimpleEvent = { type: 'response.create' };
    this.send(JSON.stringify(ev));
  }

  private onResponseDone(): void {
    if (this.toolsThisResponse > 0) {
      if (this.toolsRunning > 0) {
        this.continueWhenToolsDone = true;
      } else {
        this.continueAfterTools();
      }
      return;
    }
    if (this.suppressed) {
      return;
    }
    const spoken: string = this.transcript.trim();
    if (spoken.length === 0 && this.turn === undefined) {
      return;
    }
    const turn: TurnState = this.turn !== undefined ? this.turn : new TurnState();
    this.resetTurn();
    this.replyListeners.emit(AgentCore.get().finishExternalTurn(turn, spoken));
  }

  private resetTurn(): void {
    this.turn = undefined;
    this.turnReady = undefined;
  }

  private cancelResponse(): void {
    this.suppressed = true;
    this.player.clear();
    const ev: SimpleEvent = { type: 'response.cancel' };
    this.send(JSON.stringify(ev));
  }

  // ---- mic -----------------------------------------------------------------------------------------------------

  private async startMic(): Promise<void> {
    const streamInfo: audio.AudioStreamInfo = {
      samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_24000,
      channels: audio.AudioChannel.CHANNEL_1,
      sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
      encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
    };
    // VOICE_COMMUNICATION enables the platform echo canceller, so the agent doesn't hear itself.
    const capturerInfo: audio.AudioCapturerInfo = { source: audio.SourceType.SOURCE_TYPE_VOICE_COMMUNICATION,
      capturerFlags: 0 };
    const options: audio.AudioCapturerOptions = { streamInfo: streamInfo, capturerInfo: capturerInfo };
    const capturer: audio.AudioCapturer = await audio.createAudioCapturer(options);
    try {
      capturer.on('readData', (buffer: ArrayBuffer) => {
        if (!this.muted && this.status === 'LIVE') {
          const ev: AppendEvent = { type: 'input_audio_buffer.append',
            audio: this.base64.encodeToStringSync(new Uint8Array(buffer)) };
          this.send(JSON.stringify(ev));
        }
      });
    } catch (e) {
      await capturer.release();
      throw new Error(`readData listener failed: ${String(e)}`);
    }
    this.capturer = capturer;
    await capturer.start();
  }

  // ---- plumbing ------------------------------------------------------------------------------------------------

  private send(data: string): void {
    const ws: webSocket.WebSocket | undefined = this.ws;
    if (ws === undefined) {
      return;
    }
    ws.send(data).catch((err: BusinessError) => log.warn(`send failed: ${err.code} ${err.message}`));
  }

  private fail(reason: string): boolean {
    log.warn(`realtime unavailable: ${reason}`);
    this.teardown('FAILED');
    return false;
  }

  private async teardown(status: RealtimeStatus): Promise<void> {
    const capturer: audio.AudioCapturer | undefined = this.capturer;
    this.capturer = undefined;
    if (capturer !== undefined) {
      try {
        await capturer.stop();
        await capturer.release();
      } catch (e) {
        log.warn(`mic release failed: ${String(e)}`);
      }
    }
    await this.player.close();
    this.resetTurn();
    this.transcript = '';
    this.toolsThisResponse = 0;
    this.toolsRunning = 0;
    this.continueWhenToolsDone = false;
    this.setStatus(status);
  }

  private setStatus(s: RealtimeStatus): void {
    if (this.status !== s) {
      this.status = s;
      this.statusListeners.emit(s);
    }
  }
}
