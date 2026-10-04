import { WatchController } from '../controller/WatchController';
import { Bezel, Caps, PillButton } from './Parts';
import { Theme } from './Theme';

/**
 * 15 Missed dose: no dose logged by the reminder time + 2 h. Coral = a nudge from Celia, not a risk. "Not yet"
 * snoozes 30 min; the last ask reads "Later".
 */
@ComponentV2
export struct DoseNudgeGlance {
  @Param @Require ctrl: WatchController;

  name(): string {
    const n = this.ctrl.medicationName;
    return `${n.charAt(0).toUpperCase()}${n.substring(1)}`;
  }

  build() {
    Stack() {
      Bezel({ mode: 'RING', color: Theme.BRAND })
      Column({ space: 4 }) {
        Caps({ text: 'DAILY DOSE', color: Theme.BRAND })
        Text(`Did you take ${this.name()}?`)
          .fontSize(Theme.TITLE + 3)
          .fontWeight(FontWeight.Bolder)
          .fontColor(Theme.TEXT)
          .textAlign(TextAlign.Center)
          .width(160)
        Text('Skipped beta-blocker doses raise the risk.')
          .fontSize(Theme.SMALL)
          .fontColor(Theme.TEXT_2)
          .textAlign(TextAlign.Center)
          .width(160)
          .margin({ bottom: 8 })
        Row({ space: 8 }) {
          PillButton({ label: 'Took it', bg: Theme.BRAND, pillWidth: 84, onTap: () => {
            this.ctrl.doseTaken();
          } })
          PillButton({ label: this.ctrl.doseNudgeCanSnooze ? 'Not yet' : 'Later', pillWidth: 84, onTap: () => {
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
