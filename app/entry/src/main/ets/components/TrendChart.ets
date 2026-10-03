// Resting heart rate per day as a trend line, with two aligned rows under it: dose logged and symptom reported.
// A daily trend, never an ECG-style trace (DESIGN.md §10.2). Marks are ink, not risk colours.

import { dayX, TrendDay, TrendPoint, trendPoints, TrendScale, trendScale } from '../vitals/Trends';

const LINE_H: number = 140;
const ROW_H: number = 22;
const AXIS_W: number = 30;
const DOT: number = 6;
const MARK: number = 8;

@ComponentV2
export struct TrendChart {
  @Param days: TrendDay[] = [];
  @Param doseLabel: ResourceStr = '';
  @Param symptomLabel: ResourceStr = '';
  @Local plotWidth: number = 0;

  private range(): TrendScale {
    return trendScale(this.days);
  }

  private points(): TrendPoint[] {
    return trendPoints(this.days, this.plotWidth, LINE_H);
  }

  private line(): Array<[number, number]> {
    return this.points().map((p: TrendPoint): [number, number] => [p.x, p.y]);
  }

  private x(i: number): number {
    return dayX(i, this.days.length, this.plotWidth);
  }

  private label(i: number): string {
    const d: string = this.days[i].day;   // YYYY-MM-DD → DD.MM
    return `${d.substring(8, 10)}.${d.substring(5, 7)}`;
  }

  @Builder
  guide(y: number) {
    Line()
      .startPoint([0, y])
      .endPoint([this.plotWidth, y])
      .stroke($r('app.color.border_strong'))
      .strokeDashArray([4, 4])
  }

  @Builder
  axisLabel(text: string) {
    Text(text)
      .fontSize($r('app.float.font_micro'))
      .fontColor($r('app.color.ink_3'))
  }

  @Builder
  markRow(label: ResourceStr, symptoms: boolean) {
    Row() {
      Blank().width(AXIS_W)
      Stack({ alignContent: Alignment.TopStart }) {
        ForEach(this.days, (d: TrendDay, i: number) => {
          if (symptoms) {
            if (d.symptoms > 0) {
              Circle({ width: MARK, height: MARK })
                .fill($r('app.color.ink'))
                .position({ x: this.x(i) - MARK / 2, y: (ROW_H - MARK) / 2 })
            }
          } else {
            Rect({ width: MARK, height: MARK })
              .radius(2)
              .fill(d.doses > 0 ? $r('app.color.ink_2') : $r('app.color.surface'))
              .stroke(d.doses > 0 ? $r('app.color.ink_2') : $r('app.color.border_strong'))
              .strokeWidth(1)
              .position({ x: this.x(i) - MARK / 2, y: (ROW_H - MARK) / 2 })
          }
        }, (d: TrendDay) => `${symptoms ? 's' : 'd'}-${d.day}-${d.doses}-${d.symptoms}`)
      }
      .layoutWeight(1)
      .height(ROW_H)
    }
    .width('100%')
    Text(label)
      .fontSize($r('app.float.font_micro'))
      .fontColor($r('app.color.ink_3'))
      .margin({ left: AXIS_W })
  }

  build() {
    Column() {
      Row() {
        Column() {
          this.axisLabel(`${this.range().max}`)
          Blank()
          this.axisLabel(`${this.range().min}`)
        }
        .width(AXIS_W)
        .height(LINE_H)
        .alignItems(HorizontalAlign.Start)

        Stack({ alignContent: Alignment.TopStart }) {
          this.guide(0.5)
          this.guide(LINE_H / 2)
          this.guide(LINE_H - 0.5)
          if (this.plotWidth > 0) {
            Polyline({ width: this.plotWidth, height: LINE_H })
              .points(this.line())
              .fillOpacity(0)
              .stroke($r('app.color.brand_accent'))
              .strokeWidth(2.5)
              .strokeLineJoin(LineJoinStyle.Round)
              .strokeLineCap(LineCapStyle.Round)
            ForEach(this.points(), (p: TrendPoint) => {
              Circle({ width: DOT, height: DOT })
                .fill($r('app.color.brand_accent'))
                .position({ x: p.x - DOT / 2, y: p.y - DOT / 2 })
            }, (p: TrendPoint) => `${p.index}-${Math.round(p.y)}-${this.plotWidth}`)
          }
        }
        .layoutWeight(1)
        .height(LINE_H)
        .onSizeChange((oldValue: SizeOptions, newValue: SizeOptions) => {
          this.plotWidth = newValue.width as number;
        })
      }
      .width('100%')

      if (this.days.length > 0) {
        Row() {
          this.axisLabel(this.label(0))
          Blank()
          this.axisLabel(this.label(this.days.length - 1))
        }
        .width('100%')
        .padding({ left: AXIS_W, top: 4, bottom: 8 })

        this.markRow(this.doseLabel, false)
        this.markRow(this.symptomLabel, true)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
