import { WatchController } from '../controller/WatchController';
import { Bezel, Caps, CheckDisc, Icon, PillButton } from './Parts';
import { Theme } from './Theme';

const SOS_SECONDS: number = 10;

/** The line anyone helping can read: the biggest text on the sent / saved screens. */
@ComponentV2
struct BystanderCard {
  build() {
    Text('I have Long QT syndrome. Call 112.')
      .fontSize(Theme.BODY + 1)
      .fontWeight(FontWeight.Bolder)
      .fontColor(Theme.TEXT)
      .textAlign(TextAlign.Center)
      .width(170)
      .padding({ left: 10, right: 10, top: 7, bottom: 7 })
      .borderRadius(8)
      .backgroundColor(Theme.ALERT_TINT)
  }
}

/**
 * 12-13 SOS: a 10 s countdown (the ring drains, white Cancel), then "SOS sent" once the `sos` row reached the server,
 * or "SOS saved" (dashed amber) while it waits. The watch never dials 112 itself: the phone alerts the contacts.
 */
@ComponentV2
export struct SosScreen {
  @Param @Require ctrl: WatchController;

  @Builder
  sent() {
    Column({ space: 5 }) {
      if (this.ctrl.sosDelivered) {
        CheckDisc()
      } else {
        Icon({ src: $r('app.media.ic_risk_possible'), color: Theme.ELEVATED, glyph: 30 })
      }
      Text(this.ctrl.sosDelivered ? 'SOS sent' : 'SOS saved')
        .fontSize(Theme.TITLE + 3)
        .fontWeight(FontWeight.Bolder)
        .fontColor(Theme.TEXT)
      Text(this.ctrl.sosDelivered ? 'Your phone is alerting your contacts.' :
        'Not sent yet. Retrying when your phone is in reach...')
        .fontSize(Theme.SMALL)
        .fontColor(Theme.TEXT_2)
        .textAlign(TextAlign.Center)
        .width(160)
        .margin({ top: -3 })
      BystanderCard()
      PillButton({ label: 'Done', pillWidth: 90, onTap: () => {
        this.ctrl.dismissSosSent();
      } })
    }
  }

  @Builder
  countdown() {
    Column({ space: 0 }) {
      Caps({ text: 'SOS', color: Theme.BRAND })
      Text('Sending SOS').fontSize(Theme.TITLE + 3).fontWeight(FontWeight.Bolder).fontColor(Theme.TEXT)
      Text(`${this.ctrl.sosCountdown}`)
        .fontSize(Theme.HERO + 4)
        .fontWeight(FontWeight.Bolder)
        .fontColor(Theme.TEXT)
        .margin({ top: -6, bottom: -8 })
        .accessibilityText(`${this.ctrl.sosCountdown} seconds`)
      Text('to your phone and contacts').fontSize(Theme.SMALL).fontColor(Theme.TEXT_2).margin({ bottom: 10 })
      PillButton({ label: 'Cancel', bg: Theme.TEXT, fg: Theme.ON_LIGHT, pillWidth: 110, pillHeight: 44,
        fontSize: Theme.BODY + 1, onTap: () => {
          this.ctrl.cancelSos();
        } })
    }
  }

  build() {
    Stack() {
      if (!this.ctrl.sosSent) {
        Bezel({ mode: 'RING', color: Theme.ALERT, fraction: this.ctrl.sosCountdown / SOS_SECONDS, strokeWidth: 10 })
        this.countdown()
      } else if (this.ctrl.sosDelivered) {
        Bezel({ mode: 'RING', color: Theme.CALM })
        this.sent()
      } else {
        Bezel({ mode: 'DASHED', color: Theme.ELEVATED })
        this.sent()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
