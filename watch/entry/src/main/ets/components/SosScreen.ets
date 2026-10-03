import { WatchController } from '../controller/WatchController';
import { Pill } from './Pill';
import { Ring } from './Ring';
import { Theme } from './Theme';

/**
 * W5 SOS countdown, then "SOS sent". The watch does not dial 112 itself (unsafe in a test build): it sends an `sos`
 * row and the phone app alerts contacts and offers the call.
 */
@ComponentV2
export struct SosScreen {
  @Param @Require ctrl: WatchController;

  build() {
    Stack() {
      Ring({ percent: this.ctrl.sosSent ? 100 : this.ctrl.sosCountdown * 10, color: Theme.DANGER, strokeWidth: 10 })
      if (this.ctrl.sosSent) {
        Column({ space: 4 }) {
          Text('SOS SENT').fontSize(11).fontWeight(FontWeight.Bolder).letterSpacing(1).fontColor(Theme.DANGER)
          Text('Your phone is alerting your contacts.')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
            .textAlign(TextAlign.Center)
            .width(160)
          Text('I have Long QT syndrome. Call 112.')
            .fontSize(11)
            .fontColor(Theme.MUTED)
            .textAlign(TextAlign.Center)
            .width(150)
            .margin({ bottom: 6 })
          Pill({ label: 'Dismiss', bg: Theme.TEXT, fg: '#000000', pillWidth: 110, pillHeight: 38, onTap: () => {
            this.ctrl.dismissSosSent();
          } })
        }
      } else {
        Column({ space: 2 }) {
          Text('EMERGENCY').fontSize(11).fontWeight(FontWeight.Bolder).letterSpacing(1).fontColor(Theme.DANGER)
          Text('Sending SOS').fontSize(20).fontWeight(FontWeight.Bolder).fontColor(Theme.TEXT)
          Text(`${this.ctrl.sosCountdown} s`).fontSize(40).fontWeight(FontWeight.Bolder).fontColor(Theme.TEXT)
            .margin({ bottom: 6 })
          Pill({ label: 'Cancel', bg: Theme.TEXT, fg: '#000000', pillWidth: 120, pillHeight: 40, fontSize: 16, onTap: () => {
            this.ctrl.cancelSos();
          } })
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
