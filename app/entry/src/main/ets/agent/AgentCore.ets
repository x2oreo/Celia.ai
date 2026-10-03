// OWNER: Kaloyan — the agent loop. Runs on the device; the backend is a stateless model relay.
//
//   user text ─► SafetyGate ─(emergency)──────────────────────────► deterministic emergency reply
//                    │
//                    └─► /agent step ─► tool calls? ─► ToolRegistry (on-device) ─► /agent step … (≤ MAX_STEPS)
//                                             │
//                                             └─► final text ─► ResponseValidator ─► AgentReply
//   any failure (offline, timeout, bad JSON, contradiction) ─► deterministic fallback (OfflineAgent / VerdictText)
//
// Verdicts come from DrugChecker + ComboRules only. Writes need a confirm tap (resolveAction).

import { AgentReply, ChatMessage, QuickRepliesPayload, UiAction, EmergencyPayload } from '../model/AgentTypes';
import { Profile } from '../model/Profile';
import { Medication } from '../model/Medication';
import { VitalsAlert } from '../model/Vitals';
import { Listener, Listeners } from '../common/Listeners';
import { Logger } from '../common/Logger';
import { Config } from '../common/Config';
import { LocalStore } from '../data/LocalStore';
import { VitalsService } from '../vitals/VitalsService';
import { SafetyGate, GateResult } from '../safety/SafetyGate';
import { EmergencyNumbers } from '../safety/EmergencyNumbers';
import { AgentClient, RelayContext, RelayMessage, RelayRequest, RelayToolOutput } from './AgentClient';
import { RelayResponse, TextCheck, checkFinalText } from './ResponseValidator';
import { ToolRegistry } from './ToolRegistry';
import { PendingAction, TurnState, action } from './ToolTypes';
import { OfflineAgent } from './OfflineAgent';
import { VerdictCardPayload } from '../model/AgentTypes';
import { verdictText } from './VerdictText';
import { VitalsDigest } from './VitalsDigest';
import { EMERGENCY_COUNTDOWN_SEC } from './tools/ActionTools';

const log: Logger = new Logger('AgentCore');

const MAX_STEPS: number = 5;            // model calls per user turn
const HISTORY_FOR_MODEL: number = 12;   // recent text messages sent as conversation memory
const MAX_HISTORY: number = 100;
const CHECK_IN_TIMEOUT_MS: number = 60000;
const PENDING_TTL_MS: number = 10 * 60 * 1000;

export const QUICK_REPLY_OK: string = "I'm OK";
export const QUICK_REPLY_UNWELL: string = 'I feel unwell';

interface FallbackEvent {
  reason: string;
  tools: string[];
}

export class AgentCore {
  private static instance: AgentCore | undefined = undefined;

  private proactive: Listeners<AgentReply> = new Listeners<AgentReply>();
  private client: AgentClient = new AgentClient();
  private registry: ToolRegistry = new ToolRegistry();
  private history: ChatMessage[] = [];
  private pending: Map<string, PendingAction> = new Map<string, PendingAction>();
  private queue: Promise<void> = Promise.resolve();
  private checkInTimer: number = -1;
  private checkInPending: boolean = false;
  private started: boolean = false;

  static get(): AgentCore {
    if (AgentCore.instance === undefined) {
      AgentCore.instance = new AgentCore();
    }
    return AgentCore.instance;
  }

  // Call once at app start (EntryAbility). Subscribes to vitals alerts for proactive check-ins.
  start(): void {
    if (this.started) {
      return;
    }
    this.started = true;
    VitalsDigest.get().start();
    VitalsService.get().onAlert((a: VitalsAlert) => this.onVitalsAlert(a));
  }

  // Turns are serialised: a second message waits for the first reply.
  send(text: string): Promise<AgentReply> {
    const run: Promise<AgentReply> = this.queue.then((): Promise<AgentReply> => this.handle(text));
    this.queue = run.then((): void => {}, (): void => {});
    return run;
  }

  // Triggered by VitalsAlert. Returns an unsubscribe function.
  onProactive(cb: Listener<AgentReply>): () => void {
    return this.proactive.add(cb);
  }

  getHistory(): ChatMessage[] {
    return this.history.slice();
  }

  // Confirm-card tap (ADD_MED, SHARE_EMERGENCY_CARD). accepted=false means the user tapped Cancel.
  async resolveAction(actionId: string, accepted: boolean): Promise<AgentReply> {
    const p: PendingAction | undefined = this.pending.get(actionId);
    this.pending.delete(actionId);
    if (p === undefined || Date.now() - p.createdAt > PENDING_TTL_MS) {
      return this.say('That request has expired. Ask me again if you still want it.', [], false);
    }
    if (!accepted) {
      return this.say("Okay, I didn't change anything.", [], false);
    }
    if (p.kind === 'ADD_MED') {
      const med: Medication = await LocalStore.get().addMed(p.name, p.ingredient, p.dose);
      return this.say(`Added ${med.name}${med.dose !== '' ? ' ' + med.dose : ''} to your medicines.`, [], false);
    }
    return this.say('Choose where to share your emergency card.', [], false);
  }

  // Called by the emergency screen when the user cancels the countdown.
  emergencyCancelled(): void {
    this.cancelCheckIn();
    this.remember('assistant', 'Emergency call cancelled by the user.');
  }

  // ---- hooks for the realtime voice session (same tools, gate, validator and memory) ----------------------------

  async beginExternalTurn(): Promise<TurnState> {
    const turn: TurnState = new TurnState();
    await this.buildContext(turn);
    return turn;
  }

  async contextForVoice(): Promise<RelayContext> {
    return await this.buildContext(new TurnState());
  }

  runTool(name: string, argsJson: string, turn: TurnState): Promise<string> {
    return this.registry.run(name, argsJson, turn);
  }

  // A user utterance heard by the realtime session. EMERGENCY/UNWELL → caller must cancel the model response
  // and show triggerEmergency()'s reply. OK → check-in answered.
  noteUserUtterance(text: string): GateResult {
    const input: string = text.trim().slice(0, 2000);
    if (input.length === 0) {
      return 'NONE';
    }
    this.remember('user', input);
    const gate: GateResult = SafetyGate.classify(input, this.checkInPending);
    if (gate === 'OK') {
      this.cancelCheckIn();
    }
    return gate;
  }

  triggerEmergency(reason: string): Promise<AgentReply> {
    return this.emergency(reason);
  }

  // The model finished speaking. Validates what it said against this turn's verdicts and registers confirm cards.
  finishExternalTurn(turn: TurnState, transcript: string): AgentReply {
    const check: TextCheck = checkFinalText(transcript, turn.verdicts);
    if (check.issue !== 'NONE') {
      this.logFallback(`realtime_${check.issue}`, turn);
    }
    return this.finish(turn, check.text, check.issue !== 'NONE');
  }

  // ---------------------------------------------------------------------------------------------------------------

  private async handle(text: string): Promise<AgentReply> {
    const input: string = text.trim().slice(0, 2000);
    if (input.length === 0) {
      return this.say('I didn\'t catch that. Could you say it again?', [], true);
    }
    this.remember('user', input);
    try {
      const gate: GateResult = SafetyGate.classify(input, this.checkInPending);
      if (gate === 'EMERGENCY' || gate === 'UNWELL') {
        return await this.emergency(input);
      }
      if (gate === 'OK') {
        this.cancelCheckIn();
        return this.say('Glad you\'re OK. I\'ll keep an eye on your heart rate. Sit down and rest for a few minutes.',
          [], true);
      }
      return await this.runModelLoop(input);
    } catch (e) {
      log.error(`turn failed: ${String(e)}`);
      return await this.fallback(new TurnState(), input, 'exception');
    }
  }

  private async runModelLoop(input: string): Promise<AgentReply> {
    const turn: TurnState = new TurnState();
    const ctx: RelayContext = await this.buildContext(turn);
    const timeout: number = Config.AGENT_TIMEOUT_MS;

    const firstRequest: RelayRequest = { context: ctx, messages: this.recentMessages(), continuation: null };
    let res: RelayResponse | undefined = await this.client.step(firstRequest, timeout);
    let steps: number = 1;
    while (res !== undefined && res.toolCalls.length > 0 && steps < MAX_STEPS) {
      const outputs: RelayToolOutput[] = [];
      for (const call of res.toolCalls) {
        const output: string = await this.registry.run(call.name, call.arguments, turn);
        const o: RelayToolOutput = { callId: call.callId, output: output };
        outputs.push(o);
      }
      const next: RelayRequest = {
        context: ctx,
        messages: [],
        continuation: { previousResponseId: res.responseId, toolOutputs: outputs }
      };
      res = await this.client.step(next, timeout);
      steps++;
    }

    if (res === undefined) {
      return await this.fallback(turn, input, Config.hasBackend() ? 'model_unavailable' : 'no_backend');
    }
    if (res.toolCalls.length > 0) {
      return await this.fallback(turn, input, 'too_many_steps');
    }

    const check: TextCheck = checkFinalText(res.text, turn.verdicts);
    if (check.issue !== 'NONE') {
      await this.logFallback(check.issue, turn);
    }
    return this.finish(turn, check.text, check.issue !== 'NONE');
  }

  private finish(turn: TurnState, text: string, fallback: boolean): AgentReply {
    for (const p of turn.pending) {
      this.pending.set(p.id, p);
    }
    return this.say(text, turn.actions, fallback);
  }

  // Deterministic reply that keeps whatever the tools already produced this turn (verdict cards, confirm cards).
  private async fallback(turn: TurnState, input: string, reason: string): Promise<AgentReply> {
    await this.logFallback(reason, turn);
    if (turn.verdicts.length > 0) {
      const text: string = turn.verdicts.map((v: VerdictCardPayload) => verdictText(v)).join(' ');
      return this.finish(turn, text, true);
    }
    if (turn.actions.length > 0) {
      return this.finish(turn, 'Please continue on screen.', true);
    }
    const prefix: string = reason === 'no_backend' ? 'I\'m working offline.'
      : 'I can\'t reach my assistant service right now.';
    const offline: AgentReply = await OfflineAgent.answer(input, prefix);
    this.remember('assistant', offline.text);
    return offline;
  }

  private async emergency(reason: string): Promise<AgentReply> {
    this.cancelCheckIn();
    const profile: Profile | undefined = await LocalStore.get().getProfile();
    const num: string = EmergencyNumbers.current(profile?.country);
    const payload: EmergencyPayload = { reason: reason.slice(0, 200), emergencyNumber: num,
      countdownSec: EMERGENCY_COUNTDOWN_SEC };
    try {
      await LocalStore.get().logEvent('EMERGENCY', JSON.stringify(payload));
    } catch (e) {
      log.warn(`logEvent failed: ${String(e)}`);
    }
    return this.say(`This could be serious. Sit or lie down now. I'm calling ${num} in ${EMERGENCY_COUNTDOWN_SEC} ` +
      'seconds and alerting your emergency contacts — tap Cancel if you are OK.',
      [action('START_EMERGENCY', payload)], true);
  }

  // ---- proactive check-ins ----------------------------------------------------------------------------------------

  private onVitalsAlert(alert: VitalsAlert): void {
    if (alert.kind === 'WATCH_DISCONNECTED') {
      this.proactive.emit(this.say('Your watch disconnected, so I can\'t see your heart rate right now.', [], true));
      return;
    }
    const replies: QuickRepliesPayload = { options: [QUICK_REPLY_OK, QUICK_REPLY_UNWELL] };
    const detail: string = alert.message !== '' ? ` ${alert.message}` : '';
    const reply: AgentReply = this.say(
      `Your heart rate is ${Math.round(alert.hr)} bpm.${detail} Are you OK?`, [action('QUICK_REPLIES', replies)], true);
    this.cancelCheckIn();
    this.checkInPending = true;
    this.checkInTimer = setTimeout(() => {
      if (this.checkInPending) {
        log.warn('check-in unanswered — starting emergency flow');
        this.emergency('No answer to heart-rate check-in').then((r: AgentReply) => this.proactive.emit(r));
      }
    }, CHECK_IN_TIMEOUT_MS);
    this.proactive.emit(reply);
  }

  private cancelCheckIn(): void {
    this.checkInPending = false;
    if (this.checkInTimer !== -1) {
      clearTimeout(this.checkInTimer);
      this.checkInTimer = -1;
    }
  }

  // ---- helpers -----------------------------------------------------------------------------------------------------

  private async buildContext(turn: TurnState): Promise<RelayContext> {
    const profile: Profile | undefined = await LocalStore.get().getProfile();
    const meds: Medication[] = await LocalStore.get().listMeds();
    turn.genotype = profile !== undefined ? profile.genotype : 'UNKNOWN';
    turn.emergencyNumber = EmergencyNumbers.current(profile?.country);
    // De-identified: condition, genotype, ingredient names, vitals line. No names, phones or IDs.
    const ctx: RelayContext = {
      condition: profile !== undefined ? profile.condition : 'LQTS',
      genotype: turn.genotype,
      meds: meds.map((m: Medication) => m.ingredient !== '' ? m.ingredient : m.name),
      vitals: VitalsDigest.get().summary(Date.now()),
      emergencyNumber: turn.emergencyNumber,
      locale: EmergencyNumbers.locale()
    };
    return ctx;
  }

  private recentMessages(): RelayMessage[] {
    const recent: ChatMessage[] = this.history.slice(-HISTORY_FOR_MODEL);
    // The relay requires the first message to be a user message.
    while (recent.length > 0 && recent[0].role !== 'user') {
      recent.shift();
    }
    return recent.map((m: ChatMessage) => {
      const r: RelayMessage = { role: m.role, text: m.text.slice(0, 1500) };
      return r;
    });
  }

  private remember(role: 'user' | 'assistant', text: string): void {
    const m: ChatMessage = { role: role, text: text, ts: Date.now() };
    this.history.push(m);
    if (this.history.length > MAX_HISTORY) {
      this.history = this.history.slice(-MAX_HISTORY);
    }
  }

  private say(text: string, actions: UiAction[], fallback: boolean): AgentReply {
    this.remember('assistant', text);
    const r: AgentReply = { text: text, actions: actions, fallback: fallback };
    return r;
  }

  private async logFallback(reason: string, turn: TurnState): Promise<void> {
    log.warn(`fallback: ${reason} tools=${turn.toolsUsed.join(',')}`);
    const e: FallbackEvent = { reason: reason, tools: turn.toolsUsed };
    try {
      await LocalStore.get().logEvent('AGENT_FALLBACK', JSON.stringify(e));
    } catch (err) {
      log.warn(`logEvent failed: ${String(err)}`);
    }
  }
}
