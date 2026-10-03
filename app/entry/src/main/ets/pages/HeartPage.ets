// Health tab (DESIGN.md §10.1a, screen 04; §6.10): every watch metric one tap from its graph. Now card with the
// live heart-rate line, a card per metric (value, mini chart, fixed-rule status), what stands out, alerts, demo
// controls. Log how I feel and Doctor visit stay pinned above the tab bar. Never QT, never an ECG.

import { VitalsAlert, VitalsSample, VitalsSourceKind } from '../model/Vitals';
import { VitalsService } from '../vitals/VitalsService';
import { SCENARIOS, ScenarioName } from '../vitals/SimulatedSource';
import { WatchSource } from '../vitals/WatchSource';
import { clock } from '../common/Format';
import {
  CapsLabel, EmptyCard, PrimaryButton, QuickReplyChip, RiskShape, ScreenHeader, SecondaryButton, SectionHeader,
  SourceBadge
} from '../components/Common';
import { MetricChart } from '../components/MetricChart';
import { MetricCard } from '../components/MetricParts';
import { WatchInsight } from '../model/WatchData';
import { loadMetrics, MetricsData } from '../vitals/MetricHistory';
import {
  liveDays, liveHrBand, MetricBand, MetricDay, MetricKind, MetricSeries, metricStatus, sampleBand, seriesFor
} from '../vitals/Metrics';
import { MetricParam, Routes, TabIndex } from '../common/Routes';
import { LengthMetrics } from '@kit.ArkUI';

export function severityColor(a: VitalsAlert): Resource {
  switch (a.severity) {
    case 'CRITICAL':
      return $r('app.color.risk_known');
    case 'WARN':
      return $r('app.color.risk_possible');
    default:
      return $r('app.color.risk_unknown');
  }
}

const SPAN: number = 14;
const LIVE_SLOTS: number = 90;
// The grid under the full-width resting heart rate card, two per row.
const GRID: MetricKind[][] = [['HRV', 'SPO2'], ['BREATHING', 'SLEEP'], ['STEPS', 'STRESS']];

@ComponentV2
export struct HeartPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local latest: VitalsSample | undefined = undefined;
  @Local live: MetricDay[] = [];
  @Local alerts: VitalsAlert[] = [];
  @Local scenario: ScenarioName = 'normal';
  @Local showSim: boolean = false;
  @Local source: VitalsSourceKind = WatchSource.active();
  @Local data: MetricsData | undefined = undefined;
  @Consumer('tabIndex') activeTab: number = TabIndex.HOME;
  private offSample: () => void = () => {
  };
  private offAlert: () => void = () => {
  };

  aboutToAppear(): void {
    const svc: VitalsService = VitalsService.get();
    this.latest = svc.latest();
    this.live = liveDays(svc.history(), LIVE_SLOTS);
    this.alerts = svc.alertHistory();
    this.scenario = svc.currentScenario();
    this.source = WatchSource.active();
    this.offSample = svc.onSample((s: VitalsSample) => {
      this.latest = s;
      this.live = liveDays(VitalsService.get().history(), LIVE_SLOTS);
    });
    this.offAlert = svc.onAlert(() => {
      this.alerts = VitalsService.get().alertHistory();
    });
    this.load();
  }

  // Coming back to the tab: doses and symptoms logged elsewhere show up.
  @Monitor('activeTab')
  onTab(m: IMonitor): void {
    if (this.activeTab === TabIndex.HEART) {
      this.load();
    }
  }

  private async load(): Promise<void> {
    this.data = await loadMetrics(Date.now(), SPAN);
  }

  // Watch ↔ simulation: the live line starts again and the history is loaded from the new source.
  private async pick(kind: VitalsSourceKind): Promise<void> {
    if (kind === this.source) {
      return;
    }
    await WatchSource.set(kind);
    const svc: VitalsService = VitalsService.get();
    svc.restart();
    this.source = WatchSource.active();
    this.scenario = svc.currentScenario();
    this.latest = undefined;
    this.live = liveDays([], LIVE_SLOTS);
    this.data = undefined;
    this.load();
  }

  private series(kind: MetricKind): MetricSeries {
    return seriesFor(this.data !== undefined ? this.data.series : [], kind);
  }

  private open(kind: MetricKind): void {
    this.navStack.pushPathByName(Routes.METRIC, new MetricParam(kind));
  }

  // The reading's own label; before the first reading, the source picked.
  private badgeSource(): VitalsSourceKind {
    return this.latest !== undefined ? this.latest.source : this.source;
  }

  private liveBand(): MetricBand {
    return this.latest !== undefined ? sampleBand(this.latest) : liveHrBand(false, false);
  }

  aboutToDisappear(): void {
    this.offSample();
    this.offAlert();
  }

  // The reading in words, so the number never stands alone.
  private rangeLine(): Resource {
    if (this.latest === undefined) {
      return $r('app.string.home_bpm_waiting');
    }
    if (this.latest.asleep === true) {
      return $r('app.string.heart_asleep');
    }
    const bpm: number = this.latest.hr;
    const resting: boolean = (this.latest.steps ?? 0) <= 60;
    if (resting && bpm >= 120) {
      return $r('app.string.health_above_range');
    }
    if (bpm < 45) {
      return $r('app.string.health_below_range');
    }
    return resting ? $r('app.string.health_in_range') : $r('app.string.heart_active');
  }

  private alertWord(a: VitalsAlert): Resource {
    const bpm: number = Math.round(a.hr);
    if (a.severity === 'CRITICAL') {
      return $r('app.string.heart_alert_critical_a11y', bpm);
    }
    return a.severity === 'WARN' ? $r('app.string.heart_alert_warn_a11y', bpm) :
      $r('app.string.heart_alert_info_a11y', bpm);
  }

  // Now: the number in words, the live line of the last minutes, the rhythm flag. Opens the heart-rate page.
  @Builder
  nowCard() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Image($r('app.media.ic_heart_fill')).width(22).height(22).fillColor($r('app.color.brand_accent'))
        Text(this.latest === undefined ? '--' : `${Math.round(this.latest.hr)}`)
          .fontSize($r('app.float.font_title_1'))
          .fontWeight(800)
          .fontColor($r('app.color.ink'))
        Text($r('app.string.health_bpm_now'))
          .fontSize($r('app.float.font_small'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ink_3'))
          .layoutWeight(1)
        Column({ space: 4 }) {
          SourceBadge({
            label: this.badgeSource() === 'WATCH' ? $r('app.string.badge_watch') : $r('app.string.badge_simulated'),
            solid: this.badgeSource() === 'WATCH'
          })
          Text(this.rangeLine())
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink_2'))
            .textAlign(TextAlign.End)
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .accessibilityGroup(true)

      MetricChart({
        kind: 'HEART_RATE',
        days: this.live,
        form: 'LINE',
        band: this.liveBand(),
        plotHeight: 96,
        live: true,
        readout: false
      })

      Row({ space: 6 }) {
        Text($r('app.string.heart_rhythm'))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.ink_3'))
        Text(this.latest?.irregular === true ? $r('app.string.heart_rhythm_irregular') :
          $r('app.string.heart_rhythm_regular'))
          .fontSize($r('app.float.font_caption'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Blank()
        Text($r('app.string.health_see_days'))
          .fontSize($r('app.float.font_caption'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand_text'))
        Image($r('app.media.ic_chevron_right')).width(14).height(14).fillColor($r('app.color.brand_text'))
      }
      .width('100%')
      .accessibilityGroup(true)
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_l'))
    .onClick(() => {
      this.open('HEART_RATE');
    })
  }

  @Builder
  metricCard(kind: MetricKind, wide: boolean) {
    MetricCard({
      kind: kind,
      days: this.series(kind).days,
      status: metricStatus(kind, this.series(kind).days),
      simulated: this.series(kind).simulated,
      wide: wide,
      onTap: () => {
        this.open(kind);
      }
    })
  }

  @Builder
  insightLine(i: WatchInsight) {
    Text(i.message)
      .fontSize($r('app.float.font_button'))
      .fontWeight(600)
      .lineHeight(21)
      .fontColor($r('app.color.ink'))
      .width('100%')
  }

  // A card per metric over the last 14 days, then the fixed-rule findings.
  @Builder
  metrics() {
    if (this.data === undefined) {
      LoadingProgress().width(32).height(32).color($r('app.color.ink_3')).margin({ top: 32, bottom: 32 })
        .accessibilityText($r('app.string.a11y_loading'))
    } else if (this.data.trend.source === 'OFFLINE') {
      EmptyCard({
        message: $r('app.string.trends_offline'),
        action: $r('app.string.check_retry'),
        onAction: () => {
          this.data = undefined;
          this.load();
        }
      })
    } else {
      this.metricCard('RESTING_HR', true)
      ForEach(GRID, (pair: MetricKind[]) => {
        Row({ space: 12 }) {
          Column() {
            this.metricCard(pair[0], false)
          }
          .layoutWeight(1)
          Column() {
            this.metricCard(pair[1], false)
          }
          .layoutWeight(1)
        }
        .width('100%')
      }, (pair: MetricKind[]) => pair[0])

      if (this.data.trend.insights.length > 0) {
        Column({ space: 8 }) {
          CapsLabel({ text: $r('app.string.trends_findings') })
          ForEach(this.data.trend.insights, (i: WatchInsight) => {
            this.insightLine(i)
          }, (i: WatchInsight) => `${i.kind}-${i.ts}`)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.border') })
        .borderRadius($r('app.float.radius_ml'))
        .accessibilityGroup(true)
      }
    }
  }

  // The two actions people come here for, pinned above the tab bar. The gap in the middle leaves room for the orb.
  @Builder
  pinned() {
    Row({ space: 10 }) {
      PrimaryButton({
        label: $r('app.string.home_log_feel'),
        onTap: () => {
          this.navStack.pushPathByName(Routes.SYMPTOM_LOG, null);
        }
      })
        .layoutWeight(1)
      SecondaryButton({
        label: $r('app.string.doctor_visit'),
        onTap: () => {
          this.navStack.pushPathByName(Routes.DOCTOR_PREP, null);
        }
      })
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: $r('app.float.space_m'), right: $r('app.float.space_m'), top: 10, bottom: 14 })
    .backgroundColor($r('app.color.bg'))
    .border({ width: { top: 1 }, color: $r('app.color.border') })
  }

  // Alert row: out-of-range chip (risk tint + shape + value) and the plain-English message.
  @Builder
  alertRow(a: VitalsAlert) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Row({ space: 6 }) {
          RiskShape({ risk: a.severity === 'CRITICAL' ? 'KNOWN_RISK' : (a.severity === 'WARN' ? 'POSSIBLE_RISK' :
            'UNKNOWN_DRUG'), dim: 18 })
            .accessibilityLevel('no-hide-descendants')
          Text(a.hr > 0 ? $r('app.string.heart_bpm_value', Math.round(a.hr)) : '—')
            .accessibilityText(this.alertWord(a))
            .fontSize($r('app.float.font_badge'))
            .fontWeight(FontWeight.Bold)
            .fontColor(a.severity === 'CRITICAL' ? $r('app.color.risk_known_text') : (a.severity === 'WARN' ?
              $r('app.color.risk_possible_text') : $r('app.color.risk_unknown_text')))
        }
        .height(32)
        .padding({ left: 8, right: 12 })
        .borderRadius(16)
        .backgroundColor(a.severity === 'CRITICAL' ? $r('app.color.risk_known_tint') : (a.severity === 'WARN' ?
          $r('app.color.risk_possible_tint') : $r('app.color.risk_unknown_tint')))
        .border({
          width: 1,
          color: a.severity === 'CRITICAL' ? $r('app.color.risk_known_border') : (a.severity === 'WARN' ?
            $r('app.color.risk_possible_border') : $r('app.color.risk_unknown_border'))
        })
        Blank()
        Text(clock(a.ts))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.ink_3'))
      }
      .width('100%')
      Text(a.message)
        .fontSize($r('app.float.font_small'))
        .fontColor($r('app.color.ink_2'))
        .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_m'))
    .accessibilityGroup(true, { accessibilityPreferred: true })
  }

  build() {
    Column() {
    Scroll() {
      Column({ space: 12 }) {
        ScreenHeader({ title: $r('app.string.health_title'), back: false })

        this.nowCard()
        CapsLabel({ text: $r('app.string.health_from_watch', SPAN) })
          .width('100%')
          .margin({ top: 8 })
        this.metrics()

        SectionHeader({ title: $r('app.string.heart_alerts') })
        if (this.alerts.length === 0) {
          Text($r('app.string.heart_no_alerts'))
            .fontSize($r('app.float.font_small'))
            .fontColor($r('app.color.ink_3'))
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.surface'))
            .border({ width: 1, color: $r('app.color.border') })
            .borderRadius($r('app.float.radius_m'))
        } else {
          ForEach(this.alerts.slice(0, 6), (a: VitalsAlert) => {
            this.alertRow(a)
          }, (a: VitalsAlert) => `${a.ts}-${a.kind}`)
        }


        // Demo controls: the data source (when the watch's project can be reached) and, for the phone's own
        // simulated source, the scenarios (the watch has its own Simulate page).
        if (this.source !== 'WATCH' || WatchSource.available()) {
        Column({ space: 12 }) {
          Row() {
            Text($r('app.string.heart_sim_controls'))
              .fontSize($r('app.float.font_small'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.ink_3'))
              .layoutWeight(1)
            Image($r('app.media.ic_chevron_right'))
              .width(16)
              .height(16)
              .fillColor($r('app.color.ink_4'))
              .rotate({ angle: this.showSim ? 90 : 0 })
              .animation({ duration: 180, curve: Curve.EaseOut })
          }
          .width('100%')
          .height($r('app.float.chip_height'))
          .accessibilityGroup(true)
          .accessibilityDescription(this.showSim ? $r('app.string.a11y_expanded') : $r('app.string.a11y_collapsed'))
          .onClick(() => {
            this.showSim = !this.showSim;
          })
          if (this.showSim && WatchSource.available()) {
            Column({ space: 8 }) {
              CapsLabel({ text: $r('app.string.heart_source') })
              Row({ space: 8 }) {
                QuickReplyChip({
                  label: $r('app.string.heart_source_watch'),
                  chipStyle: this.source === 'WATCH' ? 'SELECTED' : 'DEFAULT',
                  onTap: () => {
                    this.pick('WATCH');
                  }
                })
                QuickReplyChip({
                  label: $r('app.string.heart_source_simulated'),
                  chipStyle: this.source === 'SIMULATED' ? 'SELECTED' : 'DEFAULT',
                  onTap: () => {
                    this.pick('SIMULATED');
                  }
                })
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          if (this.showSim && this.source !== 'WATCH') {
            Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
              ForEach(SCENARIOS, (name: ScenarioName) => {
                QuickReplyChip({
                  label: name.replace(/_/g, ' '),
                  chipStyle: this.scenario === name ? 'SELECTED' : 'DEFAULT',
                  onTap: () => {
                    this.scenario = name;
                    VitalsService.get().runScenario(name);
                  }
                })
              }, (name: ScenarioName) => name)
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: this.showSim ? 16 : 4 })
        .border({ width: 1, color: $r('app.color.border'), style: BorderStyle.Dashed })
        .borderRadius($r('app.float.radius_m'))
        }
      }
      .padding({ left: $r('app.float.space_m'), right: $r('app.float.space_m'), bottom: 24 })
      .width('100%')
    }
    .width('100%')
    .layoutWeight(1)
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    this.pinned()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg'))
  }
}
