// The agent conversation. Voice is the main way in: a live orb, the words of both sides written out as they are
// spoken, and the agent's tools shown as steps and cards (DESIGN.md §10.1a, §6.6a, §6.8). Typing is the second mode
// of the same thread. Speech, text and taps all go through AgentCore (SafetyGate first, then the model with
// deterministic tools). Cards come from deterministic tool payloads, never from model text.
//
// AgentPage (Routes.AGENT_CHAT) is the agent stage: a full-screen page pushed from the orb in the tab bar, the
// agent line on Today, or "Ask the agent" anywhere. AgentConversation is the only conversation in the app; its
// history lives in AgentCore, so the stage can be closed and reopened without losing the thread.

import { keepOnRestore } from '../model/Chat';
import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { AgentCore } from '../agent/AgentCore';
import { AgentPrompt } from '../agent/AgentPrompt';
import { MedicineScanFlow, ScanCandidate, ScanOutcome } from '../agent/MedicineScanFlow';
import { AgentReply, ChatRole, EmergencyPayload, ToolActivity, UiAction } from '../model/AgentTypes';
import { VoiceSession, VoiceStatus, VoiceTurn } from '../voice/VoiceSession';
import { VoiceInput } from '../voice/VoiceInput';
import { VoiceOutput } from '../voice/VoiceOutput';
import { RealtimeSession, RealtimeStatus, VoicePhase } from '../voice/RealtimeSession';
import { SosController } from '../emergency/SosController';
import { AskParam, Routes, SosParam } from '../common/Routes';
import { Config } from '../common/Config';
import { Logger } from '../common/Logger';
import { RoundIconButton, StatusStrip } from '../components/Common';
import { ToolStep, ToolUi, toolArg } from '../components/AgentCards';
import { stagePhase } from '../components/agent/AgentLogic';
import { VoiceStage } from '../components/agent/VoiceStage';
import { AgentCaptions, AgentMode, AgentThread, AgentWelcome, ChatItem } from '../components/agent/AgentThread';
import { Brief, HomeBrief } from '../components/agent/HomeBrief';
import { ChatBar, VoiceDock } from '../components/agent/AgentDock';

const log: Logger = new Logger('AgentPage');

@ComponentV2
export struct AgentConversation {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Param active: boolean = true;       // false while another page is in front of the stage
  @Event onClose: () => void = () => {
  };
  @Local line: string = HomeBrief.latest().line;   // the agent's sentence, same as on Today
  @Local showThread: boolean = false;  // voice mode: the full conversation instead of the live captions
  @Local elapsed: number = 0;          // seconds since the voice session started
  private clockTimer: number = -1;
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
    this.offs.push(HomeBrief.onChange((b: Brief) => {
      this.line = b.line;
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
    this.stopClock();
  }

  // "VOICE · 0:42": the clock runs while a voice session or a recording is on.
  @Monitor('phase', 'recording')
  onVoiceChange(m: IMonitor): void {
    if (this.voiceActive()) {
      if (this.clockTimer === -1) {
        this.elapsed = 0;
        this.clockTimer = setInterval((): void => {
          this.elapsed++;
        }, 1000);
      }
    } else {
      this.stopClock();
    }
  }

  private stopClock(): void {
    if (this.clockTimer !== -1) {
      clearInterval(this.clockTimer);
      this.clockTimer = -1;
    }
  }

  private elapsedText(): string {
    const sec: number = this.elapsed % 60;
    return `${Math.floor(this.elapsed / 60)}:${sec < 10 ? '0' : ''}${sec}`;
  }

  // Orb size: 168 until something is said, 120 above the captions, 84 above the full thread.
  private orbDim(): number {
    if (!this.hasThread()) {
      return 168;
    }
    return this.showThread ? 84 : 120;
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
    return stagePhase(this.busy, this.phase);
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

  // Live session, nothing said yet: the orb is the whole screen (DESIGN.md §10.1a). The dock stays.
  private immersive(): boolean {
    return this.mode === 'VOICE' && this.voiceActive() && !this.hasThread();
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

  // The system camera (its own UI, so the app holds no camera permission). Returns '' when the user backs out.
  // Throws when there is no camera to open (e.g. an emulator without one).
  private async takePhoto(): Promise<string> {
    const profile: cameraPicker.PickerProfile = new cameraPicker.PickerProfile();
    profile.cameraPosition = camera.CameraPosition.CAMERA_POSITION_BACK;
    const res: cameraPicker.PickerResult =
      await cameraPicker.pick(this.ctx(), [cameraPicker.PickerMediaType.PHOTO], profile);
    return res.resultCode === 0 ? res.resultUri : '';
  }

  private async choosePhoto(): Promise<string> {
    const opts: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    opts.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    opts.maxSelectNumber = 1;
    const res: photoAccessHelper.PhotoSelectResult = await new photoAccessHelper.PhotoViewPicker().select(opts);
    return res.photoUris.length > 0 ? res.photoUris[0] : '';
  }

  // Camera first; the gallery only when the camera cannot be opened.
  private async pickAndScan(): Promise<void> {
    let uri: string = '';
    try {
      uri = await this.takePhoto();
    } catch (e) {
      log.warn(`camera picker failed, opening the gallery: ${JSON.stringify(e)}`);
      try {
        uri = await this.choosePhoto();
      } catch (e2) {
        log.warn(`photo picker failed: ${JSON.stringify(e2)}`);
      }
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

  @Builder
  thread() {
    AgentThread({
      items: this.items,
      userLive: this.userLive,
      agentLive: this.agentLive,
      liveTools: this.liveTools,
      hearing: this.phase === 'HEARING',
      busy: this.busy,
      busyLabel: this.busyLabel,
      resolved: this.resolved,
      accepted: this.accepted,
      sosClosedAt: this.sosClosedAt,
      scroller: this.scroller,
      onSend: (text: string) => {
        this.send(text);
      },
      onResolve: (actionId: string, accepted: boolean) => {
        this.resolve(actionId, accepted);
      },
      onScan: () => {
        this.pickAndScan();
      },
      onOpenSos: (a: UiAction) => {
        this.openSos(a);
      },
      onPickCandidate: (c: ScanCandidate) => {
        this.pickCandidate(c);
      }
    })
      .layoutWeight(1)
  }

  @Builder
  captions() {
    AgentCaptions({
      items: this.items,
      userLive: this.userLive,
      agentLive: this.agentLive,
      liveTools: this.liveTools,
      hearing: this.phase === 'HEARING',
      busy: this.busy,
      busyLabel: this.busyLabel,
      resolved: this.resolved,
      accepted: this.accepted,
      sosClosedAt: this.sosClosedAt,
      onSend: (text: string) => {
        this.send(text);
      },
      onResolve: (actionId: string, accepted: boolean) => {
        this.resolve(actionId, accepted);
      },
      onScan: () => {
        this.pickAndScan();
      },
      onOpenSos: (a: UiAction) => {
        this.openSos(a);
      },
      onPickCandidate: (c: ScanCandidate) => {
        this.pickCandidate(c);
      }
    })
      .layoutWeight(1)
  }

  @Builder
  welcome() {
    AgentWelcome({
      mode: this.mode,
      line: this.line,
      onStarter: (label: Resource) => {
        this.send(this.str(label));
      },
      onOpen: (route: string) => {
        this.navStack.pushPathByName(route, null);
      }
    })
      .layoutWeight(1)
  }

  // Header: close (chevron down), then "VOICE · 0:42" while a session runs, else Chats and New chat.
  @Builder
  header() {
    Row({ space: 8 }) {
      RoundIconButton({
        icon: $r('app.media.ic_chevron_left'),
        angle: -90,
        label: $r('app.string.a11y_close'),
        onTap: () => {
          this.onClose();
        }
      })
      if (this.voiceActive()) {
        Text($r('app.string.agent_voice_clock', this.elapsedText()))
          .fontFamily('monospace')
          .fontSize($r('app.float.font_micro'))
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1.2)
          .fontColor($r('app.color.ink_3'))
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
        Blank().width($r('app.float.chip_height'))
      } else {
        Blank()
        Text($r('app.string.home_chats'))
          .fontSize($r('app.float.font_button'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .height($r('app.float.chip_height'))
          .padding({ left: 16, right: 16 })
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.border') })
          .borderRadius(22)
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
          .accessibilityText($r('app.string.a11y_chats'))
          .onClick(() => {
            this.navStack.pushPathByName(Routes.CHATS, null);
          })
        RoundIconButton({
          icon: $r('app.media.ic_plus'),
          label: $r('app.string.a11y_new_chat'),
          onTap: () => {
            this.showThread = false;
            AgentCore.get().newChat();
          }
        })
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
  }

  // "Show conversation" / "Hide conversation": captions and the full thread are two views of the same turns.
  @Builder
  threadToggle() {
    Row({ space: 6 }) {
      Image($r('app.media.ic_chevron_left'))
        .width(14)
        .height(14)
        .fillColor($r('app.color.ink_2'))
        .rotate({ angle: this.showThread ? -90 : 90 })
      Text(this.showThread ? $r('app.string.agent_hide_thread') : $r('app.string.agent_show_thread'))
        .fontSize($r('app.float.font_small'))
        .fontWeight(600)
        .fontColor($r('app.color.ink_2'))
    }
    .height($r('app.float.chip_height'))
    .padding({ left: 16, right: 16 })
    .accessibilityGroup(true)
    .onClick(() => {
      this.showThread = !this.showThread;
      this.toBottom();
    })
  }

  // A page pushed over the stage, or the stage being left: end live voice. The microphone never stays open unseen.
  @Monitor('active')
  onActiveChange(m: IMonitor): void {
    if (!this.active && (this.voiceActive() || RealtimeSession.get().getStatus() === 'CONNECTING')) {
      this.endVoice();
    }
  }

  build() {
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
        VoiceStage({
          phase: this.stage(),
          level: this.level,
          muted: this.muted,
          dim: this.orbDim(),
          full: this.immersive(),
          label: this.stageLabel(),
          onOrbTap: () => {
            if (this.phase === 'OFF' && !this.recording) {
              this.onMic();
            }
          }
        })
          .layoutWeight(this.immersive() ? 1 : 0)
      }
      if (!this.immersive()) {
        if (!this.hasThread()) {
          this.welcome()
        } else if (this.mode === 'CHAT' || this.showThread) {
          this.thread()
        } else {
          this.captions()
        }
        if (this.mode === 'VOICE' && this.hasThread()) {
          this.threadToggle()
        }
      }
      if (this.mode === 'VOICE') {
        VoiceDock({
          phase: this.phase,
          recording: this.recording,
          muted: this.muted,
          active: this.voiceActive(),
          onMic: () => {
            this.onMic();
          },
          onScan: () => {
            this.pickAndScan();
          },
          onEnd: () => {
            this.endVoice();
          },
          onKeyboard: () => {
            this.setMode('CHAT');
          }
        })
      } else {
        ChatBar({
          draft: this.draft,
          onDraft: (text: string) => {
            this.draft = text;
          },
          onSend: () => {
            this.send(this.draft);
          },
          onScan: () => {
            this.pickAndScan();
          },
          onVoice: () => {
            this.setMode('VOICE');
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg'))
  }
}

// Routes.AGENT_CHAT: the agent stage. Opened with an AskParam it sends that question straight away.
@ComponentV2
export struct AgentPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local shown: boolean = true;

  build() {
    NavDestination() {
      AgentConversation({
        active: this.shown,
        onClose: () => {
          this.navStack.pop();
        }
      })
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg'))
    .onShown(() => {
      this.shown = true;
    })
    .onHidden(() => {
      this.shown = false;
    })
    .onReady((ctx: NavDestinationContext) => {
      const p: Object | undefined = ctx.pathInfo.param as Object | undefined;
      if (p instanceof AskParam) {
        AgentPrompt.ask(p.question);
      }
    })
  }
}
