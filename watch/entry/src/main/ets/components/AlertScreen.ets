import { WatchController } from '../controller/WatchController';
import { Pill } from './Pill';
import { Ring } from './Ring';
import { Theme } from './Theme';

/**
 * W2 / W3 style alert: coloured ring, title, big number, context, I'm OK / Need help.
 * Also used for a fall (countdown), irregular rhythm and slow recovery.
 */
@ComponentV2
export struct AlertScreen {
  @Param @Require ctrl: WatchController;

  isFall(): boolean {
    return this.ctrl.fallCountdown > 0;
  }

  color(): string {
    if (this.isFall()) {
      return Theme.WARN;
    }
    switch (this.ctrl.alertKind) {
      case 'LOW':
        return Theme.LOW;
      case 'RHYTHM':
        return Theme.DANGER;
      default:
        return Theme.WARN;
    }
  }

  ringPercent(): number {
    if (this.isFall()) {
      return this.ctrl.fallCountdown / 30 * 100;
    }
    return this.ctrl.alertKind === 'LOW' ? 18 : 100;
  }

  title(): string {
    if (this.isFall()) {
      return 'FALL DETECTED';
    }
    switch (this.ctrl.alertKind) {
      case 'HIGH':
        return '))) HEART RATE HIGH';
      case 'LOW':
        return 'HEART RATE LOW';
      case 'RHYTHM':
        return '))) IRREGULAR RHYTHM';
      default:
        return 'SLOW RECOVERY';
    }
  }

  bigNumber(): string {
    return this.isFall() ? `${this.ctrl.fallCountdown}` : `${this.ctrl.alertBpm}`;
  }

  stateWord(): string {
    switch (this.ctrl.alertActivity) {
      case 'REST':
        return ' · at rest';
      case 'ACTIVE':
        return ' · during activity';
      case 'ASLEEP':
        return ' · while asleep';
      default:
        return '';
    }
  }

  subtitle(): string {
    if (this.isFall()) {
      return 'seconds to answer';
    }
    if (this.ctrl.alertKind === 'RECOVERY') {
      return 'bpm 1 min after exercise';
    }
    return `bpm${this.stateWord()}`;
  }

  note(): string {
    if (this.isFall()) {
      return 'No answer = SOS';
    }
    if (this.ctrl.alertKind === 'LOW' && this.ctrl.alertActivity === 'ASLEEP') {
      return 'Gentle wake-up tone';
    }
    return this.ctrl.alertText;
  }

  build() {
    Stack() {
      Ring({ percent: this.ringPercent(), color: this.color(), strokeWidth: 10 })
      Column({ space: 2 }) {
        Text(this.title())
          .fontSize(10)
          .fontWeight(FontWeight.Bolder)
          .letterSpacing(1)
          .fontColor(this.color())
        Text(this.bigNumber())
          .fontSize(48)
          .fontWeight(FontWeight.Bolder)
          .fontColor(this.color())
        Text(this.subtitle()).fontSize(12).fontColor(Theme.TEXT)
        Text(this.note())
          .fontSize(9)
          .fontColor(Theme.MUTED)
          .maxLines(2)
          .textAlign(TextAlign.Center)
          .width(140)
          .margin({ bottom: 4 })
        Row({ space: 4 }) {
          Pill({ label: "I'm OK", pillWidth: 62, pillHeight: 30, fontSize: 12, onTap: () => {
            this.ctrl.imOk();
          } })
          Pill({ label: 'Need help', bg: Theme.DANGER, pillWidth: 78, pillHeight: 30, fontSize: 12, onTap: () => {
            this.ctrl.needHelp();
          } })
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
