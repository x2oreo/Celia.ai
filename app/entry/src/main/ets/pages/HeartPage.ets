// Heart tab (DESIGN.md §10.2): header, ring hero, quick links (Trends, symptom log, doctor prep) seen without
// scrolling, trend line, extra vitals, recent alerts, and the demo controls (clearly labelled). Heart rate only,
// never QT.

import { VitalsAlert, VitalsSample } from '../model/Vitals';
import { VitalsService } from '../vitals/VitalsService';
import { SCENARIOS, ScenarioName } from '../vitals/SimulatedSource';
import { clock } from '../common/Format';
import { HrChart } from '../components/HrChart';
import { QuickReplyChip, RiskShape, ScreenHeader, SectionHeader } from '../components/Common';
import { HrRing, HrZone } from '../components/HrRing';
import { Routes } from '../common/Routes';
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

@ComponentV2
export struct HeartPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local latest: VitalsSample | undefined = undefined;
  @Local hrs: number[] = [];
  @Local alerts: VitalsAlert[] = [];
  @Local scenario: ScenarioName = 'normal';
  @Local showSim: boolean = false;
  @Local chartWidth: number = 320;
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
  }

  aboutToDisappear(): void {
    this.offSample();
    this.offAlert();
  }

  private caption(): Resource {
    if (this.latest === undefined) {
      return $r('app.string.home_bpm_waiting');
    }
    if (this.latest.asleep === true) {
      return $r('app.string.home_bpm_asleep');
    }
    return (this.latest.steps ?? 0) > 60 ? $r('app.string.home_bpm_active') : $r('app.string.home_bpm_resting');
  }

  private zone(): HrZone {
    const bpm: number = this.latest?.hr ?? 0;
    if (bpm <= 0 || this.latest?.asleep === true) {
      return 'CALM';
    }
    const resting: boolean = (this.latest?.steps ?? 0) <= 60;
    return (resting && bpm >= 120) || bpm < 45 ? 'ELEVATED' : 'CALM';
  }

  @Builder
  stat(label: Resource, value: ResourceStr) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize($r('app.float.font_subtitle'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
      Text(label)
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.ink_3'))
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor($r('app.color.surface_alt'))
    .borderRadius($r('app.float.radius_s'))
    .accessibilityGroup(true)
  }

  private alertWord(a: VitalsAlert): Resource {
    const bpm: number = Math.round(a.hr);
    if (a.severity === 'CRITICAL') {
      return $r('app.string.heart_alert_critical_a11y', bpm);
    }
    return a.severity === 'WARN' ? $r('app.string.heart_alert_warn_a11y', bpm) :
      $r('app.string.heart_alert_info_a11y', bpm);
  }

  // Quick links: the pages that used to sit under the alerts, now right under the ring.
  @Builder
  quickLinks() {
    Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
      QuickReplyChip({
        label: $r('app.string.heart_link_symptom'),
        icon: $r('app.media.ic_tab_heart'),
        onTap: () => {
          this.navStack.pushPathByName(Routes.SYMPTOM_LOG, null);
        }
      })
      QuickReplyChip({
        label: $r('app.string.trends_title'),
        icon: $r('app.media.ic_wave'),
        onTap: () => {
          this.navStack.pushPathByName(Routes.TRENDS, null);
        }
      })
      QuickReplyChip({
        label: $r('app.string.heart_link_doctor'),
        icon: $r('app.media.ic_doctor'),
        onTap: () => {
          this.navStack.pushPathByName(Routes.DOCTOR_PREP, null);
        }
      })
    }
    .width('100%')
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
    Scroll() {
      Column({ space: 12 }) {
        ScreenHeader({ title: $r('app.string.heart_title'), back: false })

        HrRing({
          bpm: this.latest?.hr ?? 0,
          caption: this.caption(),
          zone: this.zone(),
          live: this.latest !== undefined,
          simulated: this.latest?.source !== 'WATCH',
          dim: 216
        })
          .margin({ top: 4, bottom: 8 })

        this.quickLinks()

        // Trend + extra vitals
        Column({ space: 12 }) {
          Text($r('app.string.heart_trend'))
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink_3'))
          HrChart({ hrs: this.hrs, chartWidth: this.chartWidth, chartHeight: 96 })
          Row({ space: 8 }) {
            this.stat($r('app.string.heart_resting_hr'),
              this.latest?.restingHr === undefined ? '--' : `${this.latest?.restingHr}`)
            this.stat($r('app.string.heart_hrv'), this.latest?.hrv === undefined ? '--' :
              `${Math.round(this.latest?.hrv ?? 0)} ms`)
            this.stat($r('app.string.heart_rhythm'), this.latest?.irregular === true ?
              $r('app.string.heart_rhythm_irregular') : $r('app.string.heart_rhythm_regular'))
          }
          .width('100%')
          Text($r('app.string.heart_only_hr'))
            .fontSize($r('app.float.font_micro'))
            .fontColor($r('app.color.ink_4'))
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
      .padding({ left: $r('app.float.space_screen'), right: $r('app.float.space_screen'), bottom: 24 })
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .backgroundColor($r('app.color.bg'))
  }
}
