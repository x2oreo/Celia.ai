import { WatchController } from '../controller/WatchController';
import { HrBucket, TREND_BUCKETS, TREND_BUCKET_MS, TrendScale, trendScale, trendY } from '../vitals/HrTrend';
import { slotsOverMax } from '../vitals/WatchStatus';
import { Caps, OutlineBadge, StatusMark } from './Parts';
import { Theme } from './Theme';

const PLOT_W: number = 150;
const PLOT_H: number = 70;
const LABEL_W: number = 22;
const MARK_W: number = 4;
const TICK_W: number = 7;

/**
 * 02 Heart rate · 10 min: average, range and one capsule per 30 s from the lowest to the highest reading (grey, red
 * where it crossed your max) with a white average tick. Dashed lines = your current min and max. Never a trace.
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
    const step = (PLOT_W - TICK_W) / (TREND_BUCKETS - 1);
    return i * step + (TICK_W - MARK_W) / 2;
  }

  minutes(): number {
    return Math.round(TREND_BUCKETS * TREND_BUCKET_MS / 60000);
  }

  overMax(): number {
    return slotsOverMax(this.ctrl.trendSlots, this.ctrl.limitHigh);
  }

  spoken(): string {
    const s = this.ctrl.trendSummary;
    if (s.filled === 0) {
      return 'Heart rate, last 10 minutes. Collecting readings.';
    }
    const over = this.overMax() > 0 ? ` ${this.overMax()} times over your max.` : '';
    return `Heart rate over the last ${this.minutes()} minutes: average ${s.avg}, range ${s.min} to ${s.max}.` +
      `${over} Your limits are ${this.ctrl.limitLow} to ${this.ctrl.limitHigh}.`;
  }

  @Builder
  limitLine(bpm: number) {
    Line()
      .startPoint([0, 0])
      .endPoint([PLOT_W, 0])
      .stroke(Theme.TEXT_3)
      .strokeWidth(1)
      .strokeDashArray([3, 3])
      .width(PLOT_W)
      .height(1)
      .position({ x: 0, y: this.y(bpm) })
    Text(`${bpm}`)
      .fontSize(Theme.SMALL - 1)
      .fontWeight(FontWeight.Medium)
      .fontColor(Theme.TEXT_2)
      .position({ x: PLOT_W + 5, y: this.y(bpm) - 8 })
  }

  @Builder
  plot() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.limitLine(this.ctrl.limitHigh)
      this.limitLine(this.ctrl.limitLow)

      ForEach(this.ctrl.trendSlots, (b: HrBucket, i: number) => {
        if (b.count > 0) {
          Rect()
            .width(MARK_W)
            .height(Math.max(MARK_W + 2, this.y(b.min) - this.y(b.max)))
            .radius(MARK_W / 2)
            .fill(b.max > this.ctrl.limitHigh ? Theme.ALERT : Theme.CHART_BAR)
            .position({ x: this.x(i), y: Math.min(this.y(b.max), this.y(b.min) - MARK_W - 2) })
          Rect()
            .width(TICK_W)
            .height(2)
            .radius(1)
            .fill(Theme.TEXT)
            .position({ x: this.x(i) - (TICK_W - MARK_W) / 2, y: this.y(b.avg()) - 1 })
        }
      }, (b: HrBucket, i: number) => `${b.startMs}-${b.count}-${i}`)
    }
    .width(PLOT_W + LABEL_W)
    .height(PLOT_H)
  }

  build() {
    Column({ space: 0 }) {
      Caps({ text: `LAST ${this.minutes()} MIN` })

      if (this.ctrl.trendSummary.filled === 0) {
        Stack() {
          Text('Collecting readings...').fontSize(Theme.BODY).fontWeight(FontWeight.Regular).fontColor(Theme.TEXT_2)
        }
        .width(146)
        .height(72)
        .borderRadius(10)
        .border({ width: 1, color: Theme.BORDER, style: BorderStyle.Dashed })
        .margin({ top: 14, bottom: 14 })
        Text('Your chart fills in as readings arrive.')
          .fontSize(Theme.BODY - 1)
          .fontColor(Theme.TEXT)
          .textAlign(TextAlign.Center)
          .width(150)
      } else {
        Row({ space: 5 }) {
          Text(`${this.ctrl.trendSummary.avg}`)
            .fontSize(Theme.NUMBER)
            .fontWeight(FontWeight.Bolder)
            .fontColor(Theme.TEXT)
          Text('avg bpm').fontSize(Theme.BODY).fontColor(Theme.TEXT_2).margin({ bottom: 6 })
        }
        .alignItems(VerticalAlign.Bottom)
        .margin({ top: -2 })

        Row({ space: 4 }) {
          Text(`Range ${this.ctrl.trendSummary.min}-${this.ctrl.trendSummary.max}`)
            .fontSize(Theme.SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.TEXT)
          if (this.overMax() > 0) {
            Text('·').fontSize(Theme.SMALL).fontColor(Theme.TEXT_2)
            StatusMark({ mark: 'UP', color: Theme.ALERT, dim: 9 })
            Text(`${this.overMax()} over max`).fontSize(Theme.SMALL).fontWeight(FontWeight.Bold).fontColor(Theme.ALERT)
          }
        }
        .margin({ bottom: 10 })

        this.plot()

        Row() {
          Text(`${this.minutes()} min ago`).fontSize(Theme.SMALL - 1).fontColor(Theme.TEXT_2)
          Blank()
          Text('now').fontSize(Theme.SMALL - 1).fontColor(Theme.TEXT_2)
        }
        .width(PLOT_W)
        .margin({ top: 4, right: LABEL_W })
      }

      if (this.ctrl.trendSummary.filled > 0 && this.ctrl.restingBpm > 0) {
        Row({ space: 4 }) {
          Text(`Resting ${this.ctrl.restingBpm} bpm`).fontSize(Theme.SMALL).fontColor(Theme.TEXT)
          if (!this.ctrl.restingMeasured) {
            OutlineBadge({ label: 'EST', color: Theme.TEXT_2 })
          }
        }
        .margin({ top: 6 })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ bottom: 6 })
    .accessibilityGroup(true)
    .accessibilityText(this.spoken())
  }
}
