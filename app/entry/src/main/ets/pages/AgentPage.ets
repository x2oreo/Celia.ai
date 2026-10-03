// Agent tab: chat with Celia. Text, push-to-talk and live voice all go through AgentCore (SafetyGate first, then
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
import { RiskLevel } from '../model/DrugVerdict';
import { VoiceSession, VoiceStatus, VoiceTurn } from '../voice/VoiceSession';
import { RealtimeSession, RealtimeStatus } from '../voice/RealtimeSession';
import { SosController } from '../emergency/SosController';
import { CheckParam, Routes, SosParam, TabIndex } from '../common/Routes';
import { Config } from '../common/Config';
import { Logger } from '../common/Logger';
import { RiskBadge } from '../components/Common';

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
  @Consumer('tabIndex') activeTab: number = TabIndex.AGENT;
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

  @Builder
  avatar(size: number) {
    Stack() {
      Circle().width(size).height(size).fill($r('app.color.brand_accent_soft'))
      Circle().width(size * 0.4).height(size * 0.4).fill($r('app.color.brand_accent'))
    }
    .width(size)
    .height(size)
  }

  @Builder
  chip(label: ResourceStr, escalation: boolean, onTap: () => void) {
    Text(label)
      .fontSize($r('app.float.font_small'))
      .fontWeight(escalation ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(escalation ? $r('app.color.risk_known') : $r('sys.color.font_primary'))
      .height(44)
      .padding({ left: 16, right: 16 })
      .borderRadius(22)
      .borderWidth(1.5)
      .borderColor(escalation ? $r('app.color.risk_known') : $r('app.color.divider'))
      .backgroundColor($r('app.color.card_bg'))
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
      .onClick(onTap)
  }

  @Builder
  inkButton(label: ResourceStr, filled: boolean, onTap: () => void) {
    Text(label)
      .fontSize($r('app.float.font_small'))
      .fontWeight(FontWeight.Bold)
      .fontColor(filled ? $r('app.color.chat_user_text') : $r('sys.color.font_primary'))
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(44)
      .borderRadius($r('app.float.radius_s'))
      .borderWidth(filled ? 0 : 1.5)
      .borderColor($r('app.color.divider'))
      .backgroundColor(filled ? $r('app.color.chat_user_bg') : $r('app.color.card_bg'))
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
      .onClick(onTap)
  }

  @Builder
  verdictCard(a: UiAction) {
    Column({ space: 8 }) {
      RiskBadge({ risk: this.vp(a).combinedRisk as RiskLevel })
      Text(this.verdictTitle(this.vp(a)))
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Text(this.vp(a).reason)
        .fontSize($r('app.float.font_small'))
        .fontColor($r('sys.color.font_secondary'))
        .lineHeight(20)
      if (this.vp(a).findings.length > 0) {
        Text($r('app.string.agent_findings'))
          .fontSize($r('app.float.font_caption'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_secondary'))
        ForEach(this.vp(a).findings, (f: InteractionFinding) => {
          Text(`• ${f.detail}`)
            .fontSize($r('app.float.font_small'))
            .fontColor($r('sys.color.font_primary'))
        }, (f: InteractionFinding, i: number) => `${i}-${f.kind}`)
      }
      Row() {
        this.inkButton($r('app.string.agent_open_check'), true, () => {
          this.navStack.pushPathByName(Routes.CHECK_RESULT, new CheckParam(this.vp(a).query, false, 'CHAT'));
        })
      }
      .width('100%')
      Text(this.vp(a).source + ' · ' + this.str($r('app.string.disclaimer')))
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('sys.color.font_tertiary'))
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(20)
    .borderWidth(1.5)
    .borderColor(this.riskBorder(this.vp(a).combinedRisk as RiskLevel))
  }

  private vp(a: UiAction): VerdictCardPayload {
    return JSON.parse(a.payload) as VerdictCardPayload;
  }

  private addMed(a: UiAction): AddMedPayload {
    return JSON.parse(a.payload) as AddMedPayload;
  }

  private verdictTitle(p: VerdictCardPayload): string {
    const brand: string = p.query.length > 0 ? p.query.charAt(0).toUpperCase() + p.query.slice(1) : p.query;
    if (p.ingredient === '' || p.ingredient === p.query.toLowerCase()) {
      return p.ingredient === '' ? brand : p.ingredient;
    }
    return `${brand} → ${p.ingredient}`;
  }

  private riskBorder(risk: RiskLevel): Resource {
    switch (risk) {
      case 'KNOWN_RISK':
        return $r('app.color.risk_known_soft');
      case 'POSSIBLE_RISK':
        return $r('app.color.risk_possible_soft');
      case 'CONDITIONAL_RISK':
        return $r('app.color.risk_conditional_soft');
      case 'NOT_LISTED':
        return $r('app.color.risk_not_listed_soft');
      default:
        return $r('app.color.risk_unknown_soft');
    }
  }

  @Builder
  confirmCard(title: ResourceStr, detail: string, actionId: string) {
    Column({ space: 10 }) {
      Text(title)
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      if (detail !== '') {
        Text(detail)
          .fontSize($r('app.float.font_small'))
          .fontColor($r('sys.color.font_secondary'))
      }
      if (!this.resolved.includes(actionId)) {
        Row({ space: 8 }) {
          this.inkButton($r('app.string.agent_confirm'), true, () => {
            this.resolve(actionId, true);
          })
          this.inkButton($r('app.string.agent_cancel'), false, () => {
            this.resolve(actionId, false);
          })
        }
        .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(20)
    .borderWidth(1)
    .borderColor($r('app.color.divider'))
  }

  @Builder
  actionView(a: UiAction, ts: number) {
    if (a.type === 'SHOW_VERDICT') {
      this.verdictCard(a)
    } else if (a.type === 'QUICK_REPLIES') {
      Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
        ForEach((JSON.parse(a.payload) as QuickRepliesPayload).options, (o: string) => {
          this.chip(o, o === QUICK_REPLY_UNWELL, () => {
            this.send(o);
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
          .fontColor($r('app.color.risk_known'))
          .layoutWeight(1)
        if (ts > this.sosClosedAt) {
          this.chip($r('app.string.agent_open_sos'), true, () => {
            this.openSos(a);
          })
        }
      }
      .width('100%')
    } else if (a.type === 'SHOW_EMERGENCY_CARD') {
      this.chip($r('app.string.agent_open_card'), false, () => {
        this.activeTab = TabIndex.EMERGENCY;
      })
    } else if (a.type === 'OPEN_MED_SCAN') {
      this.chip($r('app.string.agent_scan'), false, () => {
        this.pickAndScan();
      })
    }
  }

  @Builder
  bubble(item: ChatItem) {
    Column({ space: 8 }) {
      if (item.text.length > 0) {
        Text(item.text)
          .fontSize($r('app.float.font_body'))
          .lineHeight(23)
          .fontColor(item.role === 'user' ? $r('app.color.chat_user_text') : $r('sys.color.font_primary'))
          .padding({ left: 14, right: 14, top: 10, bottom: 10 })
          .backgroundColor(item.role === 'user' ? $r('app.color.chat_user_bg') : $r('app.color.card_bg'))
          .borderWidth(item.role === 'user' ? 0 : 1)
          .borderColor($r('app.color.divider'))
          .borderRadius(item.role === 'user' ?
            { topLeft: 20, topRight: 20, bottomRight: 6, bottomLeft: 20 } :
            { topLeft: 6, topRight: 20, bottomRight: 20, bottomLeft: 20 })
          .constraintSize({ maxWidth: '85%' })
          .copyOption(CopyOptions.LocalDevice)
      }
      ForEach(item.actions, (a: UiAction) => {
        this.actionView(a, item.ts)
      }, (a: UiAction, i: number) => `${item.id}-${i}-${a.type}`)
      if (item.candidates.length > 0) {
        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
          ForEach(item.candidates, (c: ScanCandidate) => {
            this.chip(c.ingredient !== '' && c.ingredient !== c.name.toLowerCase() ? `${c.name} (${c.ingredient})` :
              c.name, false, () => {
              this.pickCandidate(c);
            })
          }, (c: ScanCandidate) => c.name)
        }
      }
    }
    .width('100%')
    .alignItems(item.role === 'user' ? HorizontalAlign.End : HorizontalAlign.Start)
  }

  @Builder
  welcome() {
    Column({ space: 16 }) {
      this.avatar(96)
      Text($r('app.string.agent_welcome'))
        .fontSize($r('app.float.font_body'))
        .lineHeight(23)
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.Center)
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center,
        space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
        this.chip($r('app.string.agent_starter_ibuprofen'), false, () => {
          this.send(this.str($r('app.string.agent_starter_ibuprofen')));
        })
        this.chip($r('app.string.agent_starter_avoid'), false, () => {
          this.send(this.str($r('app.string.agent_starter_avoid')));
        })
        this.chip($r('app.string.agent_starter_meds'), false, () => {
          this.send(this.str($r('app.string.agent_starter_meds')));
        })
        this.chip($r('app.string.agent_scan'), false, () => {
          this.pickAndScan();
        })
      }
    }
    .width('100%')
    .padding({ top: 32, left: 8, right: 8 })
  }

  @Builder
  statusStrip(text: ResourceStr) {
    Row({ space: 8 }) {
      Circle().width(8).height(8).fill($r('sys.color.font_tertiary'))
      Text(text)
        .fontSize($r('app.float.font_small'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.status_offline_text'))
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor($r('app.color.status_offline_bg'))
    .borderRadius($r('app.float.radius_s'))
  }

  @Builder
  roundButton(icon: Resource, filled: boolean, a11y: Resource) {
    Image(icon)
      .width(22)
      .height(22)
      .fillColor(filled ? $r('app.color.on_accent') : $r('app.color.brand_accent'))
      .padding(13)
      .width(48)
      .height(48)
      .borderRadius(24)
      .backgroundColor(filled ? $r('app.color.brand_accent') : $r('app.color.brand_accent_soft'))
      .accessibilityText(a11y)
  }

  build() {
    Column() {
      // Header
      Row({ space: 12 }) {
        this.avatar(40)
        Column({ space: 2 }) {
          Text($r('app.string.agent_name'))
            .fontSize($r('app.float.font_subtitle'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text($r('app.string.agent_status'))
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Stack() {
          this.roundButton($r('app.media.ic_wave'), this.live === 'LIVE', $r('app.string.a11y_live'))
        }
        .onClick(() => {
          this.toggleLive();
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      if (!Config.hasBackend()) {
        Column() {
          this.statusStrip($r('app.string.agent_offline'))
        }
        .padding({ left: 16, right: 16, bottom: 8 })
      } else if (this.live === 'LIVE' || this.live === 'CONNECTING') {
        Column() {
          this.statusStrip(this.live === 'LIVE' ? $r('app.string.agent_live_on') :
            $r('app.string.agent_live_connecting'))
        }
        .padding({ left: 16, right: 16, bottom: 8 })
      }

      // Thread
      List({ space: 12, scroller: this.scroller }) {
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
            Row({ space: 8 }) {
              LoadingProgress().width(20).height(20).color($r('app.color.brand_accent'))
              Text(this.listening ? $r('app.string.agent_listening') : this.busyLabel)
                .fontSize($r('app.float.font_small'))
                .fontColor($r('sys.color.font_secondary'))
            }
          }
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 16, right: 16 })
      .edgeEffect(EdgeEffect.Spring)

      // Input bar
      Row({ space: 8 }) {
        TextInput({ text: this.draft, placeholder: $r('app.string.agent_input_hint') })
          .layoutWeight(1)
          .height(48)
          .borderRadius(24)
          .backgroundColor($r('app.color.field_bg'))
          .fontSize($r('app.float.font_body'))
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
            this.roundButton($r('app.media.ic_mic'), this.listening, $r('app.string.a11y_mic'))
          }
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
      .backgroundColor($r('app.color.page_bg'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
