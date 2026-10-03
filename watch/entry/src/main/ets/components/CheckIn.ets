import { WatchController } from '../controller/WatchController';
import { SymptomKind } from '../model/WatchMetric';
import { Ring } from './Ring';
import { Theme } from './Theme';

@ComponentV2
struct FeelButton {
  @Param @Require icon: string;
  @Param @Require label: string;
  @Param @Require color: string;
  @Param @Require fill: string;
  @Event onTap: () => void = () => {};

  build() {
    Column({ space: 0 }) {
      Text(this.icon).fontSize(14).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
      Text(this.label).fontSize(10).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
    }
    .width(54)
    .height(54)
    .justifyContent(FlexAlign.Center)
    .borderRadius(27)
    .border({ width: 2, color: this.color })
    .backgroundColor(this.fill)
    .accessibilityGroup(true)
    .accessibilityText(this.label)
    .onClick(() => this.onTap())
  }
}

/** W4 check-in: "How do you feel?" Fine / Dizzy / Racing. Used as a page and after "I'm OK" on an alert. */
@ComponentV2
export struct CheckIn {
  @Param @Require ctrl: WatchController;
  /** As a swiper page it also offers medication logging. */
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

  build() {
    Stack() {
      Ring({ percent: 30, color: Theme.DANGER })
      Column({ space: 8 }) {
        Text('How do you feel?').fontSize(16).fontWeight(FontWeight.Bolder).fontColor(Theme.TEXT)
        Row({ space: 6 }) {
          FeelButton({ icon: '✓', label: 'Fine', color: Theme.OK, fill: Theme.OK_DARK, onTap: () => {
            this.answer('fine', 'Glad to hear it');
          } })
          FeelButton({ icon: '≈', label: 'Dizzy', color: Theme.WARN, fill: Theme.WARN_DARK, onTap: () => {
            this.answer('dizziness', 'Sit down. Logged for your doctor');
          } })
          FeelButton({ icon: '♥', label: 'Racing', color: Theme.DANGER, fill: Theme.DANGER_DARK, onTap: () => {
            this.answer('palpitations', 'Sit down. Logged for your doctor');
          } })
        }
        Text('"Racing" = palpitations').fontSize(10).fontColor(Theme.MUTED)
        if (this.asPage) {
          Row({ space: 6 }) {
            Text(`Took ${this.ctrl.medicationName}`)
              .fontSize(11)
              .fontColor(Theme.OK)
              .padding({ left: 10, right: 10, top: 8, bottom: 8 })
              .borderRadius(14)
              .backgroundColor(Theme.CARD)
              .accessibilityText(`Log ${this.ctrl.medicationName} as taken`)
              .onClick(() => {
                this.ctrl.logMedication();
                this.toast('Medication logged');
              })
            // Manual SOS: the same 10 s cancellable countdown an alert's "Need help" starts.
            Text('SOS')
              .fontSize(11)
              .fontWeight(FontWeight.Bolder)
              .fontColor(Theme.TEXT)
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .borderRadius(14)
              .backgroundColor(Theme.DANGER)
              .accessibilityText('Start S O S countdown')
              .onClick(() => {
                this.ctrl.needHelp();
              })
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
