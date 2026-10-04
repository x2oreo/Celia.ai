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
  spo2Level
} from '../vitals/WatchStatus';
import { Icon, SimBadge, StatusPill } from './Parts';
import { Theme } from './Theme';

/** One signal: icon well, caps label (+ SIM), value + unit, status pill. */
@ComponentV2
export struct VitalRow {
  @Param @Require icon: Resource;
  @Param @Require label: string;
  @Param @Require value: string;
  @Param unit: string = '';
  @Param level: Level = 'NONE';
  @Param showLevel: boolean = true;
  @Param simulated: boolean = false;

  spoken(): string {
    const sim = this.simulated ? ', simulated' : '';
    const lvl = this.showLevel ? `, ${levelWord(this.level)}` : '';
    return `${this.label} ${this.value} ${this.unit}${sim}${lvl}`;
  }

  build() {
    Row({ space: 8 }) {
      Stack() {
        Icon({ src: this.icon, color: Theme.BRAND, glyph: 16 })
      }
      .width(30)
      .height(30)
      .borderRadius(15)
      .backgroundColor(Theme.BUTTON)

      Column({ space: 1 }) {
        Row({ space: 4 }) {
          Text(this.label.toUpperCase())
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(0.8)
            .fontColor(Theme.TEXT_3)
            .maxLines(1)
          if (this.simulated) {
            SimBadge()
          }
        }
        Row({ space: 3 }) {
          Text(this.value)
            .fontSize(Theme.BODY + 2)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
            .maxLines(1)
          if (this.unit.length > 0) {
            Text(this.unit).fontSize(Theme.MICRO).fontColor(Theme.TEXT_2).margin({ bottom: 2 })
          }
        }
        .alignItems(VerticalAlign.Bottom)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.showLevel) {
        StatusPill({ level: this.level })
      }
    }
    .width(Theme.LIST_WIDTH)
    .height(Theme.ROW_HEIGHT)
    .padding({ left: 10, right: 10 })
    .borderRadius(Theme.ROW_HEIGHT / 2)
    .backgroundColor(Theme.SURFACE)
    .accessibilityGroup(true)
    .accessibilityText(this.spoken())
  }
}

/** Centred list title (first ArcList item). */
@ComponentV2
export struct ListTitle {
  @Param @Require title: string;
  @Param subtitle: string = '';

  build() {
    Column({ space: 2 }) {
      Text(this.title).fontSize(Theme.TITLE).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
      if (this.subtitle.length > 0) {
        Text(this.subtitle).fontSize(Theme.MICRO).fontColor(Theme.TEXT_3).maxLines(1)
      }
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
  }
}

/** Every signal the watch gives the risk model. SIM = simulated until Huawei opens it to watch apps. */
@ComponentV2
export struct VitalsPage {
  @Param @Require ctrl: WatchController;

  stateText(): string {
    switch (this.ctrl.activity) {
      case 'REST':
        return 'At rest';
      case 'ACTIVE':
        return 'Active';
      case 'ASLEEP':
        return 'Asleep';
      default:
        return '-';
    }
  }

  stateIcon(): Resource {
    switch (this.ctrl.activity) {
      case 'ACTIVE':
        return $r('app.media.ic_active');
      case 'ASLEEP':
        return $r('app.media.ic_asleep');
      default:
        return $r('app.media.ic_rest');
    }
  }

  num(v: number): string {
    return v > 0 ? `${v}` : '-';
  }

  recoveryValue(): string {
    return this.ctrl.recoveryDrop >= 0 ? `-${this.ctrl.recoveryDrop}` : '-';
  }

  recoveryLevel(): Level {
    if (this.ctrl.recoveryDrop < 0) {
      return 'NONE';
    }
    return this.ctrl.recoverySlow ? 'LOOK' : 'GOOD';
  }

  build() {
    ArcList({ initialIndex: 1 }) {
      ArcListItem() {
        ListTitle({ title: 'Vitals', subtitle: 'From your watch, now' })
      }
      ArcListItem() {
        VitalRow({ icon: $r('app.media.ic_heart_fill'), label: 'Resting', value: this.num(this.ctrl.restingBpm),
          unit: this.ctrl.restingMeasured ? 'bpm' : 'bpm est', level: restingLevel(this.ctrl.restingBpm) })
      }
      ArcListItem() {
        VitalRow({ icon: $r('app.media.ic_hrv'), label: 'HRV', value: this.num(this.ctrl.hrvMs), unit: 'ms',
          level: hrvLevel(this.ctrl.hrvMs), simulated: true })
      }
      ArcListItem() {
        VitalRow({ icon: $r('app.media.ic_spo2'), label: 'Oxygen', value: this.num(this.ctrl.spo2), unit: '%',
          level: spo2Level(this.ctrl.spo2), simulated: true })
      }
      ArcListItem() {
        VitalRow({ icon: $r('app.media.ic_breath'), label: 'Breathing', value: this.num(this.ctrl.breathingRate),
          unit: '/min', level: breathingLevel(this.ctrl.breathingRate), simulated: true })
      }
      ArcListItem() {
        VitalRow({ icon: $r('app.media.ic_rhythm'), label: 'Rhythm',
          value: this.ctrl.bpm > 0 ? (this.ctrl.irregularRhythm ? 'Irregular' : 'Regular') : '-',
          level: rhythmLevel(this.ctrl.irregularRhythm, this.ctrl.bpm > 0), simulated: true })
      }
      ArcListItem() {
        VitalRow({ icon: $r('app.media.ic_gauge'), label: 'Stress', value: this.ctrl.stress ? 'High' : 'Normal',
          level: this.ctrl.bpm > 0 ? (this.ctrl.stress ? 'LOOK' : 'GOOD') : 'NONE' })
      }
      ArcListItem() {
        VitalRow({ icon: $r('app.media.ic_timer'), label: 'Recovery', value: this.recoveryValue(),
          unit: this.ctrl.recoveryDrop >= 0 ? 'bpm in 1 min' : '', level: this.recoveryLevel() })
      }
      ArcListItem() {
        VitalRow({ icon: this.stateIcon(), label: 'State', value: this.stateText(), showLevel: false })
      }
      ArcListItem() {
        VitalRow({ icon: $r('app.media.ic_steps'), label: 'Steps', value: `${this.ctrl.steps}`, showLevel: false })
      }
      ArcListItem() {
        Text('Heart rate only. Never QT.')
          .fontSize(Theme.MICRO)
          .fontColor(Theme.TEXT_3)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 6, bottom: 48 })
      }
    }
    .space(LengthMetrics.vp(6))
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
  }
}
