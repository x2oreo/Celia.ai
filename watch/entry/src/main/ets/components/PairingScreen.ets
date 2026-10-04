import { WatchController } from '../controller/WatchController';
import { formatPairCode } from '../sync/PairingClient';
import { Caps, EdgeButton, Icon, PillButton, Ring } from './Parts';
import { Theme } from './Theme';

/** Shows a 6-digit code to type into the phone app; polls until the phone confirms (or the code expires). */
@ComponentV2
export struct PairingScreen {
  @Param @Require ctrl: WatchController;

  toast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 });
    } catch (e) {
      // Toast is cosmetic; the error is also on screen and in the log.
    }
  }

  newCode(): void {
    this.ctrl.startPairing().then((err: string) => {
      if (err.length > 0) {
        this.toast(err);
      }
    });
  }

  timeLeft(): string {
    const m = Math.floor(this.ctrl.pairSecondsLeft / 60);
    const s = this.ctrl.pairSecondsLeft % 60;
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.ctrl.pairScreen === 'PAIRED') {
        Ring({ percent: 100, color: Theme.CALM })
      } else if (this.ctrl.pairScreen === 'CODE') {
        Ring({ percent: Math.min(100, this.ctrl.pairSecondsLeft / 6), color: Theme.BRAND })
      } else {
        Ring({ percent: 0, color: Theme.BRAND })
      }

      Column({ space: 4 }) {
        if (this.ctrl.pairScreen === 'LOADING') {
          LoadingProgress().width(36).height(36).color(Theme.BRAND)
          Text('Getting a code').fontSize(Theme.SMALL).fontColor(Theme.TEXT_2)
        } else if (this.ctrl.pairScreen === 'CODE') {
          Row({ space: 4 }) {
            Icon({ src: $r('app.media.ic_phone_link'), color: Theme.BRAND, glyph: 12 })
            Caps({ text: 'PAIR WITH PHONE', color: Theme.BRAND })
          }
          Text(formatPairCode(this.ctrl.pairCode))
            .fontSize(34)
            .fontWeight(FontWeight.Bolder)
            .letterSpacing(1)
            .fontColor(Theme.TEXT)
          Text('Type this code in Celia on your phone')
            .fontSize(Theme.SMALL)
            .fontColor(Theme.TEXT_2)
            .textAlign(TextAlign.Center)
            .width(150)
          Text(`Expires in ${this.timeLeft()}`).fontSize(Theme.MICRO).fontColor(Theme.TEXT_3)
        } else if (this.ctrl.pairScreen === 'PAIRED') {
          Icon({ src: $r('app.media.ic_circle_check'), color: Theme.CALM, glyph: 36 })
          Text('Paired').fontSize(Theme.TITLE + 3).fontWeight(FontWeight.Bolder).fontColor(Theme.TEXT)
          Text('Your phone now sees this watch.')
            .fontSize(Theme.SMALL)
            .fontColor(Theme.TEXT_2)
            .textAlign(TextAlign.Center)
            .width(150)
        } else {
          Icon({ src: $r('app.media.ic_risk_possible'), color: Theme.ELEVATED, glyph: 28 })
          Text(this.ctrl.pairScreen === 'EXPIRED' ? 'Code expired' : 'Pairing failed')
            .fontSize(Theme.TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
          if (this.ctrl.pairScreen === 'ERROR') {
            Text(this.ctrl.pairError)
              .fontSize(Theme.MICRO)
              .fontColor(Theme.TEXT_2)
              .textAlign(TextAlign.Center)
              .maxLines(2)
              .width(150)
          }
          PillButton({ label: 'New code', bg: Theme.BRAND, fg: Theme.ON_LIGHT, pillWidth: 110, onTap: () => {
            this.newCode();
          } })
            .margin({ top: 4 })
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ bottom: 36 })

      if (this.ctrl.pairScreen !== 'LOADING') {
        EdgeButton({ label: this.ctrl.pairScreen === 'PAIRED' ? 'Done' : this.ctrl.pairScreen === 'CODE' ? 'Cancel' :
          'Close', onTap: () => {
          this.ctrl.closePairing();
        } })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
