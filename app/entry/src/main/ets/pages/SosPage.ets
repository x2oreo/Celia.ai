// SOS (F-27, F-28): countdown with a big "I'm OK" → if nobody answers, SOS is "sent": call the ambulance,
// share the prepared message with contacts (SMS / messengers via the share sheet), call each contact.
// Opened by the SOS button, Settings → Test SOS, or automatically by a CRITICAL heart alert.

import { common } from '@kit.AbilityKit';
import { SosParam } from '../common/Routes';
import { COUNTDOWN_S, SosController, SosState, TEST_COUNTDOWN_S } from '../emergency/SosController';
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
import { PrimaryButton, SecondaryButton } from '../components/Common';
import { LiveStatus } from '../emergency/LiveStatus';
import { AgentCore } from '../agent/AgentCore';

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
    this.trigger = this.test ? 'TEST' : ((param?.auto ?? false) ? 'VITALS' : 'BUTTON');
    const c: SosController = SosController.get();
    if (c.state !== 'COUNTDOWN') {
      c.start(Date.now(), this.test ? TEST_COUNTDOWN_S : COUNTDOWN_S, this.test);
    }
    this.state = c.state;
    this.remaining = c.remainingSeconds(Date.now());
    this.timer = setInterval(() => this.tick(), 250);
    keepScreenOn(this.ctx(), true);
    LiveStatus.startSos(this.remaining, this.reason);
    this.load();
  }

  private async load(): Promise<void> {
    this.profile = await LocalStore.get().getProfile();
    this.meds = await LocalStore.get().listMeds();
    this.where = await SosService.requestLocation(this.ctx());
    this.locating = false;
  }

  private tick(): void {
    const c: SosController = SosController.get();
    const now: number = Date.now();
    const before: SosState = c.state;
    this.state = c.tick(now);
    this.remaining = c.remainingSeconds(now);
    if (this.state === 'COUNTDOWN' && this.remaining !== this.lastSecond) {
      this.lastSecond = this.remaining;
      pulse(this.remaining <= 5 ? 400 : 150);
      LiveStatus.updateSos(this.remaining);
    }
    if (before === 'COUNTDOWN' && this.state === 'SENT') {
      this.onSent();
    }
  }

  private onSent(): void {
    stopPulse();
    LiveStatus.end();
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
    this.state = 'ACKED';
    stopPulse();
    LiveStatus.end();
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
    if (this.timer >= 0) {
      clearInterval(this.timer);
    }
    stopPulse();
    LiveStatus.end();
    keepScreenOn(this.ctx(), false);
    SosController.get().reset();
  }

  @Builder
  countdown() {
    Column({ space: 20 }) {
      if (this.test) {
        Text($r('app.string.sos_test_banner'))
          .fontSize($r('app.float.font_small'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.sim_badge'))
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor($r('app.color.sim_badge_soft'))
          .borderRadius(100)
      }
      Text($r('app.string.sos_question'))
        .fontSize($r('app.float.font_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .textAlign(TextAlign.Center)
      if (this.reason.length > 0) {
        Text(this.reason)
          .fontSize($r('app.float.font_body'))
          .fontColor('#FFE4E2')
          .textAlign(TextAlign.Center)
      }
      Stack() {
        Progress({ value: this.remaining, total: this.test ? TEST_COUNTDOWN_S : COUNTDOWN_S, type: ProgressType.Ring })
          .width(200)
          .height(200)
          .color('#FFFFFF')
          .style({ strokeWidth: 10 })
        Column() {
          Text(`${this.remaining}`)
            .fontSize(72)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .fontFeature('"tnum" on')
          Text($r('app.string.sos_seconds'))
            .fontSize($r('app.float.font_small'))
            .fontColor('#FFE4E2')
        }
      }
      Text($r('app.string.sos_explain'))
        .fontSize($r('app.float.font_small'))
        .fontColor('#FFE4E2')
        .textAlign(TextAlign.Center)
      Blank()
      Button($r('app.string.sos_im_ok'))
        .width('100%')
        .height(80)
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor('#B42318')
        .backgroundColor('#FFFFFF')
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.97 })
        .onClick(() => this.imOk())
      Text($r('app.string.sos_send_now'))
        .fontSize($r('app.float.font_body'))
        .fontColor('#FFFFFF')
        .decoration({ type: TextDecorationType.Underline })
        .padding(12)
        .onClick(() => this.sendNow())
    }
    .width('100%')
    .height('100%')
    .padding(24)
    .backgroundColor('#B42318')
  }

  @Builder
  sent() {
    Scroll() {
      Column({ space: 14 }) {
        if (this.test) {
          Text($r('app.string.sos_test_banner'))
            .fontSize($r('app.float.font_small'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.sim_badge'))
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor($r('app.color.sim_badge_soft'))
            .borderRadius(100)
        }
        Text($r('app.string.sos_sent_title'))
          .fontSize($r('app.float.font_headline'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Text($r('app.string.sos_sent_subtitle'))
          .fontSize($r('app.float.font_body'))
          .fontColor($r('sys.color.font_secondary'))
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
        Row({ space: 8 }) {
          Image($r('app.media.ic_location')).width(18).height(18).fillColor($r('app.color.brand_accent'))
          Text(this.locating ? $r('app.string.sos_locating') : (this.where === undefined ?
            $r('app.string.sos_no_location') : $r('app.string.sos_location_ok')))
            .fontSize($r('app.float.font_small'))
            .fontColor($r('sys.color.font_secondary'))
        }
        Text(this.message())
          .fontSize($r('app.float.font_small'))
          .fontColor($r('sys.color.font_primary'))
          .padding(14)
          .width('100%')
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius($r('app.float.radius_m'))
        Text($r('app.string.sos_sms_note'))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .padding(20)
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .backgroundColor($r('app.color.page_bg'))
  }

  build() {
    NavDestination() {
      if (this.state === 'SENT') {
        this.sent()
      } else {
        this.countdown()
      }
    }
    .hideTitleBar(this.state !== 'SENT')
    .title($r('app.string.emergency_sos'))
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
