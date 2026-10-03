// Bystander mode (F-41): "Help this person" for a stranger. Three big steps, the right emergency number,
// a hands-only CPR metronome (110/min, haptic + visual — no sudden sounds) and the facts paramedics need.
// Steps follow public resuscitation guidance (ERC / AHA: call, push hard and fast in the centre of the chest,
// 100–120/min, use an AED as soon as it arrives). Reachable without unlocking the app.

import { LocalStore } from '../data/LocalStore';
import { Contact, Profile } from '../model/Profile';
import { emergencyFor, EmergencyInfo, systemCountry } from '../common/EmergencyNumbers';
import { dial } from '../common/Dialer';
import { pulse } from '../common/Haptics';
import { keepScreenOn } from '../common/Screen';
import { AppLock } from '../common/AppLock';
import { PrimaryButton } from '../components/Common';
import { beatIntervalMs, CPR_BPM } from '../bystander/Metronome';

@ComponentV2
export struct BystanderPage {
  @Local profile: Profile | undefined = undefined;
  @Local running: boolean = false;
  @Local beat: boolean = false;
  @Local count: number = 0;
  private timer: number = -1;

  aboutToAppear(): void {
    this.load();
    keepScreenOn(this.getUIContext().getHostContext()!, true);
  }

  aboutToDisappear(): void {
    this.stop();
    keepScreenOn(this.getUIContext().getHostContext()!, false);
    AppLock.endEmergency();
  }

  private async load(): Promise<void> {
    this.profile = await LocalStore.get().getProfile();
  }

  private info(): EmergencyInfo {
    return emergencyFor(this.profile?.country ?? systemCountry());
  }

  private toggle(): void {
    if (this.running) {
      this.stop();
      return;
    }
    this.running = true;
    this.count = 0;
    this.timer = setInterval(() => {
      this.beat = !this.beat;
      this.count++;
      pulse(40);
    }, beatIntervalMs(CPR_BPM));
  }

  private stop(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    this.running = false;
  }

  @Builder
  step(n: string, title: Resource, body: Resource) {
    Row({ space: 14 }) {
      Text(n)
        .fontSize($r('app.float.font_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.on_accent'))
        .textAlign(TextAlign.Center)
        .width(40)
        .height(40)
        .backgroundColor($r('app.color.card_fixed_alert'))
        .borderRadius(20)
      Column({ space: 4 }) {
        Text(title)
          .fontSize($r('app.float.font_title_3'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Text(body)
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.ink_3'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .alignItems(VerticalAlign.Top)
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_m'))
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          Text($r('app.string.by_title'))
            .fontSize($r('app.float.font_title_1'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
            .width('100%')
          Text(this.profile === undefined ? $r('app.string.by_subtitle_generic') : $r('app.string.by_subtitle'))
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.ink_3'))
            .width('100%')

          PrimaryButton({
            label: `1 · Call ${this.info().ambulance}`,
            icon: $r('app.media.ic_phone'),
            danger: true,
            large: true,
            onTap: () => {
              dial(this.info().ambulance);
            }
          })
          this.step('2', $r('app.string.by_step2_title'), $r('app.string.by_step2_body'))

          // CPR metronome
          Column({ space: 12 }) {
            Stack() {
              Circle()
                .width(this.beat ? 150 : 128)
                .height(this.beat ? 150 : 128)
                .fill(this.running ? $r('app.color.card_fixed_alert') : $r('app.color.risk_known_tint'))
                .animation({ duration: 120, curve: Curve.EaseOut })
              Text(this.running ? `${this.count}` : 'CPR')
                .fontSize($r('app.float.font_title_1'))
                .fontWeight(FontWeight.Bold)
                .fontColor(this.running ? $r('app.color.on_accent') : $r('app.color.card_fixed_alert'))
            }
            .width(160)
            .height(160)
            Text(this.running ? $r('app.string.by_cpr_running') : $r('app.string.by_cpr_start'))
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.ink'))
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.border') })
          .borderRadius($r('app.float.radius_m'))
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
          .onClick(() => this.toggle())

          this.step('3', $r('app.string.by_step3_title'), $r('app.string.by_step3_body'))

          if (this.profile !== undefined) {
            Column({ space: 8 }) {
              Text($r('app.string.by_facts'))
                .fontSize($r('app.float.font_small'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.card_fixed_alert'))
              Text(`Long QT syndrome${this.profile.genotype === 'UNKNOWN' ? '' : ` (${this.profile.genotype})`}. ` +
                'Tell paramedics: avoid QT-prolonging drugs; torsades → IV magnesium.')
                .fontSize($r('app.float.font_body'))
                .fontColor($r('app.color.ink'))
              if (this.profile.hasIcd) {
                Text($r('app.string.by_icd'))
                  .fontSize($r('app.float.font_body'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.ink'))
              }
              ForEach(this.profile.contacts, (c: Contact) => {
                Text(`Call ${c.name}${c.relation === '' ? '' : ` (${c.relation})`}: ${c.phone}`)
                  .fontSize($r('app.float.font_body'))
                  .fontColor($r('app.color.brand_text'))
                  .onClick(() => {
                    dial(c.phone);
                  })
              }, (c: Contact) => c.phone)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(16)
            .backgroundColor($r('app.color.risk_known_tint'))
            .borderRadius($r('app.float.radius_m'))
          }
        }
        .padding({ left: 16, right: 16, bottom: 32 })
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .title($r('app.string.by_nav_title'))
    .backgroundColor($r('app.color.bg'))
  }
}
