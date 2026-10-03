// The health chart (DESIGN.md §6.10): one component for every watch metric. Line, range capsules or bars over the
// usual-range band, a readout that follows the finger, dates, and the dose / symptom rows for resting heart rate.
// Built from shapes so every colour is a resource. A trend of daily numbers: never an ECG trace, never QT.

import {
  ChartForm, ChartPoint, chartPoints, dayText, formatValue, hasValue, lastIndex, lineRuns, MetricBand, MetricDay,
  MetricKind, MetricScale, metricScale, metricStats, MetricStats, nearestIndex, OPEN, slotX, smoothRun, unitText, valueY
} from '../vitals/Metrics';
import { TrendDay } from '../vitals/Trends';
import { MetricUi } from '../common/MetricUi';
import { fmtText, resText } from './Common';

const AXIS_W: number = 34;
const ROW_H: number = 22;
const MARK: number = 8;
const DOT: number = 10;
const CAPSULE: number = 6;
const CURVE_STEPS: number = 8;

const NO_BAND: MetricBand = { lo: 0, hi: OPEN, okLo: 0, okHi: OPEN, personal: false };

@Extend(Text)
function axisText() {
  .fontSize($r('app.float.font_micro'))
  .fontColor($r('app.color.ink_4'))
  .maxLines(1)
}

// The widest a bar gets, so three days of data don't become three slabs.
function barWidth(count: number, width: number): number {
  return count <= 0 ? 0 : Math.max(2, Math.min(18, width / count - 2));
}

@ComponentV2
export struct MetricChart {
  @Param kind: MetricKind = 'RESTING_HR';
  @Param days: MetricDay[] = [];
  @Param form: ChartForm = 'LINE';
  @Param band: MetricBand = NO_BAND;
  @Param plotHeight: number = 160;
  @Param live: boolean = false;        // the last minutes: `day` is a clock text and the readout follows the newest
  @Param readout: boolean = true;
  @Param marks: TrendDay[] = [];       // dose and symptom rows under the plot (resting heart rate)
  @Local plotWidth: number = 0;
  @Local picked: number = -1;          // -1 = the latest reading

  private axis(): MetricScale {
    return metricScale(this.kind, this.days, this.band);
  }

  private points(): ChartPoint[] {
    return chartPoints(this.days, this.axis(), this.plotWidth, this.plotHeight);
  }

  private sel(): number {
    return this.picked >= 0 && this.picked < this.days.length && hasValue(this.days[this.picked]) ? this.picked :
      lastIndex(this.days);
  }

  private selPoint(): ChartPoint | undefined {
    const i: number = this.sel();
    return this.points().find((p: ChartPoint) => p.index === i);
  }

  private selValue(): string {
    const i: number = this.sel();
    if (i < 0) {
      return '–';
    }
    const d: MetricDay = this.days[i];
    return this.form === 'RANGE' && d.lo >= 0 && d.hi >= 0 ?
      `${formatValue(this.kind, d.lo)}–${formatValue(this.kind, d.hi)}` : formatValue(this.kind, d.value);
  }

  private selNote(): ResourceStr {
    const i: number = this.sel();
    if (i < 0) {
      return '';
    }
    const when: string = this.live ? this.days[i].day : dayText(this.days[i].day, true);
    return this.form === 'RANGE' && this.days[i].lo >= 0 ?
      $r('app.string.metric_readout_avg', when, formatValue(this.kind, this.days[i].value)) : when;
  }

  private dateAt(i: number): string {
    return this.days.length === 0 ? '' : dayText(this.days[Math.min(this.days.length - 1, i)].day, false);
  }

  private bandTop(): number {
    return valueY(Math.min(this.band.hi, this.axis().max), this.axis(), this.plotHeight);
  }

  private bandHeight(): number {
    const bottom: number = valueY(Math.max(this.band.lo, this.axis().min), this.axis(), this.plotHeight);
    return Math.max(0, bottom - this.bandTop());
  }

  private area(run: ChartPoint[]): Array<[number, number]> {
    const pts: Array<[number, number]> = smoothRun(run, CURVE_STEPS);
    pts.push([run[run.length - 1].x, this.plotHeight]);
    pts.push([run[0].x, this.plotHeight]);
    return pts;
  }

  private runKey(run: ChartPoint[]): string {
    let sum: number = 0;
    for (const p of run) {
      sum += p.y;
    }
    return `${run[0].index}-${run.length}-${Math.round(sum * 10)}-${this.plotWidth}-${this.plotHeight}`;
  }

  private pointKey(p: ChartPoint): string {
    return `${p.index}-${Math.round(p.y * 10)}-${Math.round(p.yLo)}-${Math.round(p.yHi)}-${this.plotWidth}-` +
      `${p.index === this.sel()}`;
  }

  // The drawing says nothing to a screen reader: read how many days have a reading and their range.
  private spoken(): string {
    const stats: MetricStats = metricStats(this.days);
    const name: string = resText(this.getUIContext(), MetricUi.label(this.kind));
    if (stats.count === 0) {
      return fmtText(this.getUIContext(), $r('app.string.a11y_metric_chart_empty'), name);
    }
    return fmtText(this.getUIContext(), $r('app.string.a11y_metric_chart'), name, stats.count, this.days.length,
      formatValue(this.kind, stats.min), formatValue(this.kind, stats.max), unitText(this.kind));
  }

  @Builder
  lineMarks() {
    ForEach(lineRuns(this.points()), (run: ChartPoint[]) => {
      if (run.length > 1) {
        Polygon({ width: this.plotWidth, height: this.plotHeight })
          .points(this.area(run))
          .fill($r('app.color.brand_accent'))
          .fillOpacity(0.08)
          .strokeWidth(0)
        Polyline({ width: this.plotWidth, height: this.plotHeight })
          .points(smoothRun(run, CURVE_STEPS))
          .fillOpacity(0)
          .stroke($r('app.color.brand_accent'))
          .strokeWidth(2)
          .strokeLineJoin(LineJoinStyle.Round)
          .strokeLineCap(LineCapStyle.Round)
      } else {
        // A lone day between two gaps still has to be seen.
        Circle({ width: 6, height: 6 })
          .fill($r('app.color.brand_accent'))
          .position({ x: run[0].x - 3, y: run[0].y - 3 })
      }
    }, (run: ChartPoint[]) => this.runKey(run))
  }

  @Builder
  rangeMarks() {
    ForEach(this.points(), (p: ChartPoint) => {
      Rect({ width: CAPSULE, height: Math.max(CAPSULE, p.yLo - p.yHi) })
        .radius(CAPSULE / 2)
        .fill($r('app.color.brand_accent'))
        .fillOpacity(p.index === this.sel() ? 0.5 : 0.3)
        .position({ x: p.x - CAPSULE / 2, y: Math.min(p.yHi, p.y - CAPSULE / 2) })
      Circle({ width: CAPSULE, height: CAPSULE })
        .fill($r('app.color.brand_accent'))
        .position({ x: p.x - CAPSULE / 2, y: p.y - CAPSULE / 2 })
    }, (p: ChartPoint) => this.pointKey(p))
  }

  @Builder
  barMarks() {
    ForEach(this.points(), (p: ChartPoint) => {
      Rect({ width: barWidth(this.days.length, this.plotWidth), height: Math.max(2, this.plotHeight - p.y) })
        .radius(Math.min(4, barWidth(this.days.length, this.plotWidth) / 2))
        .fill($r('app.color.brand_accent'))
        .fillOpacity(p.index === this.sel() ? 1 : 0.35)
        .position({
          x: p.x - barWidth(this.days.length, this.plotWidth) / 2,
          y: Math.min(p.y, this.plotHeight - 2)
        })
    }, (p: ChartPoint) => this.pointKey(p))
  }

  @Builder
  markRow(label: ResourceStr, symptoms: boolean) {
    Row() {
      Blank().width(AXIS_W)
      Stack({ alignContent: Alignment.TopStart }) {
        ForEach(this.marks, (d: TrendDay, i: number) => {
          if (symptoms) {
            if (d.symptoms > 0) {
              Circle({ width: MARK, height: MARK })
                .fill($r('app.color.ink'))
                .position({ x: slotX(i, this.marks.length, this.plotWidth) - MARK / 2, y: (ROW_H - MARK) / 2 })
            }
          } else {
            Rect({ width: MARK, height: MARK })
              .radius(2)
              .fill(d.doses > 0 ? $r('app.color.ink_2') : $r('app.color.surface'))
              .stroke(d.doses > 0 ? $r('app.color.ink_2') : $r('app.color.border_strong'))
              .strokeWidth(1)
              .position({ x: slotX(i, this.marks.length, this.plotWidth) - MARK / 2, y: (ROW_H - MARK) / 2 })
          }
        }, (d: TrendDay) => `${symptoms ? 's' : 'd'}-${d.day}-${d.doses}-${d.symptoms}-${this.plotWidth}`)
      }
      .layoutWeight(1)
      .height(ROW_H)
    }
    .width('100%')
    Text(label).axisText().fontColor($r('app.color.ink_3')).margin({ left: AXIS_W })
  }

  build() {
    Column() {
      if (this.readout) {
        Row({ space: 4 }) {
          Text(this.selValue())
            .fontSize($r('app.float.font_headline'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          Text(unitText(this.kind))
            .fontSize($r('app.float.font_small'))
            .fontColor($r('app.color.ink_3'))
          Blank()
          Text(this.selNote())
            .fontSize($r('app.float.font_small'))
            .fontColor($r('app.color.ink_3'))
            .maxLines(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)
        .margin({ bottom: 12 })
      }

      Row() {
        Stack({ alignContent: Alignment.TopStart }) {
          ForEach(this.axis().ticks, (t: number) => {
            Text(formatValue(this.kind, t))
              .axisText()
              .position({ x: 0, y: valueY(t, this.axis(), this.plotHeight) - 7 })
          }, (t: number) => `${t}-${this.axis().min}-${this.axis().max}-${this.plotHeight}`)
        }
        .width(AXIS_W)
        .height(this.plotHeight)

        Stack({ alignContent: Alignment.TopStart }) {
          if (this.plotWidth > 0) {
            if (this.bandHeight() > 0 && (this.band.lo > 0 || this.band.hi < OPEN)) {
              Rect({ width: this.plotWidth, height: this.bandHeight() })
                .radius(4)
                .fill($r('app.color.surface_alt'))
                .position({ x: 0, y: this.bandTop() })
            }
            ForEach(this.axis().ticks, (t: number) => {
              Line()
                .startPoint([0, valueY(t, this.axis(), this.plotHeight)])
                .endPoint([this.plotWidth, valueY(t, this.axis(), this.plotHeight)])
                .stroke($r('app.color.border'))
                .strokeWidth(1)
            }, (t: number) => `${t}-${this.axis().min}-${this.axis().max}-${this.plotWidth}-${this.plotHeight}`)

            if (this.selPoint() !== undefined && this.readout) {
              Line()
                .startPoint([this.selPoint()?.x ?? 0, 0])
                .endPoint([this.selPoint()?.x ?? 0, this.plotHeight])
                .stroke($r('app.color.border_strong'))
                .strokeWidth(1)
            }

            if (this.form === 'RANGE') {
              this.rangeMarks()
            } else if (this.form === 'BARS') {
              this.barMarks()
            } else {
              this.lineMarks()
            }

            if (this.selPoint() !== undefined && this.form === 'LINE') {
              Circle({ width: DOT, height: DOT })
                .fill($r('app.color.brand_accent'))
                .stroke($r('app.color.surface'))
                .strokeWidth(2)
                .position({ x: (this.selPoint()?.x ?? 0) - DOT / 2, y: (this.selPoint()?.y ?? 0) - DOT / 2 })
            }
          }
        }
        .layoutWeight(1)
        .height(this.plotHeight)
        .onSizeChange((oldValue: SizeOptions, newValue: SizeOptions) => {
          this.plotWidth = newValue.width as number;
        })
        .onTouch((e: TouchEvent) => {
          if (!this.readout || e.touches.length === 0) {
            return;
          }
          if (this.live && (e.type === TouchType.Up || e.type === TouchType.Cancel)) {
            this.picked = -1;   // the live line goes back to following the newest reading
            return;
          }
          this.picked = nearestIndex(this.days, e.touches[0].x, this.plotWidth);
        })
      }
      .width('100%')

      if (this.days.length > 0 && !this.live) {
        Row() {
          Text(this.dateAt(0)).axisText().fontColor($r('app.color.ink_3'))
          Blank()
          Text(this.dateAt(Math.floor(this.days.length / 2))).axisText().fontColor($r('app.color.ink_3'))
          Blank()
          Text(this.dateAt(this.days.length - 1)).axisText().fontColor($r('app.color.ink_3'))
        }
        .width('100%')
        .padding({ left: AXIS_W, top: 8 })
      }

      if (this.marks.length > 0) {
        Blank().height(8)
        this.markRow($r('app.string.trends_row_dose'), false)
        this.markRow($r('app.string.trends_row_symptom'), true)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .accessibilityGroup(true)
    .accessibilityText(this.spoken())
  }
}

// The small chart on a metric card: the same form, no axes, the last mark emphasised.
@ComponentV2
export struct MiniChart {
  @Param kind: MetricKind = 'RESTING_HR';
  @Param days: MetricDay[] = [];
  @Param form: ChartForm = 'LINE';
  @Param band: MetricBand = NO_BAND;
  @Param chartHeight: number = 36;
  @Local plotWidth: number = 0;

  // 3 vp of air so the last dot and the line's round caps are not cut.
  private points(): ChartPoint[] {
    const pts: ChartPoint[] = chartPoints(this.days, metricScale(this.kind, this.days, this.band), this.plotWidth,
      this.chartHeight - 6);
    for (const p of pts) {
      p.y += 3;
      p.yLo += 3;
      p.yHi += 3;
    }
    return pts;
  }

  private last(): ChartPoint | undefined {
    const pts: ChartPoint[] = this.points();
    return pts.length > 0 ? pts[pts.length - 1] : undefined;
  }

  private markKey(p: ChartPoint, n: number): string {
    return `${p.index}-${Math.round(p.y * 10)}-${Math.round(p.yLo)}-${this.plotWidth}-${n}`;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.plotWidth > 0) {
        if (this.form === 'LINE') {
          ForEach(lineRuns(this.points()), (run: ChartPoint[]) => {
            Polyline({ width: this.plotWidth, height: this.chartHeight })
              .points(smoothRun(run, 6))
              .fillOpacity(0)
              .stroke($r('app.color.brand_accent'))
              .strokeWidth(2)
              .strokeLineJoin(LineJoinStyle.Round)
              .strokeLineCap(LineCapStyle.Round)
          }, (run: ChartPoint[]) => this.markKey(run[run.length - 1], run.length) + `-${Math.round(run[0].y * 10)}`)
          if (this.last() !== undefined) {
            Circle({ width: 8, height: 8 })
              .fill($r('app.color.brand_accent'))
              .stroke($r('app.color.surface'))
              .strokeWidth(2)
              .position({ x: (this.last()?.x ?? 0) - 4, y: (this.last()?.y ?? 0) - 4 })
          }
        } else {
          ForEach(this.points(), (p: ChartPoint) => {
            if (this.form === 'RANGE') {
              Rect({ width: 4, height: Math.max(4, p.yLo - p.yHi) })
                .radius(2)
                .fill($r('app.color.brand_accent'))
                .fillOpacity(p.index === this.last()?.index ? 1 : 0.35)
                .position({ x: p.x - 2, y: Math.min(p.yHi, p.y - 2) })
            } else {
              Rect({
                width: barWidth(this.days.length, this.plotWidth),
                height: Math.max(2, this.chartHeight - p.y)
              })
                .radius(Math.min(3, barWidth(this.days.length, this.plotWidth) / 2))
                .fill($r('app.color.brand_accent'))
                .fillOpacity(p.index === this.last()?.index ? 1 : 0.35)
                .position({ x: p.x - barWidth(this.days.length, this.plotWidth) / 2, y: p.y })
            }
          }, (p: ChartPoint) => this.markKey(p, this.last()?.index ?? -1))
        }
      }
    }
    .width('100%')
    .height(this.chartHeight)
    .onSizeChange((oldValue: SizeOptions, newValue: SizeOptions) => {
      this.plotWidth = newValue.width as number;
    })
    .accessibilityLevel('no')
  }
}
