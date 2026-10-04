import { WatchController } from '../controller/WatchController';
import { HeartBeat, Icon, PillButton, Ring } from './Parts';
import { Theme } from './Theme';

/**
 * W2 / W3 alert: ring in the zone colour, caps title with its shape, big number, context, I'm OK / Need help.
 * Also a fall (the ring drains over 30 s), irregular rhythm, low HRV / oxygen and slow recovery.
 */
@ComponentV2
export struct AlertScreen {
  @Param @Require ctrl: WatchController;

  isFall(): boolean {
    return this.ctrl.fallCountdown > 0;
  }

  /** Amber for a heart rate that is low or near-normal-but-flagged; red where it is a real alarm. */
  color(): string {
    if (this.isFall()) {
      return Theme.ELEVATED;
    }
    switch (this.ctrl.alertKind) {
      case 'HIGH':
      case 'RHYTHM':
      case 'SPO2':
        return Theme.ALERT;
      default:
        return Theme.ELEVATED;
    }
  }

  shape(): Resource {
    return this.color() === Theme.ALERT ? $r('app.media.ic_risk_known') : $r('app.media.ic_risk_possible');
  }

  ringPercent(): number {
    return this.isFall() ? this.ctrl.fallCountdown / 30 * 100 : 100;
  }

  title(): string {
    if (this.isFall()) {
      return 'FALL DETECTED';
    }
    switch (this.ctrl.alertKind) {
      case 'HIGH':
        return 'HEART RATE HIGH';
      case 'LOW':
        return 'HEART RATE LOW';
      case 'RHYTHM':
        return 'IRREGULAR RHYTHM';
      case 'HRV':
        return 'HRV LOW';
      case 'SPO2':
        return 'OXYGEN LOW';
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
        return ' · active';
      case 'ASLEEP':
        return ' · asleep';
      default:
        return '';
    }
  }

  unit(): string {
    if (this.isFall()) {
      return 'seconds to answer';
    }
    switch (this.ctrl.alertKind) {
      case 'RECOVERY':
        return 'bpm 1 min after exercise';
      case 'HRV':
        return `ms HRV${this.stateWord()}`;
      case 'SPO2':
        return `% oxygen${this.stateWord()}`;
      default:
        return `bpm${this.stateWord()}`;
    }
  }

  note(): string {
    if (this.isFall()) {
      return 'No answer sends an SOS';
    }
    if (this.ctrl.alertKind === 'LOW' && this.ctrl.alertActivity === 'ASLEEP') {
      return 'Gentle wake-up tone';
    }
    return this.ctrl.alertText;
  }

  isHeartRate(): boolean {
    return !this.isFall() && (this.ctrl.alertKind === 'HIGH' || this.ctrl.alertKind === 'LOW');
  }

  build() {
    Stack() {
      Ring({ percent: this.ringPercent(), color: this.color(), strokeWidth: 10 })
      Column({ space: 0 }) {
        Row({ space: 4 }) {
          Icon({ src: this.isFall() ? $r('app.media.ic_zap') : this.shape(), color: this.color(), glyph: 12 })
          Text(this.title())
            .fontSize(Theme.CAPS)
            .fontWeight(FontWeight.Bolder)
            .letterSpacing(1)
            .fontColor(this.color())
        }
        Row({ space: 4 }) {
          Text(this.bigNumber())
            .fontSize(Theme.HERO)
            .fontWeight(FontWeight.Bolder)
            .fontColor(this.color())
          if (this.isHeartRate()) {
            HeartBeat({ periodMs: 500, color: this.color(), glyph: 16 }).margin({ bottom: 16 })
          }
        }
        .alignItems(VerticalAlign.Bottom)
        Text(this.unit()).fontSize(Theme.SMALL).fontColor(Theme.TEXT).margin({ top: -4 })
        Text(this.note())
          .fontSize(Theme.MICRO)
          .fontColor(Theme.TEXT_2)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .width(150)
          .margin({ top: 3, bottom: 8 })
        Row({ space: 6 }) {
          PillButton({ label: "I'm OK", pillWidth: 72, onTap: () => {
            this.ctrl.imOk();
          } })
          PillButton({ label: 'Need help', bg: Theme.ALERT, pillWidth: 88, onTap: () => {
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
