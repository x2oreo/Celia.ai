// ArcListAttribute / ArcListItemAttribute must be imported by hand up to API 21 (our minimum is 20).
import { ArcList, ArcListAttribute, ArcListItem, ArcListItemAttribute, LengthMetrics } from '@kit.ArkUI';
import { WatchController } from '../controller/WatchController';
import {
  Level,
  breathingLevel,
  hrvLevel,
  levelWord,
  restingLevel,
  rhythmLevel,
  spo2Level,
  stateWord
} from '../vitals/WatchStatus';
import { Caps, OutlineBadge, StatusWord } from './Parts';
import { Theme } from './Theme';

/** 4812 -> "4,812". */
function thousands(n: number): string {
  return `${Math.round(n)}`.replace(new RegExp('\\B(?=(\\d{3})+(?!\\d))', 'g'), ',');
}

/** One signal per row: label (+ SIM), value + unit, status mark + word on the right, a divider under it. */
@ComponentV2
export struct VitalRow {
  @Param @Require label: string;
  @Param @Require value: string;
  @Param unit: string = '';
  @Param level: Level = 'NONE';
  @Param showLevel: boolean = true;
  @Param simulated: boolean = false;
  @Param divider: boolean = true;

  spoken(): string {
    const sim = this.simulated ? ', simulated' : '';
    const lvl = this.showLevel ? `, ${levelWord(this.level)}` : '';
    return `${this.label} ${this.value} ${this.unit}${sim}${lvl}`;
  }

  build() {
    Column({ space: 0 }) {
      Row({ space: 4 }) {
        Text(this.label).fontSize(Theme.SMALL).fontColor(Theme.TEXT_2).maxLines(1)
        if (this.simulated) {
          OutlineBadge()
        }
      }
      Row({ space: 4 }) {
        Text(this.value)
          .fontSize(Theme.TITLE + 2)
          .fontWeight(FontWeight.Bolder)
          .fontColor(Theme.TEXT)
          .maxLines(1)
        if (this.unit.length > 0) {
          Text(this.unit).fontSize(Theme.SMALL).fontColor(Theme.TEXT_2).margin({ bottom: 2 })
        }
        Blank()
        if (this.showLevel) {
          StatusWord({ level: this.level }).margin({ bottom: 3 })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
      if (this.divider) {
        Divider().color(Theme.BORDER).strokeWidth(1).margin({ top: 6 })
      }
    }
    .width(Theme.LIST_WIDTH)
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 2, bottom: 2 })
    .accessibilityGroup(true)
    .accessibilityText(this.spoken())
  }
}

/** Centred caps title (first ArcList item). */
@ComponentV2
export struct ListTitle {
  @Param @Require title: string;

  build() {
    Row() {
      Caps({ text: this.title.toUpperCase() })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 4, bottom: 2 })
  }
}

/** 03 Vitals: every signal the watch gives the risk model, one per row. SIM = simulated (Huawei measures it). */
@ComponentV2
export struct VitalsPage {
  @Param @Require ctrl: WatchController;

  num(v: number): string {
    return v > 0 ? `${Math.round(v)}` : '-';
  }

  recoveryLevel(): Level {
    if (this.ctrl.recoveryDrop < 0) {
      return 'NONE';
    }
    return this.ctrl.recoverySlow ? 'LOOK' : 'GOOD';
  }

  build() {
    ArcList({ initialIndex: 2 }) {
      ArcListItem() {
        ListTitle({ title: 'Vitals' })
      }
      .autoScale(false)
      ArcListItem() {
        VitalRow({ label: 'Resting HR', value: this.num(this.ctrl.restingBpm), unit: 'bpm',
          level: restingLevel(this.ctrl.restingBpm) })
      }
      .autoScale(false)
      ArcListItem() {
        VitalRow({ label: 'HRV', value: this.num(this.ctrl.hrvMs), unit: 'ms', level: hrvLevel(this.ctrl.hrvMs),
          simulated: true })
      }
      .autoScale(false)
      ArcListItem() {
        VitalRow({ label: 'Blood oxygen', value: this.num(this.ctrl.spo2), unit: '%', level: spo2Level(this.ctrl.spo2),
          simulated: true })
      }
      .autoScale(false)
      ArcListItem() {
        VitalRow({ label: 'Breathing', value: this.num(this.ctrl.breathingRate), unit: '/min',
          level: breathingLevel(this.ctrl.breathingRate), simulated: true })
      }
      .autoScale(false)
      ArcListItem() {
        VitalRow({ label: 'Rhythm', value: this.ctrl.bpm > 0 ? (this.ctrl.irregularRhythm ? 'Irregular' : 'Regular') :
          '-', level: rhythmLevel(this.ctrl.irregularRhythm, this.ctrl.bpm > 0), simulated: true })
      }
      .autoScale(false)
      ArcListItem() {
        VitalRow({ label: 'Stress', value: this.ctrl.bpm > 0 ? (this.ctrl.stress ? 'High' : 'Normal') : '-',
          level: this.ctrl.bpm > 0 ? (this.ctrl.stress ? 'LOOK' : 'GOOD') : 'NONE' })
      }
      .autoScale(false)
      ArcListItem() {
        VitalRow({ label: 'Recovery', value: this.ctrl.recoveryDrop >= 0 ? `-${this.ctrl.recoveryDrop}` : '-',
          unit: this.ctrl.recoveryDrop >= 0 ? 'bpm' : '', level: this.recoveryLevel() })
      }
      .autoScale(false)
      ArcListItem() {
        VitalRow({ label: 'State', value: stateWord(this.ctrl.activity).length > 0 ?
          stateWord(this.ctrl.activity) : '-', showLevel: false })
      }
      .autoScale(false)
      ArcListItem() {
        VitalRow({ label: 'Steps', value: thousands(this.ctrl.steps), showLevel: false })
      }
      .autoScale(false)
      ArcListItem() {
        Text('Heart rate only. Never QT.')
          .fontSize(Theme.SMALL)
          .fontColor(Theme.TEXT_2)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 4, bottom: 48 })
      }
      .autoScale(false)
    }
    .space(LengthMetrics.vp(6))
    .scrollBar(BarState.Auto)
    .width('100%')
    .height('100%')
  }
}
