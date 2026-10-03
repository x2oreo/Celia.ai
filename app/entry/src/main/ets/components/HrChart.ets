// Heart-rate sparkline drawn with a Polyline. Fixed 40–190 bpm scale so spikes look like spikes.

const MIN_BPM: number = 40;
const MAX_BPM: number = 190;

export function chartPoints(hrs: number[], width: number, height: number, capacity: number): Array<[number, number]> {
  const pts: Array<[number, number]> = [];
  if (hrs.length === 0 || capacity < 2) {
    return pts;
  }
  const step: number = width / (capacity - 1);
  const offset: number = capacity - hrs.length;
  for (let i = 0; i < hrs.length; i++) {
    const clamped: number = Math.max(MIN_BPM, Math.min(MAX_BPM, hrs[i]));
    const y: number = height - ((clamped - MIN_BPM) / (MAX_BPM - MIN_BPM)) * height;
    pts.push([(offset + i) * step, y]);
  }
  return pts;
}

@ComponentV2
export struct HrChart {
  @Param hrs: number[] = [];
  @Param capacity: number = 90;
  @Param chartWidth: number = 320;
  @Param chartHeight: number = 120;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // Reference lines at 60 and 120 bpm
      Line()
        .startPoint([0, this.yFor(120)])
        .endPoint([this.chartWidth, this.yFor(120)])
        .stroke($r('app.color.border_strong'))
        .strokeDashArray([4, 4])
      Line()
        .startPoint([0, this.yFor(60)])
        .endPoint([this.chartWidth, this.yFor(60)])
        .stroke($r('app.color.border_strong'))
        .strokeDashArray([4, 4])
      Polyline({ width: this.chartWidth, height: this.chartHeight })
        .points(chartPoints(this.hrs, this.chartWidth, this.chartHeight, this.capacity))
        .fillOpacity(0)
        .stroke($r('app.color.brand_accent'))
        .strokeWidth(2.5)
        .strokeLineJoin(LineJoinStyle.Round)
        .strokeLineCap(LineCapStyle.Round)
    }
    .width(this.chartWidth)
    .height(this.chartHeight)
  }

  private yFor(bpm: number): number {
    return this.chartHeight - ((bpm - MIN_BPM) / (MAX_BPM - MIN_BPM)) * this.chartHeight;
  }
}
