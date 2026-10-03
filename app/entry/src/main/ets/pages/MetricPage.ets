// One health metric (DESIGN.md §10.1a 04a, §6.10): the value, the chart with its usual range, what the number
// means by fixed rules, and three stats. Heart rate adds the live line. Never QT, never a diagnosis.

import { VitalsSample } from '../model/Vitals';
import { VitalsService } from '../vitals/VitalsService';
import { loadMetrics, MetricsData } from '../vitals/MetricHistory';
import {
  bandText, chartForm, formatValue, liveDays, MetricBand, metricBand, MetricDay, MetricKind, METRIC_KINDS,
  MetricSeries, MetricStats, metricStats, MetricStatus, metricStatus, MOCKED_KINDS, sampleBand, seriesFor,
  unitText
} from '../vitals/Metrics';
import { TrendDay } from '../vitals/Trends';
import { MetricUi } from '../common/MetricUi';
import { AskParam, MetricParam, Routes } from '../common/Routes';
import { CapsLabel, EmptyCard, PrimaryButton, resText, ScreenHeader, SourceBadge } from '../components/Common';
import { MetricChart } from '../components/MetricChart';
import { ChangeChip, SpanSegments, StatusPill } from '../components/MetricParts';

const LIVE_SLOTS: number = 90;

// One number over its label. A component, not a @Builder with arguments: those are passed by value and would keep
// the first span's numbers.
@ComponentV2
struct StatCell {
  @Param label: ResourceStr = '';
  @Param value: string = '';
  @Param unit: string = '';

  build() {
    Column({ space: 2 }) {
      Row({ space: 3 }) {
        Text(this.value)
          .fontSize($r('app.float.font_subtitle'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Text(this.unit)
          .fontSize($r('app.float.font_micro'))
          .fontColor($r('app.color.ink_3'))
          .margin({ bottom: 2 })
      }
      .alignItems(VerticalAlign.Bottom)
      Text(this.label)
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.ink_3'))
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_m'))
    .accessibilityGroup(true)
  }
}

@ComponentV2
export struct MetricPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local kind: MetricKind = 'RESTING_HR';
  @Local span: number = 14;                       // 0 = now (heart rate only)
  @Local data: MetricsData | undefined = undefined;
  @Local latest: VitalsSample | undefined = undefined;
  @Local live: MetricDay[] = [];
  private wanted: number = 14;
  private loaded: number = 0;
  private offSample: () => void = () => {
  };

  aboutToAppear(): void {
    const svc: VitalsService = VitalsService.get();
    this.latest = svc.latest();
    this.live = liveDays(svc.history(), LIVE_SLOTS);
    this.offSample = svc.onSample((s: VitalsSample) => {
      this.latest = s;
      this.live = liveDays(VitalsService.get().history(), LIVE_SLOTS);
    });
  }

  aboutToDisappear(): void {
    this.offSample();
  }

  private async load(n: number): Promise<void> {
    this.wanted = n;
    const d: MetricsData = await loadMetrics(Date.now(), n);
    if (this.wanted === n) {
      this.data = d;
      this.loaded = n;
    }
  }

  // "Now" keeps the days already loaded: it only swaps the chart for the live line.
  private pick(n: number): void {
    this.span = n;
    if (n !== 0 && n !== this.loaded) {
      this.data = undefined;
      this.load(n);
    }
  }

  private now(): boolean {
    return this.span === 0;
  }

  private series(): MetricSeries {
    return seriesFor(this.data !== undefined ? this.data.series : [], this.kind);
  }

  private days(): MetricDay[] {
    return this.now() ? this.live : this.series().days;
  }

  private band(): MetricBand {
    return this.now() && this.latest !== undefined ? sampleBand(this.latest) : metricBand(this.kind, this.series().days);
  }

  private status(): MetricStatus {
    if (this.now() && this.latest !== undefined) {
      return metricStatus(this.kind, this.series().days, Math.round(this.latest.hr), sampleBand(this.latest));
    }
    return metricStatus(this.kind, this.series().days);
  }

  private stats(): MetricStats {
    return metricStats(this.days());
  }

  private simulated(): boolean {
    if (this.now()) {
      return this.latest?.source !== 'WATCH';
    }
    return this.series().simulated;
  }

  private marks(): TrendDay[] {
    return this.kind === 'RESTING_HR' && this.data !== undefined ? this.data.trend.days : [];
  }

  private usual(): string {
    return bandText(this.kind, this.band());
  }

  private ask(): void {
    const name: string = resText(this.getUIContext(), MetricUi.label(this.kind)).toLowerCase();
    this.navStack.pushPathByName(Routes.AGENT_CHAT, new AskParam(`What does my ${name} trend mean for me?`));
  }

  @Builder
  hero() {
    Row({ space: 6 }) {
      Text(formatValue(this.kind, this.status().value))
        .fontSize($r('app.float.font_display'))
        .fontWeight(800)
        .fontColor($r('app.color.ink'))
      Text(unitText(this.kind))
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.ink_3'))
        .margin({ bottom: 12 })
      Blank()
      Column({ space: 8 }) {
        SourceBadge({
          label: this.simulated() ? $r('app.string.badge_simulated') : $r('app.string.badge_watch'),
          solid: !this.simulated()
        })
        StatusPill({ level: this.status().level })
      }
      .alignItems(HorizontalAlign.End)
      .margin({ bottom: 10 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Bottom)
    .accessibilityGroup(true)
  }

  @Builder
  chartCard() {
    Column({ space: 12 }) {
      MetricChart({
        kind: this.kind,
        days: this.days(),
        form: this.now() ? 'LINE' : chartForm(this.kind),
        band: this.band(),
        live: this.now(),
        marks: this.now() ? [] : this.marks()
      })
      if (this.usual().length > 0) {
        Row({ space: 8 }) {
          Row()
            .width(14)
            .height(10)
            .borderRadius(3)
            .backgroundColor($r('app.color.surface_alt'))
            .border({ width: 1, color: $r('app.color.border') })
          Text(this.band().personal ? $r('app.string.metric_usual_personal', this.usual()) :
            $r('app.string.metric_usual_fixed', this.usual()))
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.ink_3'))
        }
      }
      Text(MOCKED_KINDS.includes(this.kind) ? $r('app.string.metric_simulated_note') :
        (this.kind === 'HEART_RATE' || this.kind === 'RESTING_HR' ? $r('app.string.health_not_ecg') :
          $r('app.string.metric_from_watch_note')))
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.ink_3'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_l'))
  }

  // What this means: the level, the change, one fixed sentence each, then what the number is.
  @Builder
  meaning() {
    Column({ space: 12 }) {
      CapsLabel({ text: $r('app.string.metric_means') })
      Row({ space: 10 }) {
        StatusPill({ level: this.status().level })
        ChangeChip({ kind: this.kind, trend: this.status().direction, delta: this.status().delta, unit: true })
      }
      Column({ space: 4 }) {
        Text(MetricUi.reason(this.status().reason))
          .fontSize($r('app.float.font_body'))
          .fontWeight(FontWeight.Medium)
          .lineHeight(23)
          .fontColor($r('app.color.ink'))
          .width('100%')
        Text(MetricUi.change(this.status().direction,
          `${formatValue(this.kind, this.status().delta)} ${unitText(this.kind)}`))
          .fontSize($r('app.float.font_body'))
          .lineHeight(23)
          .fontColor($r('app.color.ink_2'))
          .width('100%')
      }
      Divider().color($r('app.color.divider'))
      CapsLabel({ text: $r('app.string.metric_about') })
      Text(MetricUi.about(this.kind))
        .fontSize($r('app.float.font_small'))
        .lineHeight(20)
        .fontColor($r('app.color.ink_2'))
        .width('100%')
      Text($r('app.string.metric_rules_note'))
        .fontSize($r('app.float.font_micro'))
        .fontColor($r('app.color.ink_4'))
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_l'))
  }

  @Builder
  body() {
    if (this.data === undefined) {
      LoadingProgress().width(32).height(32).color($r('app.color.ink_3')).margin({ top: 48 })
        .accessibilityText($r('app.string.a11y_loading'))
    } else if (this.data.trend.source === 'OFFLINE' && !this.now()) {
      EmptyCard({
        message: $r('app.string.trends_offline'),
        action: $r('app.string.check_retry'),
        onAction: () => {
          this.data = undefined;
          this.load(this.wanted);
        }
      })
    } else if (this.stats().count === 0) {
      // The watch answered but has nothing for this metric: say so, never fill in demo data.
      EmptyCard({ message: $r('app.string.metric_no_history') })
    } else {
      this.chartCard()
      this.meaning()
      Row({ space: 8 }) {
        StatCell({
          label: $r('app.string.metric_avg'),
          value: formatValue(this.kind, this.stats().avg),
          unit: unitText(this.kind)
        })
        StatCell({
          label: $r('app.string.metric_lowest'),
          value: formatValue(this.kind, this.stats().min),
          unit: unitText(this.kind)
        })
        StatCell({
          label: $r('app.string.metric_highest'),
          value: formatValue(this.kind, this.stats().max),
          unit: unitText(this.kind)
        })
      }
      .width('100%')
    }
  }

  build() {
    NavDestination() {
      Column() {
        ScreenHeader({ title: MetricUi.label(this.kind), settings: false })
        Scroll() {
          Column({ space: 12 }) {
            this.hero()
            SpanSegments({
              spans: this.kind === 'HEART_RATE' ? [0, 14, 30] : [14, 30],
              span: this.span,
              onPick: (n: number) => {
                this.pick(n);
              }
            })
            this.body()
          }
          .padding({ left: 16, right: 16, bottom: 24 })
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Off)

        Row() {
          PrimaryButton({
            label: $r('app.string.metric_ask'),
            onTap: () => {
              this.ask();
            }
          })
            .layoutWeight(1)
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.bg'))
        .border({ width: { top: 1 }, color: $r('app.color.border') })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg'))
    .onReady((ctx: NavDestinationContext) => {
      const p: MetricParam | undefined = ctx.pathInfo.param as MetricParam | undefined;
      if (p !== undefined && p !== null && METRIC_KINDS.includes(p.kind as MetricKind)) {
        this.kind = p.kind as MetricKind;
      }
      // Heart rate opens on the live line: it is what the tab's card was showing.
      this.span = this.kind === 'HEART_RATE' ? 0 : 14;
      this.load(14);
    })
  }
}
