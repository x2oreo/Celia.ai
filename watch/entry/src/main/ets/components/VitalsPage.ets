import { WatchController } from '../controller/WatchController';
import { Theme } from './Theme';

/** One tile: label, value, and a "sim" tag for signals Huawei measures but watch apps can't read yet. */
@ComponentV2
struct Tile {
  @Param @Require label: string;
  @Param @Require value: string;
  @Param simulated: boolean = false;
  @Param warn: boolean = false;

  build() {
    Column({ space: 1 }) {
      Row({ space: 3 }) {
        Text(this.label).fontSize(8).fontColor(Theme.MUTED)
        if (this.simulated) {
          Text('sim').fontSize(7).fontColor(Theme.WARN)
        }
      }
      Text(this.value)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.warn ? Theme.DANGER : Theme.TEXT)
        .maxLines(1)
    }
    .width(74)
    .height(34)
    .justifyContent(FlexAlign.Center)
    .borderRadius(10)
    .backgroundColor(Theme.CARD)
  }
}

/** All risk-model inputs the watch provides. Values tagged "sim" are simulated (see watch/README.md). */
@ComponentV2
export struct VitalsPage {
  @Param @Require ctrl: WatchController;

  stateText(): string {
    switch (this.ctrl.activity) {
      case 'REST':
        return 'Rest';
      case 'ACTIVE':
        return 'Active';
      case 'ASLEEP':
        return 'Asleep';
      default:
        return '—';
    }
  }

  orDash(v: number, unit: string): string {
    return v > 0 ? `${v}${unit}` : '—';
  }

  build() {
    Column({ space: 4 }) {
      Row({ space: 4 }) {
        Tile({ label: 'Resting', value: `${this.ctrl.restingBpm}${this.ctrl.restingMeasured ? '' : ' est'}` })
        Tile({ label: 'State', value: this.stateText() })
      }
      Row({ space: 4 }) {
        Tile({ label: 'Recovery', value: this.ctrl.lastRecovery.length > 0 ? this.ctrl.lastRecovery : '—',
          warn: this.ctrl.lastRecovery.endsWith('slow') })
        Tile({ label: 'Stress', value: this.ctrl.stress ? 'High' : 'Normal', warn: this.ctrl.stress })
        Tile({ label: 'Steps', value: `${this.ctrl.steps}` })
      }
      Row({ space: 4 }) {
        Tile({ label: 'HRV', value: this.orDash(this.ctrl.hrvMs, ' ms'), simulated: true })
        Tile({ label: 'SpO2', value: this.orDash(this.ctrl.spo2, '%'), simulated: true,
          warn: this.ctrl.spo2 > 0 && this.ctrl.spo2 < 94 })
        Tile({ label: 'Breath', value: this.orDash(this.ctrl.breathingRate, '/min'), simulated: true })
      }
      Row({ space: 4 }) {
        Tile({ label: 'Rhythm', value: this.ctrl.irregularRhythm ? 'Irregular' : 'Regular', simulated: true,
          warn: this.ctrl.irregularRhythm })
        Tile({ label: 'Genotype', value: this.ctrl.genotype === 'UNKNOWN' ? '—' : this.ctrl.genotype })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
