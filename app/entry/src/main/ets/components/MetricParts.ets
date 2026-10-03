// Pieces of the Health tab (DESIGN.md §6.10): the status pill (word + shape + tint, never red), the change chip and
// the metric card with its mini chart. Levels come from fixed rules in vitals/Metrics.ets, never from model output.

import {
  chartForm, Direction, formatValue, MetricBand, metricBand, MetricDay, MetricKind, MetricStatus, StatusLevel, unitText
} from '../vitals/Metrics';
import { MetricUi } from '../common/MetricUi';
import { fmtText, resText, RiskShape, SourceBadge } from './Common';
import { MiniChart } from './MetricChart';

// The shape of a level: check circle, ring with a bar, triangle, dashed ring.
@ComponentV2
struct StatusShape {
  @Param level: StatusLevel = 'NONE';
  @Param dim: number = 16;

  build() {
    if (this.level === 'GOOD') {
      RiskShape({ risk: 'NOT_LISTED', dim: this.dim })
    } else if (this.level === 'ATTENTION') {
      RiskShape({ risk: 'POSSIBLE_RISK', dim: this.dim })
    } else {
      Stack() {
        Circle()
          .width(this.dim - 2)
          .height(this.dim - 2)
          .fillOpacity(0)
          .stroke(MetricUi.text(this.level))
          .strokeWidth(1.5)
          .strokeDashArray(this.level === 'NONE' ? [2, 2] : [])
        if (this.level === 'OKAY') {
          Row()
            .width(this.dim * 0.4)
            .height(2)
            .borderRadius(1)
            .backgroundColor(MetricUi.text(this.level))
        }
      }
      .width(this.dim)
      .height(this.dim)
    }
  }
}

@ComponentV2
export struct StatusPill {
  @Param level: StatusLevel = 'NONE';
  @Param compact: boolean = false;

  build() {
    Row({ space: 6 }) {
      StatusShape({ level: this.level, dim: 16 })
        .accessibilityLevel('no-hide-descendants')
      Text(MetricUi.level(this.level))
        .fontSize(this.compact ? $r('app.float.font_caption') : $r('app.float.font_badge'))
        .fontWeight(FontWeight.Bold)
        .fontColor(MetricUi.text(this.level))
        .maxLines(1)
    }
    .height(this.compact ? 24 : 28)
    .padding({ left: 5, right: 10 })
    .borderRadius(14)
    .backgroundColor(MetricUi.tint(this.level))
  }
}

// "↑ 3": the last 7 days against the days before. Ink, because a direction is not a verdict.
@ComponentV2
export struct ChangeChip {
  @Param kind: MetricKind = 'RESTING_HR';
  @Param trend: Direction = 'NONE';
  @Param delta: number = 0;
  @Param unit: boolean = false;

  build() {
    if (this.trend !== 'NONE') {
      Text(this.trend === 'STEADY' ? MetricUi.arrow(this.trend) :
        `${MetricUi.arrow(this.trend)} ${formatValue(this.kind, this.delta)}${this.unit ? ' ' + unitText(this.kind) : ''}`)
        .fontSize($r('app.float.font_badge'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink_2'))
        .maxLines(1)
    }
  }
}

// One metric on the Health tab: name, value, mini chart, status. The whole card opens the metric's page.
@ComponentV2
export struct MetricCard {
  @Param kind: MetricKind = 'RESTING_HR';
  @Param days: MetricDay[] = [];
  @Param status: MetricStatus | undefined = undefined;
  @Param simulated: boolean = false;
  @Param wide: boolean = false;
  @Event onTap: () => void = () => {
  };

  private level(): StatusLevel {
    return this.status !== undefined ? this.status.level : 'NONE';
  }

  private band(): MetricBand {
    return this.status !== undefined ? this.status.band : metricBand(this.kind, this.days);
  }

  private spoken(): string {
    const ui: UIContext = this.getUIContext();
    return fmtText(ui, $r('app.string.a11y_metric_card'), resText(ui, MetricUi.label(this.kind)),
      formatValue(this.kind, this.status !== undefined ? this.status.value : -1), unitText(this.kind),
      resText(ui, MetricUi.level(this.level())));
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Text(MetricUi.short(this.kind))
          .fontSize($r('app.float.font_caption'))
          .fontWeight(FontWeight.Bold)
          .letterSpacing(0.7)
          .fontColor($r('app.color.ink_3'))
          .textCase(TextCase.UpperCase)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (this.simulated) {
          SourceBadge({ label: $r('app.string.badge_sim') })
        }
      }
      .width('100%')

      Row({ space: 4 }) {
        Text(formatValue(this.kind, this.status !== undefined ? this.status.value : -1))
          .fontSize($r('app.float.font_title'))
          .fontWeight(800)
          .fontColor($r('app.color.ink'))
        Text(unitText(this.kind))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.ink_3'))
          .margin({ bottom: 4 })
        Blank()
        ChangeChip({
          kind: this.kind,
          trend: this.status !== undefined ? this.status.direction : 'NONE',
          delta: this.status !== undefined ? this.status.delta : 0
        })
          .margin({ bottom: 4 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      MiniChart({
        kind: this.kind,
        days: this.days,
        form: chartForm(this.kind),
        band: this.band(),
        chartHeight: this.wide ? 48 : 36
      })

      StatusPill({ level: this.level(), compact: true })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_ml'))
    .clickEffect({ level: ClickEffectLevel.LIGHT })
    .accessibilityGroup(true)
    .accessibilityText(this.spoken())
    .onClick(() => {
      this.onTap();
    })
  }
}

// Segmented control (DESIGN.md §10.1a 04): surface-alt track, the selected segment on surface. 0 = now.
@ComponentV2
export struct SpanSegments {
  @Param spans: number[] = [14, 30];
  @Param span: number = 14;
  @Event onPick: (n: number) => void = (n: number) => {
  };

  build() {
    Row() {
      ForEach(this.spans, (n: number) => {
        Text(n === 0 ? $r('app.string.metric_now') : $r('app.string.trends_days', n))
          .fontSize($r('app.float.font_small'))
          .fontWeight(this.span === n ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.span === n ? $r('app.color.ink') : $r('app.color.ink_3'))
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(36)
          .borderRadius(10)
          .backgroundColor(this.span === n ? $r('app.color.surface') : Color.Transparent)
          .accessibilityText(n === 0 ? $r('app.string.metric_now') : $r('app.string.trends_days_a11y', n))
          .accessibilitySelected(this.span === n)
          .onClick(() => {
            this.onPick(n);
          })
      }, (n: number) => `${n}`)
    }
    .width('100%')
    .padding(4)
    .backgroundColor($r('app.color.surface_alt'))
    .borderRadius($r('app.float.radius_btn'))
  }
}
