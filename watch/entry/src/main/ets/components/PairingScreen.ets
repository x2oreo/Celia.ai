import { WatchController } from '../controller/WatchController';
import { formatPairCode } from '../sync/PairingClient';
import { Bezel, Caps, CheckDisc, PillButton } from './Parts';
import { Theme } from './Theme';

/**
 * 16 Pairing: a spinner while the code is fetched, the code with a draining coral ring, then Paired (green), Code
 * expired (dashed grey: nothing is wrong with your heart) or Pairing failed (dashed amber + the reason).
 */
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

  @Builder
  bezel() {
    if (this.ctrl.pairScreen === 'LOADING') {
      Bezel({ mode: 'SPIN', color: Theme.BRAND })
    } else if (this.ctrl.pairScreen === 'CODE') {
      Bezel({ mode: 'RING', color: Theme.BRAND, fraction: this.ctrl.pairTotalSeconds > 0 ?
        this.ctrl.pairSecondsLeft / this.ctrl.pairTotalSeconds : 1 })
    } else if (this.ctrl.pairScreen === 'PAIRED') {
      Bezel({ mode: 'RING', color: Theme.CALM })
    } else {
      Bezel({ mode: 'DASHED', color: this.ctrl.pairScreen === 'EXPIRED' ? Theme.BORDER : Theme.ELEVATED })
    }
  }

  @Builder
  title(text: string) {
    Text(text).fontSize(Theme.TITLE + 3).fontWeight(FontWeight.Bolder).fontColor(Theme.TEXT)
  }

  @Builder
  line(text: string) {
    Text(text)
      .fontSize(Theme.SMALL)
      .fontColor(Theme.TEXT_2)
      .textAlign(TextAlign.Center)
      .maxLines(3)
      .width(160)
  }

  build() {
    Stack() {
      this.bezel()
      Column({ space: 5 }) {
        if (this.ctrl.pairScreen === 'LOADING') {
          this.title('Getting a code...')
          this.line('Pair with phone')
          PillButton({ label: 'Cancel', pillWidth: 90, onTap: () => this.ctrl.closePairing() }).margin({ top: 6 })
        } else if (this.ctrl.pairScreen === 'CODE') {
          Caps({ text: 'PAIR WITH PHONE' })
          Text(formatPairCode(this.ctrl.pairCode))
            .fontSize(Theme.CODE)
            .fontWeight(FontWeight.Medium)
            .letterSpacing(2)
            .fontColor(Theme.TEXT)
            .accessibilityText(`Code ${this.ctrl.pairCode.split('').join(' ')}`)
          Text('Type this code in Celia on your phone')
            .fontSize(Theme.BODY - 1)
            .fontColor(Theme.TEXT)
            .textAlign(TextAlign.Center)
            .width(160)
          Text(`Expires in ${this.timeLeft()}`).fontSize(Theme.SMALL).fontColor(Theme.TEXT_2)
          PillButton({ label: 'Cancel', pillWidth: 90, onTap: () => this.ctrl.closePairing() }).margin({ top: 4 })
        } else if (this.ctrl.pairScreen === 'PAIRED') {
          CheckDisc()
          this.title('Paired')
          this.line('Your phone')
          PillButton({ label: 'Done', pillWidth: 90, onTap: () => this.ctrl.closePairing() }).margin({ top: 6 })
        } else {
          this.title(this.ctrl.pairScreen === 'EXPIRED' ? 'Code expired' : 'Pairing failed')
          this.line(this.ctrl.pairScreen === 'EXPIRED' ? 'Get a new code and type it on your phone.' :
            this.ctrl.pairError)
          Row({ space: 8 }) {
            PillButton({ label: 'New code', bg: Theme.BRAND, pillWidth: 96, onTap: () => this.newCode() })
            PillButton({ label: 'Close', pillWidth: 72, onTap: () => this.ctrl.closePairing() })
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
