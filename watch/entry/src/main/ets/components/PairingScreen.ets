import { WatchController } from '../controller/WatchController';
import { formatPairCode } from '../sync/PairingClient';
import { Pill } from './Pill';
import { Ring } from './Ring';
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
    Stack() {
      if (this.ctrl.pairScreen === 'PAIRED') {
        Ring({ percent: 100, color: Theme.OK })
      } else if (this.ctrl.pairScreen === 'CODE') {
        Ring({ percent: Math.min(100, this.ctrl.pairSecondsLeft / 6), color: Theme.INFO })
      }
      Column({ space: 4 }) {
        if (this.ctrl.pairScreen === 'LOADING') {
          Text('Getting a code…').fontSize(14).fontColor(Theme.MUTED)
        } else if (this.ctrl.pairScreen === 'CODE') {
          Text('PAIR WITH PHONE').fontSize(10).fontWeight(FontWeight.Bolder).letterSpacing(1).fontColor(Theme.INFO)
          Text(formatPairCode(this.ctrl.pairCode)).fontSize(38).fontWeight(FontWeight.Bolder).fontColor(Theme.TEXT)
          Text('Enter this code in the Celia phone app')
            .fontSize(10)
            .fontColor(Theme.MUTED)
            .textAlign(TextAlign.Center)
            .width(150)
          Text(`Expires in ${this.timeLeft()}`).fontSize(11).fontColor(Theme.TEXT).margin({ bottom: 4 })
          Pill({ label: 'Cancel', pillWidth: 90, pillHeight: 30, fontSize: 12, onTap: () => {
            this.ctrl.closePairing();
          } })
        } else if (this.ctrl.pairScreen === 'PAIRED') {
          Text('✓').fontSize(36).fontWeight(FontWeight.Bold).fontColor(Theme.OK)
          Text('Paired').fontSize(20).fontWeight(FontWeight.Bolder).fontColor(Theme.TEXT)
          Text('Your phone now receives this watch.')
            .fontSize(11)
            .fontColor(Theme.MUTED)
            .textAlign(TextAlign.Center)
            .width(150)
            .margin({ bottom: 6 })
          Pill({ label: 'Done', bg: Theme.OK, fg: '#000000', pillWidth: 90, pillHeight: 30, fontSize: 12, onTap: () => {
            this.ctrl.closePairing();
          } })
        } else {
          Text(this.ctrl.pairScreen === 'EXPIRED' ? 'Code expired' : 'Pairing failed')
            .fontSize(18)
            .fontWeight(FontWeight.Bolder)
            .fontColor(Theme.TEXT)
          if (this.ctrl.pairScreen === 'ERROR') {
            Text(this.ctrl.pairError).fontSize(11).fontColor(Theme.MUTED).textAlign(TextAlign.Center).width(150)
          }
          Row({ space: 4 }) {
            Pill({ label: 'New code', bg: Theme.INFO, pillWidth: 80, pillHeight: 30, fontSize: 12, onTap: () => {
              this.newCode();
            } })
            Pill({ label: 'Close', pillWidth: 64, pillHeight: 30, fontSize: 12, onTap: () => {
              this.ctrl.closePairing();
            } })
          }
          .margin({ top: 6 })
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
