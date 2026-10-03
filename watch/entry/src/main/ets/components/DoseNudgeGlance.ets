import { WatchController } from '../controller/WatchController';
import { Pill } from './Pill';
import { Ring } from './Ring';
import { Theme } from './Theme';

/** Missed-dose nudge: no dose logged by the reminder time + 2 h. */
@ComponentV2
export struct DoseNudgeGlance {
  @Param @Require ctrl: WatchController;

  build() {
    Stack() {
      Ring({ percent: 35, color: Theme.WARN })
      Column({ space: 4 }) {
        Text('MISSED DOSE?').fontSize(10).fontWeight(FontWeight.Bolder).letterSpacing(1).fontColor(Theme.WARN)
        Text(`Did you take ${this.ctrl.medicationName}?`)
          .fontSize(18)
          .fontWeight(FontWeight.Bolder)
          .fontColor(Theme.TEXT)
          .textAlign(TextAlign.Center)
          .width(170)
        Text('Skipping beta-blocker doses raises the risk.')
          .fontSize(10)
          .fontColor(Theme.MUTED)
          .textAlign(TextAlign.Center)
          .width(150)
          .margin({ bottom: 6 })
        Row({ space: 4 }) {
          Pill({ label: 'Took it', bg: Theme.OK, fg: '#000000', pillWidth: 70, pillHeight: 32, fontSize: 13,
            onTap: () => {
              this.ctrl.doseTaken();
            } })
          Pill({ label: this.ctrl.doseNudgeCanSnooze ? 'Not yet' : 'Later', pillWidth: 70, pillHeight: 32,
            fontSize: 13, onTap: () => {
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
