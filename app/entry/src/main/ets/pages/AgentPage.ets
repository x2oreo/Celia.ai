// Agent chat (design B2), a pushed page: Text, push-to-talk and live voice all go through AgentCore (SafetyGate first, then
// the model with deterministic tools). The cards under a reply come from deterministic data, never from model
// text: verdict, confirm-before-write, quick replies, emergency hand-off to the SOS screen, box scan.

import { common } from '@kit.AbilityKit';
import { LengthMetrics } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { AgentCore, QUICK_REPLY_UNWELL } from '../agent/AgentCore';
import { AgentPrompt } from '../agent/AgentPrompt';
import { MedicineScanFlow, ScanCandidate, ScanOutcome } from '../agent/MedicineScanFlow';
import { AddMedPayload, AgentReply, ChatMessage, ChatRole, ConfirmPayload, EmergencyPayload, InteractionFinding,
  QuickRepliesPayload, UiAction, VerdictCardPayload } from '../model/AgentTypes';
import { VoiceSession, VoiceStatus, VoiceTurn } from '../voice/VoiceSession';
import { RealtimeSession, RealtimeStatus } from '../voice/RealtimeSession';
import { SosController } from '../emergency/SosController';
import { CheckParam, Routes, SosParam, TabIndex } from '../common/Routes';
import { TabRequest } from '../common/TabRequest';
import { Config } from '../common/Config';
import { Logger } from '../common/Logger';
import { DrugVerdict, RiskLevel } from '../model/DrugVerdict';
import { InkButton, QuickReplyChip, SecondaryButton, SourceBadge, StatusStrip, TypingDots } from '../components/Common';
import { AgentAvatar } from '../components/AgentAvatar';
import { VerdictCard } from '../components/VerdictCard';

const log: Logger = new Logger('AgentPage');

class ChatItem {
  id: number;
  role: ChatRole;
  text: string;
  actions: UiAction[];
  candidates: ScanCandidate[];
  ts: number = Date.now();

  constructor(id: number, role: ChatRole, text: string, actions: UiAction[], candidates: ScanCandidate[]) {
    this.id = id;
    this.role = role;
    this.text = text;
    this.actions = actions;
    this.candidates = candidates;
  }
}

@ComponentV2
export struct AgentPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local items: ChatItem[] = [];
  @Local draft: string = '';
  @Local busy: boolean = false;
  @Local busyLabel: ResourceStr = $r('app.string.agent_thinking');
  @Local listening: boolean = false;
  @Local live: RealtimeStatus = 'IDLE';
  @Local resolved: string[] = [];    // actionIds of confirm cards already answered
  @Local sosClosedAt: number = 0;    // last time the SOS countdown was cancelled
  private nextId: number = 1;
  private voiceReady: boolean = false;
  private scroller: Scroller = new Scroller();
  private offs: (() => void)[] = [];

  aboutToAppear(): void {
    const history: ChatMessage[] = AgentCore.get().getHistory();
    for (const m of history) {
      this.push(m.role, m.text, [], []);
    }
    this.offs.push(AgentCore.get().onProactive((r: AgentReply) => {
      // Index opens the SOS screen for proactive emergencies; here we only show the message.
      this.push('assistant', r.text, r.actions, []);
    }));
    this.offs.push(AgentCore.get().onEmergencyClosed((ts: number) => {
      this.sosClosedAt = ts;
    }));
    this.offs.push(RealtimeSession.get().onStatus((s: RealtimeStatus) => {
      this.live = s;
    }));
    this.offs.push(RealtimeSession.get().onUserTranscript((t: string) => {
      this.push('user', t, [], []);
    }));
    this.offs.push(RealtimeSession.get().onReply((r: AgentReply) => {
      this.showReply(r);
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
  }

  private ctx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private push(role: ChatRole, text: string, actions: UiAction[], candidates: ScanCandidate[]): void {
    if (text.trim().length === 0 && actions.length === 0 && candidates.length === 0) {
      return;
    }
    const next: ChatItem[] = this.items.slice();
    next.push(new ChatItem(this.nextId++, role, text, actions, candidates));
    this.items = next;
    setTimeout((): void => this.scroller.scrollEdge(Edge.Bottom), 50);
  }

  // A reply to something the user did (typed, spoken, tapped). Emergencies hand over to the SOS screen.
  private showReply(r: AgentReply): void {
    this.push('assistant', r.text, r.actions, []);
    const emergency: UiAction | undefined = r.actions.find((a: UiAction) => a.type === 'START_EMERGENCY');
    if (emergency !== undefined) {
      this.openSos(emergency);
    }
  }

  private openSos(a: UiAction): void {
    if (SosController.get().state === 'COUNTDOWN') {
      return;
    }
    const p: EmergencyPayload = JSON.parse(a.payload) as EmergencyPayload;
    this.navStack.pushPathByName(Routes.SOS, new SosParam(false, p.reason, false));
  }

  private async send(text: string): Promise<void> {
    const t: string = text.trim();
    if (t.length === 0) {
      return;
    }
    this.draft = '';
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
    this.showReply(await AgentCore.get().resolveAction(actionId, accepted));
  }

  // ---- voice ---------------------------------------------------------------------------------------------------

  private async ensureVoice(): Promise<boolean> {
    if (!this.voiceReady) {
      const s: VoiceStatus = await VoiceSession.get().init(this.ctx(), false);
      this.voiceReady = s.input !== 'UNAVAILABLE';
    }
    if (!this.voiceReady) {
      this.push('assistant', this.str($r('app.string.agent_mic_unavailable')), [], []);
    }
    return this.voiceReady;
  }

  private async micDown(): Promise<void> {
    if (this.busy || this.live === 'LIVE' || !(await this.ensureVoice())) {
      return;
    }
    this.listening = await VoiceSession.get().startTalking();
  }

  private async micUp(): Promise<void> {
    if (!this.listening) {
      return;
    }
    this.listening = false;
    this.busy = true;
    this.busyLabel = $r('app.string.agent_thinking');
    try {
      const turn: VoiceTurn = await VoiceSession.get().stopTalking();
      if (turn.transcript.length > 0) {
        this.push('user', turn.transcript, [], []);
      }
      if (turn.reply !== undefined) {
        this.showReply(turn.reply);
      }
    } finally {
      this.busy = false;
    }
  }

  private async toggleLive(): Promise<void> {
    if (this.live === 'LIVE' || this.live === 'CONNECTING') {
      await RealtimeSession.get().stop();
      return;
    }
    if (!(await this.ensureVoice())) {
      return;
    }
    const ok: boolean = await RealtimeSession.get().start();
    if (!ok) {
      this.push('assistant', this.str($r('app.string.agent_live_failed')), [], []);
    }
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

  @Builder
  confirmCard(title: ResourceStr, detail: string, actionId: string) {
    Column({ space: 10 }) {
      Text(title)
        .fontSize($r('app.float.font_headline'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
      if (detail !== '') {
        Text(detail)
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink_2'))
      }
      if (!this.resolved.includes(actionId)) {
        Row({ space: 8 }) {
          InkButton({
            label: $r('app.string.agent_confirm'),
            onTap: () => {
              this.resolve(actionId, true);
            }
          })
            .layoutWeight(1)
          SecondaryButton({
            label: $r('app.string.agent_cancel'),
            onTap: () => {
              this.resolve(actionId, false);
            }
          })
            .layoutWeight(1)
        }
        .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .borderRadius($r('app.float.radius_ml'))
    .border({ width: 1, color: $r('app.color.border') })
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
      this.confirmCard($r('app.string.agent_add_med_title'),
        `${this.addMed(a).name} ${this.addMed(a).dose}`.trim(),
        this.addMed(a).actionId)
    } else if (a.type === 'SHARE_EMERGENCY_CARD') {
      this.confirmCard($r('app.string.agent_share_card_title'), '', (JSON.parse(a.payload) as ConfirmPayload).actionId)
    } else if (a.type === 'START_EMERGENCY') {
      Row({ space: 8 }) {
        Text(ts > this.sosClosedAt ? $r('app.string.agent_emergency_started') : $r('app.string.agent_emergency_cancelled'))
          .fontSize($r('app.float.font_small'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.risk_known_text'))
          .layoutWeight(1)
        if (ts > this.sosClosedAt) {
          QuickReplyChip({
            label: $r('app.string.agent_open_sos'),
            chipStyle: 'ESCALATION',
            onTap: () => {
              this.openSos(a);
            }
          })
        }
      }
      .width('100%')
    } else if (a.type === 'SHOW_EMERGENCY_CARD') {
      QuickReplyChip({
        label: $r('app.string.agent_open_card'),
        onTap: () => {
          this.navStack.clear();
          TabRequest.open(TabIndex.EMERGENCY);
        }
      })
    } else if (a.type === 'OPEN_MED_SCAN') {
      QuickReplyChip({
        label: $r('app.string.agent_scan'),
        icon: $r('app.media.ic_camera'),
        onTap: () => {
          this.pickAndScan();
        }
      })
    }
  }

  // User turns are ink bubbles with the tail bottom-right. The agent speaks in plain text, no bubble.
  @Builder
  bubble(item: ChatItem) {
    Column({ space: 10 }) {
      if (item.text.length > 0) {
        if (item.role === 'user') {
          Text(item.text)
            .fontSize($r('app.float.font_button'))
            .lineHeight(22)
            .fontColor($r('app.color.chat_user_text'))
            .padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .backgroundColor($r('app.color.chat_user_bg'))
            .borderRadius({ topLeft: 20, topRight: 20, bottomRight: 6, bottomLeft: 20 })
            .constraintSize({ maxWidth: '82%' })
            .copyOption(CopyOptions.LocalDevice)
        } else {
          Text(item.text)
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Medium)
            .lineHeight(23)
            .fontColor($r('app.color.ink'))
            .constraintSize({ maxWidth: '92%' })
            .copyOption(CopyOptions.LocalDevice)
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
  welcome() {
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
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center,
        space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
        this.starter($r('app.string.agent_starter_ibuprofen'))
        this.starter($r('app.string.agent_starter_avoid'))
        this.starter($r('app.string.agent_starter_meds'))
      }
    }
    .width('100%')
    .padding({ top: 40, left: 8, right: 8 })
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
  }

  build() {
    NavDestination() {
      Column() {
        // Header: back, orb, name, technical badge, live voice
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
          AgentAvatar({ dim: 40 })
          Text($r('app.string.agent_name'))
            .fontSize($r('app.float.font_subtitle'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
            .layoutWeight(1)
          if (!Config.hasBackend()) {
            SourceBadge({ label: $r('app.string.badge_on_device') })
          }
          Stack() {
            this.roundButton($r('app.media.ic_wave'), this.live === 'LIVE', $r('app.string.a11y_live'))
          }
          .onClick(() => {
            this.toggleLive();
          })
        }
        .width('100%')
        .padding({ left: 4, right: 16, top: 8, bottom: 8 })

        if (!Config.hasBackend()) {
          StatusStrip({ label: $r('app.string.agent_offline') })
            .padding({ left: 20, right: 20, bottom: 8 })
        } else if (this.live === 'LIVE' || this.live === 'CONNECTING') {
          StatusStrip({
            label: this.live === 'LIVE' ? $r('app.string.agent_live_on') : $r('app.string.agent_live_connecting')
          })
            .padding({ left: 20, right: 20, bottom: 8 })
        }

        // Thread
        List({ space: 16, scroller: this.scroller }) {
          if (this.items.length === 0) {
            ListItem() {
              this.welcome()
            }
          }
          ForEach(this.items, (item: ChatItem) => {
            ListItem() {
              this.bubble(item)
            }
          }, (item: ChatItem) => `${item.id}`)
          if (this.busy || this.listening) {
            ListItem() {
              Row({ space: 10 }) {
                AgentAvatar({ dim: 28 })
                TypingDots({ label: this.listening ? $r('app.string.agent_listening') : this.busyLabel })
              }
            }
          }
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 20, right: 20 })
        .contentEndOffset(12)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)

        // Input bar: camera, pill input, mic (send when there is text)
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
              this.roundButton($r('app.media.ic_mic'), true, $r('app.string.a11y_mic'))
            }
            .scale({ x: this.listening ? 1.12 : 1, y: this.listening ? 1.12 : 1 })
            .animation({ duration: 150, curve: Curve.EaseOut })
            .onTouch((e: TouchEvent) => {
              if (e.type === TouchType.Down) {
                this.micDown();
              } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
                this.micUp();
              }
            })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 12 })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg'))
  }
}
