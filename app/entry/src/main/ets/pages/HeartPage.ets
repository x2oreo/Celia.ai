// Health tab (DESIGN.md §10.1a, screen 04): the graph is the screen. Now card, three vitals, a Today / 14 days /
// 30 days switch over one chart card (last minutes, or resting heart rate per day with dose and symptom rows), stat
// tiles, what stands out, alerts, demo controls. Log how I feel and Doctor visit stay pinned above the tab bar.
// Heart rate only, never QT.

import { VitalsAlert, VitalsSample } from '../model/Vitals';
import { VitalsService } from '../vitals/VitalsService';
import { SCENARIOS, ScenarioName } from '../vitals/SimulatedSource';
import { clock } from '../common/Format';
import { HrChart } from '../components/HrChart';
import {
  CapsLabel, EmptyCard, PrimaryButton, QuickReplyChip, RiskShape, ScreenHeader, SecondaryButton, SectionHeader,
  SourceBadge
} from '../components/Common';
import { TrendChart } from '../components/TrendChart';
import { WatchInsight } from '../model/WatchData';
import { loadTrends, TrendData, TrendStats, trendStats } from '../vitals/Trends';
import { Routes, TabIndex } from '../common/Routes';
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

// One extra vital: value over its label. A component, not a @Builder with arguments: builder arguments are passed by
// value, so the tiles would keep the first reading.
@ComponentV2
struct HeartStat {
  @Param label: ResourceStr = '';
  @Param value: ResourceStr = '';

  build() {
    Column({ space: 2 }) {
      Text(this.value)
        .fontSize($r('app.float.font_subtitle'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
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

const SPANS: number[] = [0, 14, 30];   // 0 = today (the last minutes)

@ComponentV2
export struct HeartPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local latest: VitalsSample | undefined = undefined;
  @Local hrs: number[] = [];
  @Local alerts: VitalsAlert[] = [];
  @Local scenario: ScenarioName = 'normal';
  @Local showSim: boolean = false;
  @Local chartWidth: number = 320;
  @Local span: number = 14;
  @Local data: TrendData | undefined = undefined;
  @Consumer('tabIndex') activeTab: number = TabIndex.HOME;
  private offSample: () => void = () => {
  };
  private offAlert: () => void = () => {
  };

  aboutToAppear(): void {
    const svc: VitalsService = VitalsService.get();
    this.latest = svc.latest();
    this.hrs = svc.history().map((s: VitalsSample) => s.hr);
    this.alerts = svc.alertHistory();
    this.scenario = svc.currentScenario();
    this.offSample = svc.onSample((s: VitalsSample) => {
      this.latest = s;
      const next: number[] = this.hrs.slice(this.hrs.length >= 90 ? 1 : 0);
      next.push(s.hr);
      this.hrs = next;
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
    const forSpan: number = this.span;
    if (forSpan === 0) {
      return;
    }
    const d: TrendData = await loadTrends(Date.now(), forSpan);
    if (forSpan === this.span) {
      this.data = d;
    }
  }

  private pick(n: number): void {
    if (this.span === n) {
      return;
    }
    this.span = n;
    if (n > 0) {
      this.data = undefined;
      this.load();
    }
  }

  private stats(): TrendStats {
    return trendStats(this.data !== undefined ? this.data.days : []);
  }

  private changeText(): string {
    const s: TrendStats = this.stats();
    if (!s.hasChange) {
      return '–';
    }
    return s.change > 0 ? `+${s.change}` : `${s.change}`;
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

  @Builder
  nowCard() {
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
          label: this.latest?.source === 'WATCH' ? $r('app.string.badge_watch') : $r('app.string.badge_simulated'),
          solid: this.latest?.source === 'WATCH'
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
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_ml'))
    .accessibilityGroup(true)
  }

  @Builder
  vitals() {
    Row({ space: 8 }) {
      HeartStat({
        label: $r('app.string.heart_resting_hr'),
        value: this.latest?.restingHr === undefined ? '--' : `${this.latest?.restingHr}`
      })
      HeartStat({
        label: $r('app.string.heart_hrv'),
        value: this.latest?.hrv === undefined ? '--' : `${Math.round(this.latest?.hrv ?? 0)} ms`
      })
      HeartStat({
        label: $r('app.string.heart_rhythm'),
        value: this.latest?.irregular === true ? $r('app.string.heart_rhythm_irregular') :
          $r('app.string.heart_rhythm_regular')
      })
    }
    .width('100%')
  }

  // Today · 14 days · 30 days: surface-alt track, the selected segment on surface.
  @Builder
  segments() {
    Row() {
      ForEach(SPANS, (n: number) => {
        Text(n === 0 ? $r('app.string.health_today') : $r('app.string.trends_days', n))
          .fontSize($r('app.float.font_small'))
          .fontWeight(this.span === n ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.span === n ? $r('app.color.ink') : $r('app.color.ink_3'))
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(36)
          .borderRadius(10)
          .backgroundColor(this.span === n ? $r('app.color.surface') : Color.Transparent)
          .accessibilityText(n === 0 ? $r('app.string.health_today') : $r('app.string.trends_days_a11y', n))
          .accessibilitySelected(this.span === n)
          .onClick(() => {
            this.pick(n);
          })
      }, (n: number) => `${n}`)
    }
    .width('100%')
    .padding(4)
    .backgroundColor($r('app.color.surface_alt'))
    .borderRadius($r('app.float.radius_btn'))
  }

  @Builder
  todayCard() {
    Column({ space: 12 }) {
      Text($r('app.string.heart_trend'))
        .fontSize($r('app.float.font_headline'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
      HrChart({ hrs: this.hrs, chartWidth: this.chartWidth, chartHeight: 120 })
      Text($r('app.string.heart_only_hr'))
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.ink_3'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_l'))
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.chartWidth = Math.max(100, (newArea.width as number) - 34);
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

  // Resting heart rate per day with the dose and symptom rows, then the numbers and the fixed-rule findings.
  @Builder
  trendBlock() {
    if (this.data === undefined) {
      LoadingProgress().width(32).height(32).color($r('app.color.ink_3')).margin({ top: 32, bottom: 32 })
        .accessibilityText($r('app.string.a11y_loading'))
    } else if (this.data.source === 'OFFLINE') {
      EmptyCard({
        message: $r('app.string.trends_offline'),
        action: $r('app.string.check_retry'),
        onAction: () => {
          this.data = undefined;
          this.load();
        }
      })
    } else if (this.data.source === 'WATCH' && this.stats().daysWithData === 0) {
      // The project answered, but this watch has no rows in the span: say so, never fill in demo data.
      EmptyCard({
        message: $r('app.string.trends_no_rows', this.data.days.length),
        action: this.span === 14 ? $r('app.string.trends_days', 30) : '',
        onAction: () => {
          this.pick(30);
        }
      })
    } else {
      Column({ space: 8 }) {
        Row() {
          Text($r('app.string.trends_chart_title'))
            .fontSize($r('app.float.font_headline'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
            .layoutWeight(1)
          // Honest source label: SIMULATED for demo history or watch rows marked simulated, WATCH for real rows.
          if (this.data.simulated) {
            SourceBadge({ label: $r('app.string.badge_simulated') })
          } else if (this.data.source === 'WATCH') {
            SourceBadge({ label: $r('app.string.badge_watch'), solid: true })
          }
        }
        .width('100%')
        TrendChart({
          days: this.data.days,
          doseLabel: $r('app.string.trends_row_dose'),
          symptomLabel: $r('app.string.trends_row_symptom')
        })
        Text($r('app.string.health_not_ecg'))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.ink_3'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.border') })
      .borderRadius($r('app.float.radius_l'))

      Row({ space: 8 }) {
        HeartStat({
          label: $r('app.string.health_resting_avg'),
          value: this.stats().avgResting > 0 ? `${this.stats().avgResting}` : '–'
        })
        HeartStat({ label: $r('app.string.health_vs_before'), value: this.changeText() })
        HeartStat({
          label: $r('app.string.health_days_dosed'),
          value: `${this.stats().doseDays}/${this.data.days.length}`
        })
      }
      .width('100%')

      if (this.data.insights.length > 0) {
        Column({ space: 8 }) {
          CapsLabel({ text: $r('app.string.trends_findings') })
          ForEach(this.data.insights, (i: WatchInsight) => {
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
        this.vitals()
        this.segments()
        if (this.span === 0) {
          this.todayCard()
        } else {
          this.trendBlock()
        }

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


        // Demo controls — only for the phone's own simulated source (the watch has its own Simulate page).
        if (VitalsService.get().sourceKind() !== 'WATCH') {
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
          if (this.showSim) {
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
