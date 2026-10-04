import { WatchController } from '../controller/WatchController';
import { Caps, EdgeButton, Icon, Ring } from './Parts';
import { Theme } from './Theme';

/**
 * W5 SOS countdown (the ring drains over 10 s), then "SOS sent" once the `sos` row is uploaded ("SOS saved" while it
 * waits). The watch does not dial 112 itself (unsafe in a test build): the phone app alerts the contacts and offers
 * the call.
 */
@ComponentV2
export struct SosScreen {
  @Param @Require ctrl: WatchController;

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Ring({ percent: this.ctrl.sosSent ? 100 : this.ctrl.sosCountdown * 10, color: Theme.ALERT, strokeWidth: 10 })
      if (this.ctrl.sosSent) {
        Column({ space: 4 }) {
          Icon({ src: this.ctrl.sosDelivered ? $r('app.media.ic_circle_check') : $r('app.media.ic_timer'),
            color: this.ctrl.sosDelivered ? Theme.CALM : Theme.ELEVATED, glyph: 26 })
          Text(this.ctrl.sosDelivered ? 'SOS sent' : 'SOS saved')
            .fontSize(Theme.TITLE + 3)
            .fontWeight(FontWeight.Bolder)
            .fontColor(Theme.TEXT)
          Text(this.ctrl.sosDelivered ? 'Your phone is alerting your contacts.' : 'Not sent yet. Retrying.')
            .fontSize(Theme.SMALL)
            .fontColor(Theme.TEXT_2)
            .textAlign(TextAlign.Center)
            .width(160)
          Text('I have Long QT syndrome. Call 112.')
            .fontSize(Theme.MICRO)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.ALERT)
            .textAlign(TextAlign.Center)
            .width(160)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ bottom: 36 })
        EdgeButton({ label: 'Done', bg: Theme.TEXT, fg: Theme.ON_LIGHT, onTap: () => {
          this.ctrl.dismissSosSent();
        } })
      } else {
        Column({ space: 0 }) {
          Caps({ text: 'EMERGENCY', color: Theme.ALERT })
          Text('Sending SOS').fontSize(Theme.TITLE + 3).fontWeight(FontWeight.Bolder).fontColor(Theme.TEXT)
            .margin({ top: 2 })
          Row({ space: 2 }) {
            Text(`${this.ctrl.sosCountdown}`).fontSize(Theme.HERO).fontWeight(FontWeight.Bolder).fontColor(Theme.TEXT)
            Text('s').fontSize(Theme.TITLE).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT_2).margin({ bottom: 12 })
          }
          .alignItems(VerticalAlign.Bottom)
          Text('to your phone and contacts').fontSize(Theme.MICRO).fontColor(Theme.TEXT_2)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ bottom: 36 })
        .accessibilityGroup(true)
        .accessibilityText(`Emergency. Sending S O S in ${this.ctrl.sosCountdown} seconds.`)
        EdgeButton({ label: 'Cancel', bg: Theme.TEXT, fg: Theme.ON_LIGHT, onTap: () => {
          this.ctrl.cancelSos();
        } })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
