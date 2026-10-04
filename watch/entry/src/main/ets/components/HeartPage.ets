import { WatchController } from '../controller/WatchController';
import { drugBadgeText } from '../vitals/DrugBadge';
import { Zone, beatPeriodMs, ringRatio, zoneFor, zoneWord } from '../vitals/WatchStatus';
import { DashedRing, HeartBeat, Icon, Ring, SimBadge, zoneColor, zoneShape } from './Parts';
import { Theme } from './Theme';

/** W7: shown instead of Home while the watch is off the wrist. */
@ComponentV2
struct NotWorn {
  build() {
    Stack() {
      DashedRing()
      Column({ space: 6 }) {
        Icon({ src: $r('app.media.ic_watch'), color: Theme.TEXT_3, glyph: 28 })
        Text('Not on wrist').fontSize(Theme.TITLE).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
        Text('Put your watch back on to keep watching your heart.')
          .fontSize(Theme.SMALL)
          .fontColor(Theme.TEXT_2)
          .textAlign(TextAlign.Center)
          .width(150)
      }
    }
    .width('100%')
    .height('100%')
    .accessibilityGroup(true)
    .accessibilityText('Not on wrist. Put your watch back on to keep watching your heart.')
  }
}

/** W1 Home: ring = where the bpm sits between your min and max, status word + shape, bpm, context, link. */
@ComponentV2
export struct HeartPage {
  @Param @Require ctrl: WatchController;

  zone(): Zone {
    return zoneFor(this.ctrl.bpm, this.ctrl.limitLow, this.ctrl.limitHigh, this.ctrl.stress);
  }

  statusWord(): string {
    if (this.ctrl.bpm <= 0) {
      return this.ctrl.statusText.length > 0 ? this.ctrl.statusText : 'Starting';
    }
    return this.ctrl.stress && this.zone() === 'NEAR' && this.ctrl.bpm < this.ctrl.limitHigh * 0.9 ?
      'Stressed' : zoneWord(this.zone());
  }

  stateWord(): string {
    switch (this.ctrl.activity) {
      case 'REST':
        return 'At rest';
      case 'ACTIVE':
        return 'Active';
      case 'ASLEEP':
        return 'Asleep';
      default:
        return '';
    }
  }

  contextLine(): string {
    const s = this.stateWord();
    return s.length > 0 ? `${s} · max ${this.ctrl.limitHigh}` : `Max ${this.ctrl.limitHigh}`;
  }

  phoneText(): string {
    switch (this.ctrl.syncState) {
      case 'OK':
        return 'Phone';
      case 'PENDING':
        return 'Syncing';
      case 'ERROR':
        return 'Phone off';
      default:
        return 'Offline';
    }
  }

  phoneColor(): string {
    switch (this.ctrl.syncState) {
      case 'OK':
        return Theme.CALM;
      case 'PENDING':
        return Theme.TEXT_2;
      default:
        return Theme.ELEVATED;
    }
  }

  badge(): string {
    return drugBadgeText(this.ctrl.riskyDrug, this.ctrl.riskyDrugAt, Date.now());
  }

  /** One sentence for the screen reader instead of eight fragments. */
  spoken(): string {
    if (this.ctrl.bpm <= 0) {
      return `Heart rate not available. ${this.statusWord()}.`;
    }
    return `Heart rate ${this.ctrl.bpm} beats per minute. ${this.statusWord()}. ${this.contextLine()}.`;
  }

  build() {
    if (!this.ctrl.onWrist) {
      NotWorn()
    } else {
      Stack() {
        if (this.ctrl.bpm > 0) {
          Ring({ percent: ringRatio(this.ctrl.bpm, this.ctrl.limitLow, this.ctrl.limitHigh) * 100,
            color: zoneColor(this.zone()) })
        } else {
          DashedRing()
        }
        Column({ space: 0 }) {
          Row({ space: 5 }) {
            Icon({ src: zoneShape(this.zone()), color: zoneColor(this.zone()), glyph: 14 })
            Text(this.statusWord())
              .fontSize(Theme.SMALL)
              .fontWeight(FontWeight.Bold)
              .fontColor(zoneColor(this.zone()))
              .maxLines(1)
          }

          Row({ space: 4 }) {
            Text(this.ctrl.bpm > 0 ? `${this.ctrl.bpm}` : '--')
              .fontSize(Theme.HERO)
              .fontWeight(FontWeight.Bolder)
              .fontColor(Theme.TEXT)
            Column({ space: 2 }) {
              HeartBeat({ periodMs: beatPeriodMs(this.zone()), beating: this.ctrl.bpm > 0,
                color: this.zone() === 'ABOVE' ? Theme.ALERT : Theme.BRAND })
              Text('bpm').fontSize(Theme.SMALL).fontColor(Theme.TEXT_2)
            }
            .margin({ bottom: 12 })
          }
          .alignItems(VerticalAlign.Bottom)
          .margin({ top: -2 })

          Text(this.contextLine())
            .fontSize(Theme.SMALL)
            .fontColor(Theme.TEXT_2)
            .margin({ top: -4 })

          // A QT-risk drug taken in the last 72 h: amber = watching more closely (red is for alerts).
          if (this.badge().length > 0) {
            Row({ space: 4 }) {
              Text('!').fontSize(Theme.MICRO).fontWeight(FontWeight.Bolder).fontColor(Theme.ELEVATED)
              Text(this.badge())
                .fontSize(Theme.MICRO)
                .fontWeight(FontWeight.Medium)
                .fontColor(Theme.ELEVATED)
                .maxLines(1)
            }
            .height(22)
            .padding({ left: 8, right: 8 })
            .borderRadius(11)
            .backgroundColor(Theme.ELEVATED_TINT)
            .margin({ top: 8 })
          }

          Row({ space: 6 }) {
            if (this.ctrl.genotype !== 'UNKNOWN') {
              Text(this.ctrl.genotype).fontSize(Theme.MICRO).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
              Divider().vertical(true).height(10).color(Theme.BORDER).strokeWidth(1)
            }
            Row({ space: 3 }) {
              Icon({ src: $r('app.media.ic_phone_link'), color: this.phoneColor(), glyph: 11 })
              Text(this.phoneText()).fontSize(Theme.MICRO).fontWeight(FontWeight.Bold).fontColor(this.phoneColor())
            }
          }
          .height(22)
          .padding({ left: 10, right: 10 })
          .borderRadius(11)
          .backgroundColor(Theme.SURFACE)
          .margin({ top: this.badge().length > 0 ? 4 : 10 })

          if (this.ctrl.sourceKind === 'SIMULATED') {
            SimBadge({ label: 'DEMO DATA' }).margin({ top: 6 })
          }
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .accessibilityGroup(true)
      .accessibilityText(this.spoken())
    }
  }
}
