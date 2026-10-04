import { WatchController } from '../controller/WatchController';
import { SymptomKind } from '../model/WatchMetric';
import { EdgeButton, Icon } from './Parts';
import { Theme } from './Theme';

@ComponentV2
struct FeelButton {
  @Param @Require icon: Resource;
  @Param @Require label: string;
  @Param @Require color: string;
  @Param @Require fill: string;
  @Event onTap: () => void = () => {};

  build() {
    Column({ space: 2 }) {
      Icon({ src: this.icon, color: this.color, glyph: 18 })
      Text(this.label).fontSize(Theme.MICRO + 1).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
    }
    .width(56)
    .height(56)
    .justifyContent(FlexAlign.Center)
    .borderRadius(28)
    .border({ width: 2, color: this.color })
    .backgroundColor(this.fill)
    .accessibilityGroup(true)
    .accessibilityText(this.label)
    .onClick(() => this.onTap())
  }
}

/**
 * W4 check-in: "How do you feel?" Fine / Dizzy / Racing. As a swiper page it also logs the daily medicine and starts
 * a manual SOS; as an overlay (after "I'm OK" on an alert) it offers "Not now".
 */
@ComponentV2
export struct CheckIn {
  @Param @Require ctrl: WatchController;
  @Param asPage: boolean = false;

  toast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1500 });
    } catch (e) {
      // A missing toast is harmless; the metric is already queued.
    }
  }

  answer(kind: SymptomKind, msg: string): void {
    this.ctrl.checkIn(kind);
    this.toast(msg);
  }

  medLabel(): string {
    const n = this.ctrl.medicationName;
    return `Took ${n.charAt(0).toUpperCase()}${n.substring(1)}`;
  }

  @Builder
  feelings() {
    Row({ space: 8 }) {
      FeelButton({ icon: $r('app.media.ic_check'), label: 'Fine', color: Theme.CALM, fill: Theme.CALM_TINT,
        onTap: () => {
          this.answer('fine', 'Glad to hear it');
        } })
      FeelButton({ icon: $r('app.media.ic_breath'), label: 'Dizzy', color: Theme.ELEVATED,
        fill: Theme.ELEVATED_TINT, onTap: () => {
          this.answer('dizziness', 'Sit down. Logged for your doctor');
        } })
      FeelButton({ icon: $r('app.media.ic_heart_fill'), label: 'Racing', color: Theme.ALERT, fill: Theme.ALERT_TINT,
        onTap: () => {
          this.answer('palpitations', 'Sit down. Logged for your doctor');
        } })
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column({ space: 8 }) {
        Text('How do you feel?').fontSize(Theme.TITLE).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
        this.feelings()
        Text('"Racing" = palpitations').fontSize(Theme.MICRO).fontColor(Theme.TEXT_3)
        if (this.asPage) {
          Row({ space: 6 }) {
            Row({ space: 5 }) {
              Icon({ src: $r('app.media.ic_pill'), color: Theme.BRAND, glyph: 14 })
              Text(this.medLabel()).fontSize(Theme.SMALL).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                .maxLines(1)
            }
            .height(Theme.PILL_HEIGHT)
            .padding({ left: 12, right: 14 })
            .borderRadius(Theme.PILL_HEIGHT / 2)
            .backgroundColor(Theme.BUTTON)
            .accessibilityGroup(true)
            .accessibilityText(`Log ${this.ctrl.medicationName} as taken`)
            .onClick(() => {
              this.ctrl.logMedication();
              this.toast('Dose logged');
            })
            // Manual SOS: the same 10 s cancellable countdown an alert's "Need help" starts.
            Column({ space: 0 }) {
              Text('SOS').fontSize(Theme.SMALL).fontWeight(FontWeight.Bolder).fontColor(Theme.TEXT)
            }
            .width(Theme.PILL_HEIGHT)
            .height(Theme.PILL_HEIGHT)
            .justifyContent(FlexAlign.Center)
            .borderRadius(Theme.PILL_HEIGHT / 2)
            .backgroundColor(Theme.ALERT)
            .accessibilityText('Start S O S countdown')
            .onClick(() => {
              this.ctrl.needHelp();
            })
          }
          .margin({ top: 2 })
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ bottom: this.asPage ? 0 : 30 })

      if (!this.asPage) {
        EdgeButton({ label: 'Not now', onTap: () => {
          this.ctrl.closeCheckIn();
        } })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
