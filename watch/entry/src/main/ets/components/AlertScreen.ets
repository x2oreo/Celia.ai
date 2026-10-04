import { WatchController } from '../controller/WatchController';
import { HRV_USUAL_MS } from '../vitals/MockedVitals';
import { USUAL_RECOVERY_DROP_BPM, stateWord } from '../vitals/WatchStatus';
import { Bezel, Caps, OkHelp, OutlineBadge, StatusMark } from './Parts';
import { Theme } from './Theme';

/** Seconds to answer a fall before an SOS goes out. */
const FALL_SECONDS: number = 30;

/** 10 Fall: the ring drains over 30 s; no answer sends an SOS. */
@ComponentV2
struct FallAlert {
  @Param @Require ctrl: WatchController;

  build() {
    Stack() {
      Bezel({ mode: 'RING', color: Theme.ALERT, fraction: this.ctrl.fallCountdown / FALL_SECONDS })
      Column({ space: 0 }) {
        Caps({ text: 'FALL DETECTED', color: Theme.BRAND })
        Text('Are you OK?').fontSize(Theme.TITLE + 2).fontWeight(FontWeight.Bolder).fontColor(Theme.TEXT)
        Row({ space: 3 }) {
          Text(`${this.ctrl.fallCountdown}`).fontSize(Theme.HERO - 6).fontWeight(FontWeight.Bolder)
            .fontColor(Theme.TEXT)
          Text('s').fontSize(Theme.TITLE + 2).fontWeight(FontWeight.Bolder).fontColor(Theme.TEXT).margin({ bottom: 12 })
        }
        .alignItems(VerticalAlign.Bottom)
        .margin({ top: -6, bottom: -6 })
        Text('No answer sends an SOS').fontSize(Theme.SMALL).fontColor(Theme.TEXT_2).margin({ bottom: 10 })
        OkHelp({ onOk: () => this.ctrl.imOk(), onHelp: () => this.ctrl.needHelp() })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}

/**
 * 07-09 Alerts: ring in the zone colour, caps title with its shape, the value (or a word), unit + context, the limit
 * and why (heart rate) or one line of advice (signals), and always I'm OK / Need help. Only a high heart rate is red;
 * low heart rate and every signal alert are amber.
 */
@ComponentV2
export struct AlertScreen {
  @Param @Require ctrl: WatchController;

  kind(): string {
    return this.ctrl.alertKind;
  }

  color(): string {
    return this.kind() === 'HIGH' ? Theme.ALERT : Theme.ELEVATED;
  }

  title(): string {
    switch (this.kind()) {
      case 'HIGH':
        return 'HEART RATE HIGH';
      case 'LOW':
        return 'HEART RATE LOW';
      case 'RHYTHM':
        return 'IRREGULAR RHYTHM';
      case 'HRV':
        return 'LOW HRV';
      case 'SPO2':
        return 'LOW OXYGEN';
      default:
        return 'SLOW RECOVERY';
    }
  }

  value(): string {
    switch (this.kind()) {
      case 'RHYTHM':
        return 'Irregular';
      case 'RECOVERY':
        return `-${Math.max(0, this.ctrl.recoveryDrop)}`;
      default:
        return `${this.ctrl.alertBpm}`;
    }
  }

  /** "at rest" for the unit line; '' when the state is unknown. */
  state(): string {
    return stateWord(this.ctrl.alertActivity).toLowerCase();
  }

  unit(): string {
    switch (this.kind()) {
      case 'HRV':
        return 'ms';
      case 'SPO2':
        return '%';
      case 'RECOVERY':
        return 'bpm in 1 min';
      case 'RHYTHM':
        return '';
      default:
        return 'bpm';
    }
  }

  /** What follows the unit: "· at rest", or "· usual 45" for HRV. */
  context(): string {
    if (this.kind() === 'HRV') {
      return `· usual ${HRV_USUAL_MS}`;
    }
    if (this.kind() === 'RECOVERY') {
      return '';
    }
    return this.state().length > 0 ? `· ${this.state()}` : '';
  }

  simulated(): boolean {
    return this.kind() === 'RHYTHM' || this.kind() === 'HRV' || this.kind() === 'SPO2';
  }

  /** Heart rate: the limit and why (from the rules). Signals: one line of advice. */
  note(): string {
    switch (this.kind()) {
      case 'HIGH':
      case 'LOW':
        return this.ctrl.alertText;
      case 'RHYTHM':
        return 'Sit down and breathe slowly.';
      case 'HRV':
        return 'Rest for a few minutes.';
      case 'SPO2':
        return 'Sit up and breathe deeply.';
      default:
        return `Usually -${USUAL_RECOVERY_DROP_BPM} after exercise. Take it easy for now.`;
    }
  }

  gentleWake(): boolean {
    return this.kind() === 'LOW' && this.ctrl.alertActivity === 'ASLEEP';
  }

  build() {
    if (this.ctrl.fallCountdown > 0) {
      FallAlert({ ctrl: this.ctrl })
    } else {
      Stack() {
        Bezel({ mode: 'RING', color: this.color(), strokeWidth: 10 })
        Column({ space: 0 }) {
          Row({ space: 4 }) {
            StatusMark({ mark: this.kind() === 'LOW' ? 'DOWN' : 'UP', color: this.color(), dim: 10 })
            Caps({ text: this.title(), color: this.color() })
          }
          Text(this.value())
            .fontSize(this.kind() === 'RHYTHM' ? Theme.NUMBER + 2 : this.gentleWake() ? Theme.HERO - 8 : Theme.HERO)
            .fontWeight(FontWeight.Bolder)
            .fontColor(this.color())
            .maxLines(1)
            .margin({ top: this.kind() === 'RHYTHM' ? 2 : -8, bottom: this.kind() === 'RHYTHM' ? 2 : -10 })
          Row({ space: 4 }) {
            if (this.unit().length > 0) {
              Text(this.unit()).fontSize(Theme.BODY).fontWeight(FontWeight.Regular).fontColor(Theme.TEXT)
            }
            if (this.simulated()) {
              OutlineBadge({ color: Theme.TEXT })
            }
            if (this.context().length > 0) {
              Text(this.context()).fontSize(Theme.BODY).fontWeight(FontWeight.Regular).fontColor(Theme.TEXT)
            }
          }
          Text(this.note())
            .fontSize(Theme.SMALL)
            .fontColor(Theme.TEXT_2)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Center)
            .width(160)
            .margin({ top: 2 })
          if (this.gentleWake()) {
            Text('))) Gentle wake-up tone').fontSize(Theme.SMALL).fontColor(Theme.ELEVATED).margin({ top: 2 })
          }
          OkHelp({ onOk: () => this.ctrl.imOk(), onHelp: () => this.ctrl.needHelp() }).margin({ top: 8 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.BG)
    }
  }
}
