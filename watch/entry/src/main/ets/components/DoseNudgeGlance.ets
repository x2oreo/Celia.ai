import { WatchController } from '../controller/WatchController';
import { Caps, Icon, PillButton, Ring } from './Parts';
import { Theme } from './Theme';

/** Missed-dose nudge: no dose logged by the reminder time + 2 h. Amber, not red: a reminder, not an alarm. */
@ComponentV2
export struct DoseNudgeGlance {
  @Param @Require ctrl: WatchController;

  name(): string {
    const n = this.ctrl.medicationName;
    return `${n.charAt(0).toUpperCase()}${n.substring(1)}`;
  }

  build() {
    Stack() {
      Ring({ percent: 100, color: Theme.ELEVATED_TINT, strokeWidth: 10 })
      Column({ space: 3 }) {
        Stack() {
          Icon({ src: $r('app.media.ic_pill'), color: Theme.ELEVATED, glyph: 20 })
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor(Theme.ELEVATED_TINT)
        Caps({ text: 'MISSED DOSE?', color: Theme.ELEVATED }).margin({ top: 2 })
        Text(`Did you take ${this.name()}?`)
          .fontSize(Theme.TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)
          .textAlign(TextAlign.Center)
          .width(170)
        Text('Skipped beta-blocker doses raise the risk.')
          .fontSize(Theme.MICRO)
          .fontColor(Theme.TEXT_2)
          .textAlign(TextAlign.Center)
          .width(150)
          .margin({ bottom: 6 })
        Row({ space: 6 }) {
          PillButton({ label: 'Took it', bg: Theme.BRAND, fg: Theme.ON_LIGHT, pillWidth: 80, onTap: () => {
            this.ctrl.doseTaken();
          } })
          PillButton({ label: this.ctrl.doseNudgeCanSnooze ? 'Not yet' : 'Later', pillWidth: 80, onTap: () => {
            this.ctrl.doseNotYet();
          } })
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
