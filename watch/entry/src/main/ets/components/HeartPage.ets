import { WatchController } from '../controller/WatchController';
import { drugBadgeText } from '../vitals/DrugBadge';
import { Zone, contextLine, ringRatio, zoneFor, zoneWord } from '../vitals/WatchStatus';
import { Bezel, Chip, NoNumber, OutlineBadge, StatusMark, zoneColor, zoneMark } from './Parts';
import { Theme } from './Theme';

/** 1.6: shown instead of Home while the watch is off the wrist. Alerts pause; SOS stays on the Log page. */
@ComponentV2
struct NotWorn {
  build() {
    Stack() {
      Bezel({ mode: 'DASHED', color: Theme.BORDER })
      Column({ space: 4 }) {
        NoNumber()
        Text('Not on wrist').fontSize(Theme.TITLE + 3).fontWeight(FontWeight.Bolder).fontColor(Theme.TEXT)
          .margin({ top: 6 })
        Text('Put your watch back on to keep watching your heart.')
          .fontSize(Theme.BODY)
          .fontWeight(FontWeight.Regular)
          .fontColor(Theme.TEXT_2)
          .textAlign(TextAlign.Center)
          .width(160)
      }
    }
    .width('100%')
    .height('100%')
    .accessibilityGroup(true)
    .accessibilityText('Not on wrist. Put your watch back on to keep watching your heart.')
  }
}

/**
 * 01 Home: the gauge (where the bpm sits between your min and max), status mark + word, bpm, state + limit,
 * genotype and phone chips. A risky medicine (or demo data) gets a badge on top.
 */
@ComponentV2
export struct HeartPage {
  @Param @Require ctrl: WatchController;

  zone(): Zone {
    return zoneFor(this.ctrl.bpm, this.ctrl.limitLow, this.ctrl.limitHigh, this.ctrl.stress);
  }

  waiting(): boolean {
    return this.ctrl.bpm <= 0;
  }

  context(): string {
    return contextLine(this.ctrl.activity, this.zone(), this.ctrl.limitLow, this.ctrl.limitHigh);
  }

  phoneText(): string {
    switch (this.ctrl.syncState) {
      case 'OK':
        return 'Phone';
      case 'PENDING':
        return 'Syncing...';
      default:
        return 'Offline';
    }
  }

  badge(): string {
    return drugBadgeText(this.ctrl.riskyDrug, this.ctrl.riskyDrugAt, Date.now());
  }

  /** The badge uses the verdict colour of the medicine (DESIGN.md §3), on its dark tint. */
  badgeColor(): string {
    switch (this.ctrl.riskyDrugRisk) {
      case 'POSSIBLE_RISK':
        return Theme.RISK_POSSIBLE;
      case 'CONDITIONAL_RISK':
        return Theme.RISK_CONDITIONAL;
      default:
        return Theme.RISK_KNOWN;
    }
  }

  badgeTint(): string {
    return this.ctrl.riskyDrugRisk === 'KNOWN_RISK' || this.ctrl.riskyDrugRisk === '' ? Theme.ALERT_TINT :
      Theme.ELEVATED_TINT;
  }

  badgeShape(): Resource {
    switch (this.ctrl.riskyDrugRisk) {
      case 'POSSIBLE_RISK':
        return $r('app.media.ic_risk_possible');
      case 'CONDITIONAL_RISK':
        return $r('app.media.ic_risk_conditional');
      default:
        return $r('app.media.ic_risk_known');
    }
  }

  isDemo(): boolean {
    return this.ctrl.sourceKind === 'SIMULATED';
  }

  /** One sentence for the screen reader instead of eight fragments. */
  spoken(): string {
    if (this.waiting()) {
      return `Waiting for heart rate. ${this.context()}.`;
    }
    const demo = this.isDemo() ? ' Demo data.' : '';
    return `Heart rate ${this.ctrl.bpm} beats per minute. ${zoneWord(this.zone())}. ${this.context()}.${demo}`;
  }

  @Builder
  topBadge() {
    if (this.badge().length > 0) {
      Row({ space: 5 }) {
        Image(this.badgeShape()).width(11).height(11).fillColor(this.badgeColor())
        Text(this.badge())
          .fontSize(Theme.SMALL - 1)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)
          .maxLines(1)
      }
      .height(Theme.CHIP_HEIGHT)
      .padding({ left: 8, right: 10 })
      .borderRadius(Theme.CHIP_HEIGHT / 2)
      .backgroundColor(this.badgeTint())
      .margin({ bottom: 4 })
    } else if (this.isDemo()) {
      OutlineBadge({ label: 'DEMO DATA', color: Theme.TEXT }).margin({ bottom: 6 })
    }
  }

  build() {
    if (!this.ctrl.onWrist) {
      NotWorn()
    } else {
      Stack() {
        if (this.waiting()) {
          Bezel({ mode: 'DASHED', color: Theme.BORDER })
        } else {
          Bezel({ mode: 'GAUGE', color: zoneColor(this.zone()), dot: this.zone() === 'BELOW',
            fraction: ringRatio(this.ctrl.bpm, this.ctrl.limitLow, this.ctrl.limitHigh) })
        }
        Column({ space: 0 }) {
          this.topBadge()

          Row({ space: 5 }) {
            StatusMark({ mark: zoneMark(this.zone()), color: zoneColor(this.zone()), dim: 12 })
            Text(zoneWord(this.zone()))
              .fontSize(Theme.TITLE - 1)
              .fontWeight(FontWeight.Bold)
              .fontColor(zoneColor(this.zone()))
              .maxLines(1)
          }

          if (this.waiting()) {
            NoNumber().margin({ top: 10, bottom: 6 })
            Text('Waiting for heart rate').fontSize(Theme.BODY).fontWeight(FontWeight.Regular)
              .fontColor(Theme.TEXT_2)
          } else {
            Text(`${this.ctrl.bpm}`)
              .fontSize(Theme.HERO)
              .fontWeight(FontWeight.Bolder)
              .fontColor(Theme.TEXT)
              .margin({ top: -4, bottom: -8 })
            Text('bpm').fontSize(Theme.BODY).fontWeight(FontWeight.Regular).fontColor(Theme.TEXT_2)
          }

          Text(this.context())
            .fontSize(Theme.BODY - 1)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.TEXT)
            .margin({ top: 6 })

          Row({ space: 4 }) {
            Chip({ label: this.ctrl.genotype === 'UNKNOWN' ? 'No genotype' : this.ctrl.genotype,
              color: this.ctrl.genotype === 'UNKNOWN' ? Theme.TEXT_2 : Theme.TEXT })
            Chip({ label: this.phoneText(), check: this.ctrl.syncState === 'OK',
              color: this.ctrl.syncState === 'OK' ? Theme.TEXT : Theme.TEXT_2 })
          }
          .margin({ top: 6 })
        }
        .alignItems(HorizontalAlign.Center)
        .padding({ bottom: 8 })
      }
      .width('100%')
      .height('100%')
      .accessibilityGroup(true)
      .accessibilityText(this.spoken())
    }
  }
}
