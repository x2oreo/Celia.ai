import { WatchController } from '../controller/WatchController';
import { HrBucket, TREND_BUCKETS, TREND_BUCKET_MS, TrendScale, trendScale, trendY } from '../vitals/HrTrend';
import { Caps, Icon } from './Parts';
import { Theme } from './Theme';

const PLOT_W: number = 172;
const PLOT_H: number = 72;
const MARK_W: number = 5;

/**
 * Heart rate over the last minutes (DESIGN.md §7 page 2): one range capsule per 30 s (lowest to highest reading,
 * average dot), your min-max limits as a band, the max as a dashed line. Never a trace.
 */
@ComponentV2
export struct TrendPage {
  @Param @Require ctrl: WatchController;

  plotScale(): TrendScale {
    return trendScale(this.ctrl.trendSlots, this.ctrl.limitLow, this.ctrl.limitHigh);
  }

  y(bpm: number): number {
    return (1 - trendY(bpm, this.plotScale())) * PLOT_H;
  }

  x(i: number): number {
    const step = (PLOT_W - MARK_W) / (TREND_BUCKETS - 1);
    return i * step;
  }

  windowLabel(): string {
    return `${Math.round(TREND_BUCKETS * TREND_BUCKET_MS / 60000)} MIN`;
  }

  spoken(): string {
    const s = this.ctrl.trendSummary;
    if (s.filled === 0) {
      return 'Heart rate trend. Collecting readings.';
    }
    return `Heart rate over the last ${Math.round(TREND_BUCKETS * TREND_BUCKET_MS / 60000)} minutes: average ` +
      `${s.avg}, lowest ${s.min}, highest ${s.max}. Your limits are ${this.ctrl.limitLow} to ${this.ctrl.limitHigh}.`;
  }

  @Builder
  plot() {
    Stack({ alignContent: Alignment.TopStart }) {
      // Your limits: the band you should stay in.
      Rect()
        .width(PLOT_W)
        .height(Math.max(2, this.y(this.ctrl.limitLow) - this.y(this.ctrl.limitHigh)))
        .radius(4)
        .fill(Theme.RING_TRACK)
        .position({ x: 0, y: this.y(this.ctrl.limitHigh) })
      Line()
        .startPoint([0, 0])
        .endPoint([PLOT_W, 0])
        .stroke(Theme.ELEVATED)
        .strokeOpacity(0.6)
        .strokeWidth(1)
        .strokeDashArray([3, 3])
        .width(PLOT_W)
        .height(1)
        .position({ x: 0, y: this.y(this.ctrl.limitHigh) })

      ForEach(this.ctrl.trendSlots, (b: HrBucket, i: number) => {
        if (b.count > 0) {
          Rect()
            .width(MARK_W)
            .height(Math.max(MARK_W, this.y(b.min) - this.y(b.max)))
            .radius(MARK_W / 2)
            .fill(i === TREND_BUCKETS - 1 ? Theme.BRAND : Theme.BRAND_SOFT)
            .position({ x: this.x(i), y: Math.min(this.y(b.max), this.y(b.min) - MARK_W) })
          Circle()
            .width(MARK_W)
            .height(MARK_W)
            .fill(b.max > this.ctrl.limitHigh ? Theme.ALERT : Theme.BRAND)
            .position({ x: this.x(i), y: this.y(b.avg()) - MARK_W / 2 })
        }
      }, (b: HrBucket, i: number) => `${b.startMs}-${b.count}-${i}`)

      Text(`${this.ctrl.limitHigh}`)
        .fontSize(8)
        .fontColor(Theme.ELEVATED)
        .position({ x: PLOT_W + 3, y: this.y(this.ctrl.limitHigh) - 6 })
      Text(`${this.ctrl.limitLow}`)
        .fontSize(8)
        .fontColor(Theme.TEXT_3)
        .position({ x: PLOT_W + 3, y: this.y(this.ctrl.limitLow) - 6 })
    }
    .width(PLOT_W)
    .height(PLOT_H)
  }

  build() {
    Column({ space: 0 }) {
      Row({ space: 4 }) {
        Icon({ src: $r('app.media.ic_heart_fill'), color: Theme.BRAND, glyph: 11 })
        Caps({ text: `HEART · ${this.windowLabel()}` })
      }

      if (this.ctrl.trendSummary.filled === 0) {
        Column({ space: 6 }) {
          Text('--').fontSize(Theme.NUMBER).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT_3)
          Text('Collecting your heart rate. The chart fills as readings come in.')
            .fontSize(Theme.SMALL)
            .fontColor(Theme.TEXT_2)
            .textAlign(TextAlign.Center)
            .width(160)
        }
        .height(PLOT_H + 60)
        .justifyContent(FlexAlign.Center)
      } else {
        Row({ space: 4 }) {
          Text(`${this.ctrl.trendSummary.avg}`)
            .fontSize(Theme.NUMBER + 6)
            .fontWeight(FontWeight.Bolder)
            .fontColor(Theme.TEXT)
          Text('avg').fontSize(Theme.SMALL).fontColor(Theme.TEXT_2).margin({ bottom: 5 })
          Text(`${this.ctrl.trendSummary.min}-${this.ctrl.trendSummary.max}`)
            .fontSize(Theme.BODY)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
            .margin({ left: 8, bottom: 3 })
          Text('range').fontSize(Theme.SMALL).fontColor(Theme.TEXT_2).margin({ bottom: 5 })
        }
        .alignItems(VerticalAlign.Bottom)
        .margin({ top: 2, bottom: 8 })

        this.plot()

        Row() {
          Text(`${this.windowLabel().toLowerCase()} ago`).fontSize(Theme.MICRO).fontColor(Theme.TEXT_3)
          Blank()
          Text('now').fontSize(Theme.MICRO).fontColor(Theme.TEXT_3)
        }
        .width(PLOT_W)
        .margin({ top: 4 })
      }

      Row({ space: 4 }) {
        Text('Resting').fontSize(Theme.SMALL).fontColor(Theme.TEXT_2)
        Text(`${this.ctrl.restingBpm}`).fontSize(Theme.SMALL).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
        Text(this.ctrl.restingMeasured ? 'bpm' : 'bpm est').fontSize(Theme.SMALL).fontColor(Theme.TEXT_2)
      }
      .margin({ top: 10 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ right: 8 })
    .accessibilityGroup(true)
    .accessibilityText(this.spoken())
  }
}
