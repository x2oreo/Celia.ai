// SOS (F-27, F-28): countdown with a big "I'm OK" → if nobody answers, SOS is "sent": call the ambulance,
// share the prepared message with contacts (SMS / messengers via the share sheet), call each contact.
// Opened by the SOS button, Settings → Test SOS, or automatically by a CRITICAL heart alert.
// A watch SOS (SosParam.sentBy 'WATCH') opens straight in the sent state: the watch already counted down and sent it,
// so there is no second countdown (B8). The sent state says what was sent, to whom, and what still needs a tap.

import { common } from '@kit.AbilityKit';
import { Routes, SosParam } from '../common/Routes';
import { COUNTDOWN_S, SosController, SosSender, SosState, TEST_COUNTDOWN_S } from '../emergency/SosController';
import { clock } from '../common/Format';
import { SosService } from '../emergency/SosService';
import { GeoPoint, SosEvent, sosMessage } from '../emergency/SosMessage';
import { LocalStore } from '../data/LocalStore';
import { Contact, Profile } from '../model/Profile';
import { Medication } from '../model/Medication';
import { emergencyFor, EmergencyInfo, systemCountry } from '../common/EmergencyNumbers';
import { dial } from '../common/Dialer';
import { pulse, stopPulse } from '../common/Haptics';
import { keepScreenOn } from '../common/Screen';
import { toast } from '../common/Toast';
import { BackHeader, InkButton, PrimaryButton, SecondaryButton } from '../components/Common';
import { LiveStatus } from '../emergency/LiveStatus';
import { AgentCore } from '../agent/AgentCore';
import { SosContacts, SosStatus, watchSosWhom, WatchSosWhom } from '../account/SosContacts';
import { Session } from '../account/Session';

@ComponentV2
export struct SosPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local state: SosState = 'IDLE';
  @Local remaining: number = COUNTDOWN_S;
  @Local test: boolean = false;
  @Local reason: string = '';
  @Local where: GeoPoint | undefined = undefined;
  @Local locating: boolean = true;
  @Local profile: Profile | undefined = undefined;
  @Local meds: Medication[] = [];
  @Local sentBy: SosSender = 'PHONE';
  @Local sentAt: number = -1;
  @Local watchLocation: boolean = false;
  @Local whom: WatchSosWhom = 'OFF';
  private whomTimer: number = -1;
  private whomTries: number = 0;
  private timer: number = -1;
  private lastSecond: number = -1;
  private trigger: string = 'BUTTON';
  private logged: boolean = false;

  private ctx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private begin(param: SosParam | undefined): void {
    this.test = param?.test ?? false;
    this.reason = param?.reason ?? '';
    const c: SosController = SosController.get();
    const byWatch: boolean = (param?.sentBy ?? 'PHONE') === 'WATCH' || (c.state === 'SENT' && c.sentBy === 'WATCH');
    this.trigger = byWatch ? 'WATCH' : this.test ? 'TEST' : ((param?.auto ?? false) ? 'VITALS' : 'BUTTON');
    if (!byWatch && c.state !== 'COUNTDOWN') {
      c.start(Date.now(), this.test ? TEST_COUNTDOWN_S : COUNTDOWN_S, this.test);
    }
    this.syncSent(c);
    this.state = c.state;
    this.remaining = c.remainingSeconds(Date.now());
    this.timer = setInterval(() => this.tick(), 250);
    keepScreenOn(this.ctx(), true);
    if (this.state === 'COUNTDOWN') {
      LiveStatus.startSos(this.remaining, this.reason);
    } else {
      this.record('SENT');
    }
    this.load();
    this.checkWhom();
  }

  private async load(): Promise<void> {
    this.profile = await LocalStore.get().getProfile();
    this.meds = await LocalStore.get().listMeds();
    this.where = await SosService.requestLocation(this.ctx());
    this.locating = false;
  }

  // Watch SOS: the server alerts the contacts (with consent), so ask it what happened. The dispatch can land a few
  // seconds after the phone hears of the SOS: check again every 5 s, at most 12 times.
  private async checkWhom(): Promise<void> {
    if (this.sentBy !== 'WATCH') {
      return;
    }
    const consent: boolean = await SosContacts.consent();
    const st: SosStatus | undefined = Session.isSignedIn() && consent ? await SosContacts.status() : undefined;
    this.whom = watchSosWhom(Session.isSignedIn(), consent, st, this.sentAt);
    this.whomTries++;
    if (this.whom === 'PENDING' && this.whomTries < 12) {
      this.whomTimer = setTimeout(() => {
        this.checkWhom();
      }, 5000);
    }
  }

  private whomText(): Resource {
    switch (this.whom) {
      case 'PENDING':
        return $r('app.string.ntf_sos_whom_pending');
      case 'SENT':
        return $r('app.string.ntf_sos_whom_sent');
      case 'PARTIAL':
        return $r('app.string.ntf_sos_whom_partial');
      case 'FAILED':
        return $r('app.string.ntf_sos_whom_failed');
      case 'DRY_RUN':
        return $r('app.string.ntf_sos_whom_dry_run');
      case 'NO_CONTACTS':
        return $r('app.string.ntf_sos_whom_no_contacts');
      case 'SKIPPED':
        return $r('app.string.ntf_sos_whom_skipped');
      default:
        return $r('app.string.ntf_sos_watch_whom');
    }
  }

  private syncSent(c: SosController): void {
    this.sentBy = c.sentBy;
    this.sentAt = c.sentAt;
    this.watchLocation = c.watchLocation;
  }

  private tick(): void {
    const c: SosController = SosController.get();
    const now: number = Date.now();
    const before: SosState = this.state;
    this.state = c.tick(now);
    this.syncSent(c);
    if (before === 'COUNTDOWN' && this.state === 'ACKED') {
      // "I'm OK" on the notification (EntryAbility) acked the controller.
      this.closeAcked();
      return;
    }
    this.remaining = c.remainingSeconds(now);
    if (this.state === 'COUNTDOWN' && this.remaining !== this.lastSecond) {
      this.lastSecond = this.remaining;
      pulse(this.remaining <= 5 ? 400 : 150);
      LiveStatus.updateSos(this.remaining);
    }
    if (before === 'COUNTDOWN' && this.state === 'SENT') {
      // Timeout, or the watch sent its own SOS meanwhile (SosController.watchSent).
      if (this.sentBy === 'WATCH') {
        this.trigger = 'WATCH';
      }
      this.onSent();
    }
  }

  private onSent(): void {
    this.checkWhom();
    stopPulse();
    LiveStatus.end('SENT');
    this.record('SENT');
  }

  private async record(outcome: string): Promise<void> {
    if (this.logged) {
      return;
    }
    this.logged = true;
    const ev: SosEvent = {
      ts: Date.now(),
      trigger: this.reason.length > 0 ? `${this.trigger}: ${this.reason}` : this.trigger,
      test: this.test,
      lat: this.where?.lat ?? NaN,
      lon: this.where?.lon ?? NaN,
      outcome: outcome
    };
    await SosService.log(ev);
  }

  private imOk(): void {
    SosController.get().ack();
    AgentCore.get().emergencyCancelled();
    this.closeAcked();
  }

  private closeAcked(): void {
    this.state = 'ACKED';
    stopPulse();
    LiveStatus.end('OK');
    this.record('ACKED');
    toast(this.getUIContext(), $r('app.string.sos_glad'));
    this.navStack.pop();
  }

  private sendNow(): void {
    SosController.get().sendNow(Date.now());
    this.state = SosController.get().state;
    this.onSent();
  }

  private info(): EmergencyInfo {
    return emergencyFor(this.profile?.country ?? systemCountry());
  }

  private message(): string {
    if (this.profile === undefined) {
      return '';
    }
    return sosMessage(this.profile, this.meds, this.where, this.reason, this.test);
  }

  private async shareMessage(): Promise<void> {
    const ok: boolean = await SosService.share(this.ctx(), this.message());
    if (!ok) {
      toast(this.getUIContext(), $r('app.string.error_generic'));
    }
  }

  aboutToDisappear(): void {
    if (this.whomTimer !== -1) {
      clearTimeout(this.whomTimer);
    }
    if (this.timer >= 0) {
      clearInterval(this.timer);
    }
    stopPulse();
    LiveStatus.end();
    keepScreenOn(this.ctx(), false);
    SosController.get().reset();
  }

  @Builder
  testBanner() {
    Text($r('app.string.sos_test_banner'))
      .fontSize($r('app.float.font_badge'))
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.ink'))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .border({ width: 1, color: $r('app.color.ink') })
      .borderRadius(16)
  }

  // Calm surface, one draining ring (DESIGN.md §10.2). Red is the ring and the send action only.
  @Builder
  countdown() {
    Column({ space: 16 }) {
      if (this.test) {
        this.testBanner()
      }
      Text($r('app.string.sos_label'))
        .fontSize($r('app.float.font_badge'))
        .fontWeight(800)
        .letterSpacing(1)
        .fontColor($r('app.color.risk_known_text'))
        .margin({ top: 12 })
      Text($r('app.string.sos_question'))
        .fontSize($r('app.float.font_title_1'))
        .fontWeight(800)
        .fontColor($r('app.color.ink'))
        .textAlign(TextAlign.Center)
      if (this.reason.length > 0) {
        Text(this.reason)
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.ink_2'))
          .textAlign(TextAlign.Center)
      }
      Stack() {
        Progress({ value: this.remaining, total: this.test ? TEST_COUNTDOWN_S : COUNTDOWN_S, type: ProgressType.Ring })
          .width(200)
          .height(200)
          .color($r('app.color.risk_known'))
          .backgroundColor($r('app.color.border'))
          .style({ strokeWidth: 12 })
        Column() {
          Text(`${this.remaining}`)
            .fontSize($r('app.float.font_display'))
            .fontWeight(800)
            .fontColor($r('app.color.ink'))
            .fontFeature('"tnum" on')
          Text($r('app.string.sos_seconds'))
            .fontSize($r('app.float.font_small'))
            .fontColor($r('app.color.ink_3'))
        }
      }
      .margin({ top: 8, bottom: 8 })
      Text($r('app.string.sos_explain'))
        .fontSize($r('app.float.font_small'))
        .fontColor($r('app.color.ink_3'))
        .textAlign(TextAlign.Center)
      Blank()
      InkButton({
        label: $r('app.string.sos_im_ok'),
        large: true,
        onTap: () => this.imOk()
      })
        .height($r('app.float.button_height_l'))
      PrimaryButton({
        label: $r('app.string.sos_send_now'),
        danger: true,
        large: true,
        onTap: () => this.sendNow()
      })
    }
    .width('100%')
    .height('100%')
    .padding(24)
    .backgroundColor($r('app.color.bg'))
  }

  @Builder
  statusRow(label: Resource, text: ResourceStr, extra: ResourceStr) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize($r('app.float.font_caption'))
        .fontWeight(FontWeight.Bold)
        .letterSpacing(0.5)
        .fontColor($r('app.color.ink_3'))
      Text(text)
        .fontSize($r('app.float.font_small'))
        .fontColor($r('app.color.ink_2'))
      if (extra !== '') {
        Text(extra)
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink_2'))
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  // What happened, in plain words (B8). Built from the controller state only — no model text.
  @Builder
  status() {
    Column({ space: 12 }) {
      if (this.sentBy === 'WATCH') {
        this.statusRow($r('app.string.ntf_sos_label_what'),
          $r('app.string.ntf_sos_watch_what', clock(this.sentAt)),
          this.watchLocation ? $r('app.string.ntf_sos_watch_loc') : $r('app.string.ntf_sos_watch_no_loc'))
        Divider().color($r('app.color.divider'))
        this.statusRow($r('app.string.ntf_sos_label_whom'), this.whomText(), '')
      } else {
        this.statusRow($r('app.string.ntf_sos_label_what'), $r('app.string.ntf_sos_phone_what'), '')
        Divider().color($r('app.color.divider'))
        this.statusRow($r('app.string.ntf_sos_label_whom'), $r('app.string.ntf_sos_phone_whom'), '')
      }
      Divider().color($r('app.color.divider'))
      this.statusRow($r('app.string.ntf_sos_label_todo'), $r('app.string.ntf_sos_todo'), '')
    }
    .width('100%')
    .padding($r('app.float.space_m'))
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_m'))
  }

  @Builder
  sent() {
    Scroll() {
      Column({ space: 14 }) {
        if (this.test) {
          this.testBanner()
        }
        Text(this.sentBy === 'WATCH' ? $r('app.string.ntf_sos_watch_title') : $r('app.string.sos_sent_title'))
          .fontSize($r('app.float.font_title_1'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Text($r('app.string.sos_sent_subtitle'))
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.ink_3'))
        this.status()
        PrimaryButton({
          label: `${this.info().ambulance} · Call ambulance`,
          icon: $r('app.media.ic_phone'),
          danger: true,
          large: true,
          onTap: () => {
            dial(this.info().ambulance);
          }
        })
        SecondaryButton({
          label: $r('app.string.sos_share'),
          icon: $r('app.media.ic_share'),
          onTap: () => {
            this.shareMessage();
          }
        })
        ForEach(this.profile?.contacts ?? [], (c: Contact) => {
          SecondaryButton({
            label: `Call ${c.name}`,
            icon: $r('app.media.ic_phone'),
            onTap: () => {
              dial(c.phone);
            }
          })
        }, (c: Contact) => `${c.name}-${c.phone}`)
        // B5: what to give and what not to give, for whoever arrives (S2's page).
        SecondaryButton({
          label: $r('app.string.ntf_sos_responder'),
          icon: $r('app.media.ic_doctor'),
          onTap: () => {
            this.navStack.pushPathByName(Routes.RESPONDER, null);
          }
        })
        Row({ space: 8 }) {
          Image($r('app.media.ic_location')).width(18).height(18).fillColor($r('app.color.ink_3'))
          Text(this.locating ? $r('app.string.sos_locating') : (this.where === undefined ?
            $r('app.string.sos_no_location') : $r('app.string.sos_location_ok')))
            .fontSize($r('app.float.font_small'))
            .fontColor($r('app.color.ink_3'))
        }
        Text(this.message())
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink'))
          .padding(14)
          .width('100%')
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.border') })
          .borderRadius($r('app.float.radius_m'))
        Text($r('app.string.sos_sms_note'))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.ink_4'))
      }
      .padding(20)
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .layoutWeight(1)
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
  }

  build() {
    NavDestination() {
      if (this.state === 'SENT') {
        Column() {
          BackHeader({
            title: $r('app.string.emergency_sos'),
            onBack: () => {
              this.navStack.pop();
            }
          })
          this.sent()
        }
        .width('100%')
        .height('100%')
      } else {
        this.countdown()
      }
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg'))
    .onReady((ctx: NavDestinationContext) => {
      this.begin(ctx.pathInfo.param as SosParam | undefined);
    })
    .onBackPressed(() => {
      // Back during the countdown means "I'm OK"; never leaves an SOS silently running.
      if (this.state === 'COUNTDOWN') {
        this.imOk();
        return true;
      }
      return false;
    })
  }
}
