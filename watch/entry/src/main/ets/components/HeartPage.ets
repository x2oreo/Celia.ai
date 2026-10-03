import { WatchController } from '../controller/WatchController';
import { Ring } from './Ring';
import { Theme } from './Theme';

/** W7: shown instead of Home while the watch is off the wrist. */
@ComponentV2
struct NotWorn {
  build() {
    Stack() {
      Circle()
        .width('94%')
        .height('94%')
        .fill(Theme.TRACK)
        .stroke(Theme.DASH)
        .strokeWidth(4)
        .strokeDashArray([14, 10])
      Column({ space: 6 }) {
        Text('– –').fontSize(28).fontWeight(FontWeight.Bold).fontColor(Theme.DASH)
        Text('Not on wrist').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
        Text('Put your watch back on to keep watching your heart.')
          .fontSize(11)
          .fontColor(Theme.MUTED)
          .textAlign(TextAlign.Center)
          .width(150)
      }
    }
    .width('100%')
    .height('100%')
  }
}

/** W1 Home: status, big bpm, genotype + phone link, ring = bpm relative to the current max. */
@ComponentV2
export struct HeartPage {
  @Param @Require ctrl: WatchController;

  /** Ring fill: where the current bpm sits between your min (empty) and max (full) limit. */
  ratio(): number {
    const span = this.ctrl.limitHigh - this.ctrl.limitLow;
    if (span <= 0 || this.ctrl.bpm <= 0) {
      return 0;
    }
    return Math.max(0.03, Math.min(1, (this.ctrl.bpm - this.ctrl.limitLow) / span));
  }

  status(): string {
    if (this.ctrl.bpm <= 0) {
      return this.ctrl.statusText.length > 0 ? this.ctrl.statusText : 'Starting…';
    }
    if (this.ctrl.bpm > this.ctrl.limitHigh) {
      return 'Above your max';
    }
    if (this.ctrl.bpm < this.ctrl.limitLow) {
      return 'Below your min';
    }
    if (this.ctrl.bpm >= this.ctrl.limitHigh * 0.9 || this.ctrl.stress) {
      return 'Elevated';
    }
    return 'All good';
  }

  statusColor(): string {
    if (this.ctrl.bpm <= 0) {
      return Theme.MUTED;
    }
    if (this.ctrl.bpm > this.ctrl.limitHigh) {
      return Theme.DANGER;
    }
    if (this.ctrl.bpm < this.ctrl.limitLow) {
      return Theme.LOW;
    }
    if (this.ctrl.bpm >= this.ctrl.limitHigh * 0.9 || this.ctrl.stress) {
      return Theme.WARN;
    }
    return Theme.OK;
  }

  phoneMark(): string {
    switch (this.ctrl.syncState) {
      case 'OK':
        return 'Phone ✓';
      case 'PENDING':
        return 'Phone ↑';
      case 'ERROR':
        return 'Phone ✕';
      default:
        return 'Offline';
    }
  }

  pillText(): string {
    const g = this.ctrl.genotype === 'UNKNOWN' ? '' : `${this.ctrl.genotype} · `;
    return `${g}${this.phoneMark()}`;
  }

  stateWord(): string {
    switch (this.ctrl.activity) {
      case 'REST':
        return 'at rest';
      case 'ACTIVE':
        return 'active';
      case 'ASLEEP':
        return 'asleep';
      default:
        return '';
    }
  }

  /** One sentence for the screen reader instead of eight fragments. */
  spoken(): string {
    if (this.ctrl.bpm <= 0) {
      return `Heart rate not available. ${this.status()}`;
    }
    return `Heart rate ${this.ctrl.bpm} beats per minute ${this.stateWord()}. ${this.status()}. ` +
      `Your maximum is ${this.ctrl.limitHigh}.`;
  }

  build() {
    if (!this.ctrl.onWrist) {
      NotWorn()
    } else {
      Stack() {
        Ring({ percent: this.ratio() * 100, color: this.statusColor() })
        Column({ space: 2 }) {
          Row({ space: 4 }) {
            Circle().width(7).height(7).fill(this.statusColor())
            Text(this.status()).fontSize(11).fontWeight(FontWeight.Bold).fontColor(this.statusColor()).maxLines(1)
          }

          Text(this.ctrl.bpm > 0 ? `${this.ctrl.bpm}` : '--')
            .fontSize(56)
            .fontWeight(FontWeight.Bolder)
            .fontColor(Theme.TEXT)

          Text(this.stateWord().length > 0 ? `bpm · ${this.stateWord()} · max ${this.ctrl.limitHigh}` : 'bpm')
            .fontSize(11)
            .fontColor(Theme.MUTED)

          Row({ space: 4 }) {
            Text('HRV').fontSize(11).fontColor(Theme.MUTED)
            Text(this.ctrl.hrvMs > 0 ? `${this.ctrl.hrvMs} ms` : '—')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.ctrl.hrvMs > 0 && this.ctrl.hrvMs < 20 ? Theme.DANGER : Theme.TEXT)
            Text('sim').fontSize(10).fontColor(Theme.WARN)
          }
          .margin({ top: 2 })

          Text(this.pillText())
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.TEXT)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .borderRadius(10)
            .backgroundColor(Theme.CARD)
            .margin({ top: 4 })

          if (this.ctrl.sourceKind === 'SIMULATED') {
            Text(`DEMO · ${this.ctrl.scenarioLabel}`).fontSize(10).fontColor(Theme.WARN).margin({ top: 2 })
          }
        }
      }
      .width('100%')
      .height('100%')
      .accessibilityGroup(true)
      .accessibilityText(this.spoken())
    }
  }
}
