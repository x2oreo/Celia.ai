// The agent conversation, a pushed page. Voice is the main way in: a live orb, the words of both sides written out
// as they are spoken, and the agent's tools shown as steps and cards (DESIGN.md §10.1 B2, §6.6a, §6.8). Typing is
// the second mode of the same thread. Speech, text and taps all go through AgentCore (SafetyGate first, then the
// model with deterministic tools). Cards come from deterministic tool payloads, never from model text.

import { keepOnRestore } from '../model/Chat';
import { common } from '@kit.AbilityKit';
import { LengthMetrics } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { AgentCore, QUICK_REPLY_UNWELL } from '../agent/AgentCore';
import { AgentPrompt } from '../agent/AgentPrompt';
import { MedicineScanFlow, ScanCandidate, ScanOutcome } from '../agent/MedicineScanFlow';
import {
  AddMedPayload, AgentReply, AlternativesPayload, ChatMessage, ChatRole, ConfirmPayload, EmergencyPayload,
  InteractionFinding, MedsPayload, QuickRepliesPayload, ToolActivity, UiAction, VerdictCardPayload, OpenPagePayload
} from '../model/AgentTypes';
import { VoiceSession, VoiceStatus, VoiceTurn } from '../voice/VoiceSession';
import { VoiceInput } from '../voice/VoiceInput';
import { VoiceOutput } from '../voice/VoiceOutput';
import { RealtimeSession, RealtimeStatus, VoicePhase } from '../voice/RealtimeSession';
import { SosController } from '../emergency/SosController';
import { AskParam, CheckParam, DoctorPrepParam, Routes, SosParam, TabIndex } from '../common/Routes';
import { TabRequest } from '../common/TabRequest';
import { Config } from '../common/Config';
import { Logger } from '../common/Logger';
import { DrugVerdict, RiskLevel } from '../model/DrugVerdict';
import { QuickReplyChip, SourceBadge, StatusStrip, TypingDots } from '../components/Common';
import { AgentAvatar } from '../components/AgentAvatar';
import { VoiceOrb } from '../components/VoiceOrb';
import { VerdictCard } from '../components/VerdictCard';
import {
  ActionTile, AlternativesCard, ConfirmCard, ConfirmState, EmergencyNotice, MedsCard, ToolStep, ToolStepRow, ToolUi,
  toolArg
} from '../components/AgentCards';

const log: Logger = new Logger('AgentPage');

type AgentMode = 'VOICE' | 'CHAT';

const ORB_DIM: number = 168;
const ORB_DIM_COMPACT: number = 84;
const STAGE_OPEN: number = 264;      // orb at full size, nothing said yet
const STAGE_COMPACT: number = 124;   // orb at half size above the conversation
const STAGE_MS: number = 320;

class ChatItem {
  id: number;
  role: ChatRole;
  text: string;
  actions: UiAction[];
  candidates: ScanCandidate[];
  tools: ToolStep[];
  ts: number = Date.now();

  constructor(id: number, role: ChatRole, text: string, actions: UiAction[], candidates: ScanCandidate[],
    tools: ToolStep[]) {
    this.id = id;
    this.role = role;
    this.text = text;
    this.actions = actions;
    this.candidates = candidates;
    this.tools = tools;
  }
}

@ComponentV2
export struct AgentPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local mode: AgentMode = 'VOICE';
  @Local items: ChatItem[] = [];
  @Local draft: string = '';
  @Local busy: boolean = false;
  @Local busyLabel: ResourceStr = $r('app.string.agent_thinking');
  @Local phase: VoicePhase = 'OFF';
  @Local level: number = 0;
  @Local userLive: string = '';        // the user's words while they are still being recognised
  @Local agentLive: string = '';       // the agent's words while it is still speaking
  @Local liveTools: ToolStep[] = [];   // tools of the turn in progress
  @Local muted: boolean = false;
  @Local tapMode: boolean = false;     // live voice unavailable: tap, speak, tap again to send
  @Local recording: boolean = false;
  @Local micBlocked: boolean = false;
  @Local resolved: string[] = [];      // actionIds of confirm cards already answered
  @Local accepted: string[] = [];      // of those, the confirmed ones
  @Local sosClosedAt: number = 0;      // last time the SOS countdown was cancelled
  private nextId: number = 1;
  private voiceReady: boolean = false;
  private scroller: Scroller = new Scroller();
  private offs: (() => void)[] = [];

  aboutToAppear(): void {
    this.loadChat();
    // Another chat was opened (Chats page), a new one started (button, "new chat", start_new_chat tool) or the last
    // chat finished loading at app start: show that chat.
    this.offs.push(AgentCore.get().onChatChanged((id: number) => {
      this.loadChat();
    }));
    this.offs.push(AgentCore.get().onProactive((r: AgentReply) => {
      // Index opens the SOS screen for proactive emergencies; here we only show the message.
      this.push('assistant', r.text, r.actions, []);
    }));
    this.offs.push(AgentCore.get().onEmergencyClosed((ts: number) => {
      this.sosClosedAt = ts;
    }));
    this.offs.push(AgentCore.get().onToolActivity((t: ToolActivity) => {
      this.onTool(t);
    }));
    this.offs.push(RealtimeSession.get().onStatus((s: RealtimeStatus) => {
      if (s !== 'LIVE' && s !== 'CONNECTING') {
        this.muted = false;
        this.level = 0;
      }
    }));
    this.offs.push(RealtimeSession.get().onPhase((p: VoicePhase) => {
      if (!this.recording) {
        this.phase = p;
      }
    }));
    this.offs.push(RealtimeSession.get().onLevel((v: number) => {
      this.level = v;
    }));
    this.offs.push(RealtimeSession.get().onUserPartial((t: string) => {
      this.userLive = t;
      this.toBottom();
    }));
    this.offs.push(RealtimeSession.get().onAgentPartial((t: string) => {
      this.agentLive = t;
      this.toBottom();
    }));
    this.offs.push(RealtimeSession.get().onUserTranscript((t: string) => {
      this.push('user', t, [], []);
    }));
    this.offs.push(RealtimeSession.get().onReply((r: AgentReply) => {
      this.showReply(r);
    }));
    this.offs.push(VoiceInput.get().onPartial((t: string) => {
      this.userLive = t;
      this.toBottom();
    }));
    this.offs.push(VoiceInput.get().onLevel((v: number) => {
      this.level = v;
    }));
    this.offs.push(VoiceOutput.get().onSpeaking((on: boolean) => {
      if (this.tapMode && !this.recording) {
        this.phase = on ? 'SPEAKING' : 'OFF';
      }
    }));
    this.offs.push(AgentPrompt.onAsk((q: string) => {
      this.send(q);
    }));
    for (const q of AgentPrompt.drain()) {
      this.send(q);
    }
  }

  aboutToDisappear(): void {
    for (const off of this.offs) {
      off();
    }
    this.offs = [];
    this.endVoice();
  }

  // Rebuilds the thread from the open chat. Restored chats carry display cards only (no confirm or SOS cards).
  private loadChat(): void {
    this.items = [];
    this.liveTools = [];
    this.userLive = '';
    this.agentLive = '';
    this.resolved = [];
    this.accepted = [];
    // Confirm, quick-reply and SOS cards belong to the moment they were shown; redrawing them would make an
    // already answered card look actionable again (the page's resolved/accepted state is reset above).
    for (const m of AgentCore.get().getHistory()) {
      this.push(m.role, m.text, (m.actions ?? []).filter((a: UiAction) => keepOnRestore(a)), []);
    }
  }

  // Header "New chat": the open chat is already saved; stop any live voice and start empty.
  private startNewChat(): void {
    if (this.busy) {
      return;   // the reply in flight belongs to this chat; New chat waits for it
    }
    this.endVoice();
    AgentCore.get().newChat();
  }

  private ctx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private toBottom(): void {
    setTimeout((): void => this.scroller.scrollEdge(Edge.Bottom), 50);
  }

  private push(role: ChatRole, text: string, actions: UiAction[], candidates: ScanCandidate[],
    tools: ToolStep[] = []): void {
    if (text.trim().length === 0 && actions.length === 0 && candidates.length === 0 && tools.length === 0) {
      return;
    }
    const next: ChatItem[] = this.items.slice();
    next.push(new ChatItem(this.nextId++, role, text, actions, candidates, tools));
    this.items = next;
    this.toBottom();
  }

  // A reply to something the user did (typed, spoken, tapped). The tools that ran for it stay on the turn.
  // Emergencies hand over to the SOS screen.
  private showReply(r: AgentReply): void {
    const tools: ToolStep[] = this.liveTools.map((t: ToolStep) => new ToolStep(t.id, t.name, t.arg, true));
    this.liveTools = [];
    this.agentLive = '';
    this.push('assistant', r.text, r.actions, [], tools);
    const emergency: UiAction | undefined = r.actions.find((a: UiAction) => a.type === 'START_EMERGENCY');
    if (emergency !== undefined) {
      this.openSos(emergency);
    }
  }

  private onTool(t: ToolActivity): void {
    const arg: string = toolArg(t.args);
    const step: ToolStep = new ToolStep(t.id, t.name, arg !== '' ? arg : this.str($r('app.string.tool_this_medicine')),
      t.done);
    const next: ToolStep[] = this.liveTools.filter((s: ToolStep) => s.id !== t.id);
    next.push(step);
    next.sort((a: ToolStep, b: ToolStep) => a.id - b.id);
    this.liveTools = next;
    this.toBottom();
  }

  private openSos(a: UiAction): void {
    if (SosController.get().state === 'COUNTDOWN') {
      return;
    }
    const p: EmergencyPayload = JSON.parse(a.payload) as EmergencyPayload;
    this.navStack.pushPathByName(Routes.SOS, new SosParam(false, p.reason, false));
  }

  // Typed text, a starter or a quick reply. While the voice session is live the agent answers out loud.
  private async send(text: string): Promise<void> {
    const t: string = text.trim();
    if (t.length === 0) {
      return;
    }
    this.draft = '';
    if (RealtimeSession.get().getStatus() === 'LIVE') {
      RealtimeSession.get().sendText(t);
      return;
    }
    this.push('user', t, [], []);
    this.busy = true;
    this.busyLabel = $r('app.string.agent_thinking');
    try {
      this.showReply(await AgentCore.get().send(t));
    } finally {
      this.busy = false;
    }
  }

  private async resolve(actionId: string, accepted: boolean): Promise<void> {
    const r: string[] = this.resolved.slice();
    r.push(actionId);
    this.resolved = r;
    if (accepted) {
      const a: string[] = this.accepted.slice();
      a.push(actionId);
      this.accepted = a;
    }
    this.showReply(await AgentCore.get().resolveAction(actionId, accepted));
  }

  private confirmState(actionId: string): ConfirmState {
    if (!this.resolved.includes(actionId)) {
      return 'OPEN';
    }
    return this.accepted.includes(actionId) ? 'ACCEPTED' : 'DECLINED';
  }

  // ---- voice ---------------------------------------------------------------------------------------------------

  private async ensureVoice(): Promise<boolean> {
    if (!this.voiceReady) {
      const s: VoiceStatus = await VoiceSession.get().init(this.ctx(), false);
      this.voiceReady = s.input !== 'UNAVAILABLE';
    }
    this.micBlocked = !this.voiceReady;
    return this.voiceReady;
  }

  private voiceActive(): boolean {
    return this.phase !== 'OFF' || this.recording;
  }

  // The one big button. Idle: start talking. Live: mute / unmute. Tap-to-talk: start, then send.
  private async onMic(): Promise<void> {
    if (this.phase === 'CONNECTING') {
      return;
    }
    if (RealtimeSession.get().getStatus() === 'LIVE') {
      this.muted = !this.muted;
      RealtimeSession.get().setMuted(this.muted);
      return;
    }
    if (this.recording) {
      await this.finishTalking();
      return;
    }
    if (this.busy || !(await this.ensureVoice())) {
      return;
    }
    if (!this.tapMode && Config.hasBackend()) {
      if (await RealtimeSession.get().start()) {
        return;
      }
      // Live voice failed: explain once, then the same button records a single question.
      this.tapMode = true;
      this.push('assistant', this.str($r('app.string.agent_live_failed')), [], []);
      return;
    }
    this.tapMode = true;
    await this.startTalking();
  }

  private async startTalking(): Promise<void> {
    this.userLive = '';
    this.recording = await VoiceSession.get().startTalking();
    if (this.recording) {
      this.phase = 'HEARING';
    } else {
      this.micBlocked = true;
    }
  }

  private async finishTalking(): Promise<void> {
    this.recording = false;
    this.phase = 'THINKING';
    this.level = 0;
    this.busy = true;
    this.busyLabel = $r('app.string.agent_thinking');
    try {
      const turn: VoiceTurn = await VoiceSession.get().stopTalking();
      this.userLive = '';
      if (turn.transcript.length > 0) {
        this.push('user', turn.transcript, [], []);
      }
      if (turn.reply !== undefined) {
        this.showReply(turn.reply);
      }
    } finally {
      this.busy = false;
      this.userLive = '';
      if (this.phase === 'THINKING') {
        this.phase = 'OFF';
      }
    }
  }

  private endVoice(): void {
    const s: RealtimeStatus = RealtimeSession.get().getStatus();
    if (s === 'LIVE' || s === 'CONNECTING') {
      RealtimeSession.get().stop();
    }
    if (this.recording) {
      VoiceSession.get().cancel();
      this.recording = false;
    }
    VoiceOutput.get().stop();
    this.phase = 'OFF';
    this.level = 0;
    this.muted = false;
    this.userLive = '';
  }

  private setMode(m: AgentMode): void {
    if (m === 'CHAT') {
      this.endVoice();
    }
    this.mode = m;
    this.toBottom();
  }

  // What the orb shows: the voice phase, or "thinking" while a typed or tapped turn is running.
  private stage(): VoicePhase {
    if (this.busy && (this.phase === 'OFF' || this.phase === 'LISTENING')) {
      return 'THINKING';
    }
    return this.phase;
  }

  private stageLabel(): ResourceStr {
    if (this.muted) {
      return $r('app.string.agent_voice_muted');
    }
    switch (this.stage()) {
      case 'CONNECTING':
        return $r('app.string.agent_voice_connecting');
      case 'LISTENING':
        return $r('app.string.agent_voice_listening');
      case 'HEARING':
        return this.recording ? $r('app.string.agent_listening') : $r('app.string.agent_voice_hearing');
      case 'THINKING':
        return this.runningTool() !== undefined ? ToolUi.label(this.runningTool() as ToolStep) : this.busyLabel;
      case 'SPEAKING':
        return $r('app.string.agent_voice_speaking');
      default:
        return $r('app.string.agent_voice_idle');
    }
  }

  private runningTool(): ToolStep | undefined {
    return this.liveTools.find((t: ToolStep) => !t.done);
  }

  private hasThread(): boolean {
    return this.items.length > 0 || this.userLive !== '' || this.agentLive !== '' || this.liveTools.length > 0 ||
      this.busy;
  }

  private str(r: Resource): string {
    try {
      return this.ctx().resourceManager.getStringSync(r.id);
    } catch (e) {
      return '';
    }
  }

  // ---- box scan ------------------------------------------------------------------------------------------------

  private async pickAndScan(): Promise<void> {
    let uri: string = '';
    try {
      const opts: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      opts.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      opts.maxSelectNumber = 1;
      const res: photoAccessHelper.PhotoSelectResult = await new photoAccessHelper.PhotoViewPicker().select(opts);
      uri = res.photoUris.length > 0 ? res.photoUris[0] : '';
    } catch (e) {
      log.warn(`photo picker failed: ${JSON.stringify(e)}`);
    }
    if (uri === '') {
      return;
    }
    this.busy = true;
    this.busyLabel = $r('app.string.agent_scan_reading');
    try {
      const file: fileIo.File = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      let pixelMap: image.PixelMap | undefined = undefined;
      try {
        pixelMap = await image.createImageSource(file.fd).createPixelMap();
      } finally {
        fileIo.closeSync(file);
      }
      const outcome: ScanOutcome = await MedicineScanFlow.scan(pixelMap);
      pixelMap.release();
      if (outcome.candidates.length === 0) {
        this.push('assistant', outcome.message, [], []);
      } else if (outcome.candidates.length === 1) {
        this.showReply(await MedicineScanFlow.confirmCandidate(outcome.candidates[0]));
      } else {
        this.push('assistant', this.str($r('app.string.agent_scan_pick')), [], outcome.candidates);
      }
    } catch (e) {
      log.warn(`scan failed: ${JSON.stringify(e)}`);
      this.push('assistant', "Couldn't read that box. Type the name instead?", [], []);
    } finally {
      this.busy = false;
    }
  }

  private async pickCandidate(c: ScanCandidate): Promise<void> {
    this.push('user', c.name, [], []);
    this.busy = true;
    try {
      this.showReply(await MedicineScanFlow.confirmCandidate(c));
    } finally {
      this.busy = false;
    }
  }

  // ---- builders ------------------------------------------------------------------------------------------------

  private vp(a: UiAction): VerdictCardPayload {
    return JSON.parse(a.payload) as VerdictCardPayload;
  }

  private addMed(a: UiAction): AddMedPayload {
    return JSON.parse(a.payload) as AddMedPayload;
  }

  // The card payload carries the deterministic verdict; the colour and word come from it, never from model text.
  private verdictOf(p: VerdictCardPayload): DrugVerdict {
    const brand: string = p.query.length > 0 ? p.query.charAt(0).toUpperCase() + p.query.slice(1) : p.query;
    const v: DrugVerdict = {
      query: brand,
      ingredient: p.ingredient,
      risk: p.combinedRisk as RiskLevel,
      reason: p.reason,
      source: p.source
    };
    return v;
  }

  @Builder
  verdictCard(a: UiAction) {
    Column({ space: 8 }) {
      VerdictCard({
        verdict: this.verdictOf(this.vp(a)),
        variant: 'INLINE',
        actionLabel: $r('app.string.agent_open_check'),
        onAction: () => {
          this.navStack.pushPathByName(Routes.CHECK_RESULT, new CheckParam(this.vp(a).query, false, 'CHAT'));
        }
      })
      if (this.vp(a).findings.length > 0) {
        Column({ space: 4 }) {
          Text($r('app.string.agent_findings'))
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.risk_possible_text'))
          ForEach(this.vp(a).findings, (f: InteractionFinding) => {
            Text(`• ${f.detail}`)
              .fontSize($r('app.float.font_small'))
              .fontColor($r('app.color.ink_2'))
          }, (f: InteractionFinding, i: number) => `${i}-${f.kind}`)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(12)
        .backgroundColor($r('app.color.risk_possible_tint'))
        .borderRadius($r('app.float.radius_s'))
      }
    }
    .width('100%')
  }

  private confirmId(a: UiAction): string {
    return (JSON.parse(a.payload) as ConfirmPayload).actionId;
  }

  @Builder
  actionView(a: UiAction, ts: number) {
    if (a.type === 'SHOW_VERDICT') {
      this.verdictCard(a)
    } else if (a.type === 'QUICK_REPLIES') {
      Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
        ForEach((JSON.parse(a.payload) as QuickRepliesPayload).options, (o: string) => {
          QuickReplyChip({
            label: o,
            chipStyle: o === QUICK_REPLY_UNWELL ? 'ESCALATION' : 'DEFAULT',
            onTap: () => {
              this.send(o);
            }
          })
        }, (o: string) => o)
      }
    } else if (a.type === 'ADD_MED') {
      ConfirmCard({
        icon: $r('app.media.ic_pill'),
        title: $r('app.string.agent_add_med_title'),
        detail: `${this.addMed(a).name} ${this.addMed(a).dose}`.trim(),
        risk: this.addMed(a).risk as RiskLevel,
        state: this.confirmState(this.addMed(a).actionId),
        onConfirm: () => {
          this.resolve(this.addMed(a).actionId, true);
        },
        onCancel: () => {
          this.resolve(this.addMed(a).actionId, false);
        }
      })
    } else if (a.type === 'SHARE_EMERGENCY_CARD') {
      ConfirmCard({
        icon: $r('app.media.ic_share'),
        title: $r('app.string.agent_share_card_title'),
        detail: $r('app.string.agent_share_card_sub'),
        state: this.confirmState(this.confirmId(a)),
        onConfirm: () => {
          this.resolve(this.confirmId(a), true);
        },
        onCancel: () => {
          this.resolve(this.confirmId(a), false);
        }
      })
    } else if (a.type === 'SHOW_MEDS') {
      MedsCard({
        meds: JSON.parse(a.payload) as MedsPayload,
        onOpen: () => {
          this.navStack.clear();
          TabRequest.open(TabIndex.MEDICINES);
        }
      })
    } else if (a.type === 'SHOW_ALTERNATIVES') {
      AlternativesCard({ alts: JSON.parse(a.payload) as AlternativesPayload })
    } else if (a.type === 'START_EMERGENCY') {
      EmergencyNotice({
        active: ts > this.sosClosedAt,
        onOpen: () => {
          this.openSos(a);
        }
      })
    } else if (a.type === 'SHOW_EMERGENCY_CARD') {
      ActionTile({
        icon: $r('app.media.ic_qr'),
        title: $r('app.string.agent_card_title'),
        subtitle: $r('app.string.agent_card_sub'),
        onTap: () => {
          this.navStack.clear();
          TabRequest.open(TabIndex.EMERGENCY);
        }
      })
    } else if (a.type === 'OPEN_MED_SCAN') {
      ActionTile({
        icon: $r('app.media.ic_camera'),
        title: $r('app.string.agent_scan'),
        subtitle: $r('app.string.agent_scan_sub'),
        onTap: () => {
          this.pickAndScan();
        }
      })
    } else if (a.type === 'OPEN_PAGE') {
      if (this.pagePayload(a).page === 'DOCTOR_PREP') {
        ActionTile({
          icon: $r('app.media.ic_doctor'),
          title: $r('app.string.home_doctor'),
          subtitle: $r('app.string.agent_open_brief_sub'),
          onTap: () => {
            this.navStack.pushPathByName(Routes.DOCTOR_PREP, new DoctorPrepParam(this.pagePayload(a).specialty));
          }
        })
      } else if (this.pagePayload(a).page === 'REMINDERS') {
        ActionTile({
          icon: $r('app.media.ic_bell'),
          title: $r('app.string.rem_title'),
          subtitle: $r('app.string.agent_open_reminders_sub'),
          onTap: () => {
            this.navStack.pushPathByName(Routes.REMINDERS, null);
          }
        })
      }
    }
  }

  private pagePayload(a: UiAction): OpenPagePayload {
    return JSON.parse(a.payload) as OpenPagePayload;
  }

  // The user's words: an ink bubble with the tail bottom-right. Dimmed while they are still being recognised.
  @Builder
  userBubble(text: string, live: boolean) {
    Row() {
      if (text.length > 0) {
        Text(text)
          .fontSize($r('app.float.font_button'))
          .lineHeight(22)
          .fontColor($r('app.color.chat_user_text'))
          .copyOption(live ? CopyOptions.None : CopyOptions.LocalDevice)
      } else {
        TypingDots()
      }
    }
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .constraintSize({ maxWidth: '82%', minHeight: 42 })
    .backgroundColor($r('app.color.chat_user_bg'))
    .borderRadius({ topLeft: 20, topRight: 20, bottomRight: 6, bottomLeft: 20 })
    .opacity(live ? 0.6 : 1)
  }

  // The agent speaks in plain text, no bubble.
  @Builder
  agentText(text: string) {
    Text(text)
      .fontSize($r('app.float.font_body'))
      .fontWeight(FontWeight.Medium)
      .lineHeight(23)
      .fontColor($r('app.color.ink'))
      .constraintSize({ maxWidth: '92%' })
      .copyOption(CopyOptions.LocalDevice)
  }

  @Builder
  toolSteps(tools: ToolStep[]) {
    ForEach(tools, (t: ToolStep) => {
      ToolStepRow({ step: t })
    }, (t: ToolStep) => `${t.id}-${t.done ? 1 : 0}`)
  }

  @Builder
  turn(item: ChatItem) {
    Column({ space: 10 }) {
      this.toolSteps(item.tools)
      if (item.text.length > 0) {
        if (item.role === 'user') {
          this.userBubble(item.text, false)
        } else {
          this.agentText(item.text)
        }
      }
      ForEach(item.actions, (a: UiAction) => {
        this.actionView(a, item.ts)
      }, (a: UiAction, i: number) => `${item.id}-${i}-${a.type}`)
      if (item.candidates.length > 0) {
        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
          ForEach(item.candidates, (c: ScanCandidate) => {
            QuickReplyChip({
              label: c.ingredient !== '' && c.ingredient !== c.name.toLowerCase() ? `${c.name} (${c.ingredient})` :
                c.name,
              onTap: () => {
                this.pickCandidate(c);
              }
            })
          }, (c: ScanCandidate) => c.name)
        }
      }
    }
    .width('100%')
    .alignItems(item.role === 'user' ? HorizontalAlign.End : HorizontalAlign.Start)
  }

  // The turn in progress: what the user is saying, the tools that are running, what the agent is saying.
  @Builder
  liveTurn() {
    if (this.userLive !== '' || this.phase === 'HEARING') {
      ListItem() {
        Column() {
          this.userBubble(this.userLive, true)
        }
        .width('100%')
        .alignItems(HorizontalAlign.End)
      }
    }
    if (this.liveTools.length > 0 || this.agentLive !== '' || this.busy) {
      ListItem() {
        Column({ space: 10 }) {
          this.toolSteps(this.liveTools)
          if (this.agentLive !== '') {
            this.agentText(this.agentLive)
          } else if (this.runningTool() === undefined && (this.busy || this.liveTools.length > 0)) {
            TypingDots({ label: this.busy ? this.busyLabel : '' })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
  }

  @Builder
  thread() {
    List({ space: 16, scroller: this.scroller }) {
      ForEach(this.items, (item: ChatItem) => {
        ListItem() {
          this.turn(item)
        }
      }, (item: ChatItem) => `${item.id}`)
      this.liveTurn()
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 20, right: 20 })
    .contentStartOffset(4)
    .contentEndOffset(12)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  starter(label: Resource) {
    QuickReplyChip({
      label: label,
      onTap: () => {
        this.send(this.str(label));
      }
    })
  }

  @Builder
  starters() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center,
      space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
      this.starter($r('app.string.agent_starter_ibuprofen'))
      this.starter($r('app.string.agent_starter_avoid'))
      this.starter($r('app.string.agent_starter_meds'))
    }
  }

  // Voice stage: the orb and what it is doing. Full size until something is said, then it steps back above the
  // conversation.
  @Builder
  voiceStage() {
    Column() {
      Stack() {
        VoiceOrb({
          dim: this.hasThread() ? ORB_DIM_COMPACT : ORB_DIM,
          phase: this.stage(),
          level: this.level,
          muted: this.muted
        })
      }
      .width('100%')
      .height(this.hasThread() ? STAGE_COMPACT : STAGE_OPEN)
      .animation({ duration: STAGE_MS, curve: Curve.EaseInOut })
      .accessibilityText($r('app.string.a11y_orb'))
      .onClick(() => {
        if (this.phase === 'OFF' && !this.recording) {
          this.onMic();
        }
      })

      Text(this.stageLabel())
        .fontSize(this.hasThread() ? $r('app.float.font_badge') : $r('app.float.font_title_3'))
        .fontWeight(FontWeight.Bold)
        .fontColor(this.hasThread() ? $r('app.color.ink_3') : $r('app.color.ink'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 20, right: 20 })

      if (Config.DEMO_VOICE_INPUT) {
        SourceBadge({ label: $r('app.string.demo_voice_badge') })
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .padding({ bottom: 12 })
  }

  @Builder
  voiceWelcome() {
    Column({ space: 20 }) {
      Text($r('app.string.agent_voice_idle_hint'))
        .fontSize($r('app.float.font_small'))
        .lineHeight(20)
        .fontColor($r('app.color.ink_3'))
        .textAlign(TextAlign.Center)
      this.starters()
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 20, right: 20 })
  }

  @Builder
  chatWelcome() {
    Column({ space: 20 }) {
      AgentAvatar({ dim: 96 })
      Text($r('app.string.agent_welcome_title'))
        .fontSize($r('app.float.font_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
      Text($r('app.string.agent_welcome'))
        .fontSize($r('app.float.font_small'))
        .lineHeight(20)
        .fontColor($r('app.color.ink_3'))
        .textAlign(TextAlign.Center)
      this.starters()
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ top: 40, left: 28, right: 28 })
  }

  @Builder
  roundButton(icon: Resource, filled: boolean, a11y: Resource) {
    Row() {
      Image(icon)
        .width(22)
        .height(22)
        .fillColor(filled ? $r('app.color.on_accent') : $r('app.color.ink'))
    }
    .width($r('app.float.touch_min'))
    .height($r('app.float.touch_min'))
    .justifyContent(FlexAlign.Center)
    .borderRadius(24)
    .backgroundColor(filled ? $r('app.color.brand_accent') : $r('app.color.surface'))
    .border({ width: filled ? 0 : 1, color: $r('app.color.border') })
    .accessibilityText(a11y)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
  }

  @Builder
  dockSide(icon: Resource, a11y: Resource) {
    Row() {
      Image(icon).width(22).height(22).fillColor($r('app.color.ink'))
    }
    .width($r('app.float.dock_side'))
    .height($r('app.float.dock_side'))
    .justifyContent(FlexAlign.Center)
    .borderRadius(26)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .accessibilityText(a11y)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
  }

  // Coral mic to talk; outlined with a struck mic when muted; ink "send" while a tap-to-talk question records.
  @Builder
  dockMic() {
    Row() {
      Image(this.recording ? $r('app.media.ic_send') : (this.muted ? $r('app.media.ic_mic_off') :
        $r('app.media.ic_mic')))
        .width(30)
        .height(30)
        .fillColor(this.recording ? $r('app.color.chat_user_text') : (this.muted ? $r('app.color.ink') :
          $r('app.color.on_accent')))
    }
    .width($r('app.float.dock_main'))
    .height($r('app.float.dock_main'))
    .justifyContent(FlexAlign.Center)
    .borderRadius(36)
    .backgroundColor(this.recording ? $r('app.color.chat_user_bg') : (this.muted ? $r('app.color.surface') :
      $r('app.color.brand_accent')))
    .border({ width: this.muted ? 1.5 : 0, color: $r('app.color.border_strong') })
    .opacity(this.phase === 'CONNECTING' ? 0.6 : 1)
    .accessibilityText(this.recording ? $r('app.string.a11y_send') : (this.muted ? $r('app.string.a11y_unmute') :
      (this.phase === 'OFF' ? $r('app.string.a11y_mic') : $r('app.string.a11y_mute'))))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
    .onClick(() => {
      this.onMic();
    })
  }

  // Voice dock: scan a box, talk, and either end the conversation or switch to typing.
  @Builder
  voiceDock() {
    Row() {
      Stack() {
        this.dockSide($r('app.media.ic_camera'), $r('app.string.a11y_camera'))
      }
      .onClick(() => {
        this.pickAndScan();
      })
      this.dockMic()
      if (this.voiceActive()) {
        Stack() {
          this.dockSide($r('app.media.ic_close'), $r('app.string.a11y_end'))
        }
        .onClick(() => {
          this.endVoice();
        })
      } else {
        Stack() {
          this.dockSide($r('app.media.ic_keyboard'), $r('app.string.a11y_keyboard'))
        }
        .onClick(() => {
          this.setMode('CHAT');
        })
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceEvenly)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 32, right: 32, top: 8, bottom: 20 })
  }

  // Chat input bar: camera, pill input, then send (when there is text) or back to voice.
  @Builder
  chatBar() {
    Row({ space: 8 }) {
      Stack() {
        this.roundButton($r('app.media.ic_camera'), false, $r('app.string.a11y_camera'))
      }
      .onClick(() => {
        this.pickAndScan();
      })
      TextInput({ text: this.draft, placeholder: $r('app.string.agent_input_hint') })
        .layoutWeight(1)
        .height($r('app.float.touch_min'))
        .borderRadius(24)
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.border') })
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.ink'))
        .placeholderColor($r('app.color.ink_4'))
        .enterKeyType(EnterKeyType.Send)
        .onChange((v: string) => {
          this.draft = v;
        })
        .onSubmit(() => {
          this.send(this.draft);
        })
      if (this.draft.trim().length > 0) {
        Stack() {
          this.roundButton($r('app.media.ic_send'), true, $r('app.string.a11y_send'))
        }
        .onClick(() => {
          this.send(this.draft);
        })
      } else {
        Stack() {
          this.roundButton($r('app.media.ic_wave'), true, $r('app.string.a11y_voice'))
        }
        .onClick(() => {
          this.setMode('VOICE');
        })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 12 })
  }

  @Builder
  headerButton(icon: Resource, label: Resource, onTap: () => void) {
    Row() {
      Image(icon).width(22).height(22).fillColor($r('app.color.ink_2'))
    }
    .width($r('app.float.touch_min'))
    .height($r('app.float.touch_min'))
    .justifyContent(FlexAlign.Center)
    .borderRadius(22)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.92 })
    .accessibilityText(label)
    .onClick(() => onTap())
  }

  @Builder
  header() {
    Row({ space: 10 }) {
      Row() {
        Image($r('app.media.ic_chevron_left')).width(24).height(24).fillColor($r('app.color.ink'))
      }
      .width($r('app.float.touch_min'))
      .height($r('app.float.touch_min'))
      .justifyContent(FlexAlign.Center)
      .accessibilityText($r('app.string.a11y_back'))
      .onClick(() => {
        this.navStack.pop();
      })
      if (this.mode === 'CHAT') {
        AgentAvatar({ dim: 40 })
      }
      Text($r('app.string.agent_name'))
        .fontSize($r('app.float.font_subtitle'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .layoutWeight(1)
      if (!Config.hasBackend()) {
        SourceBadge({ label: $r('app.string.badge_on_device') })
      }
      this.headerButton($r('app.media.ic_history'), $r('app.string.a11y_chats'), () => {
        this.navStack.pushPathByName(Routes.CHATS, null);
      })
      this.headerButton($r('app.media.ic_plus'), $r('app.string.a11y_new_chat'), () => {
        this.startNewChat();
      })
    }
    .width('100%')
    .padding({ left: 4, right: 8, top: 8, bottom: 8 })
  }

  build() {
    NavDestination() {
      Column() {
        this.header()

        if (this.micBlocked && this.mode === 'VOICE') {
          StatusStrip({
            kind: 'ERROR',
            label: $r('app.string.agent_voice_unavailable'),
            action: $r('app.string.agent_type_instead'),
            onAction: () => {
              this.setMode('CHAT');
            }
          })
            .padding({ left: 20, right: 20, bottom: 8 })
        } else if (!Config.hasBackend()) {
          StatusStrip({ label: $r('app.string.agent_offline') })
            .padding({ left: 20, right: 20, bottom: 8 })
        }

        if (this.mode === 'VOICE') {
          this.voiceStage()
          if (this.hasThread()) {
            this.thread()
          } else {
            this.voiceWelcome()
          }
          this.voiceDock()
        } else {
          if (this.hasThread()) {
            this.thread()
          } else {
            this.chatWelcome()
          }
          this.chatBar()
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg'))
    .onReady((ctx: NavDestinationContext) => {
      // Opened with a question (e.g. "Ask the agent" from a medicine): show it typed and send it once.
      const p: Object | undefined = ctx.pathInfo.param as Object | undefined;
      if (p instanceof AskParam && p.question.trim().length > 0) {
        this.setMode('CHAT');
        this.send(p.question);
      }
    })
  }
}
