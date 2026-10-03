// Heart tab: live heart rate, sparkline, extra vitals, recent alerts, simulation controls (clearly labelled).

import { VitalsAlert, VitalsSample } from '../model/Vitals';
import { VitalsService } from '../vitals/VitalsService';
import { SCENARIOS, ScenarioName } from '../vitals/SimulatedSource';
import { clock } from '../common/Format';
import { HrChart } from '../components/HrChart';
import { PageTitle, SectionHeader } from '../components/Common';

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

  private stateLabel(): Resource {
    if (this.latest === undefined) {
      return $r('app.string.heart_waiting');
    }
    if (this.latest.asleep === true) {
      return $r('app.string.heart_asleep');
    }
    return (this.latest.steps ?? 0) > 60 ? $r('app.string.heart_active') : $r('app.string.heart_resting');
  }

  @Builder
  stat(label: Resource, value: string) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize($r('app.float.font_subtitle'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Text(label)
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  alertRow(a: VitalsAlert) {
    Row({ space: 12 }) {
      Column()
        .width(4)
        .height('100%')
        .backgroundColor(severityColor(a))
        .borderRadius(2)
      Column({ space: 4 }) {
        Text(`${clock(a.ts)} · ${a.hr > 0 ? `${a.hr} bpm` : '—'}`)
          .fontSize($r('app.float.font_caption'))
          .fontColor(severityColor(a))
          .fontWeight(FontWeight.Medium)
        Text(a.message)
          .fontSize($r('app.float.font_small'))
          .fontColor($r('sys.color.font_primary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .height('auto')
    .padding(14)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius($r('app.float.radius_m'))
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Row() {
          PageTitle({ title: $r('app.string.heart_title'), subtitle: $r('app.string.heart_subtitle') })
            .layoutWeight(1)
          Text($r('app.string.heart_simulated'))
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.sim_badge'))
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor($r('app.color.sim_badge_soft'))
            .borderRadius(100)
        }
        .width('100%')

        // Live heart rate
        Column({ space: 12 }) {
          Row({ space: 8 }) {
            Image($r('app.media.ic_tab_heart'))
              .width(28)
              .height(28)
              .fillColor($r('app.color.brand_accent'))
            Text(this.latest === undefined ? '--' : `${this.latest.hr}`)
              .fontSize($r('app.float.font_hero'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_primary'))
              .fontFeature('"tnum" on')
            Text('bpm')
              .fontSize($r('app.float.font_body'))
              .fontColor($r('sys.color.font_secondary'))
              .margin({ top: 18 })
            Blank()
            Text(this.stateLabel())
              .fontSize($r('app.float.font_small'))
              .fontColor($r('sys.color.font_secondary'))
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          HrChart({ hrs: this.hrs, chartWidth: this.chartWidth, chartHeight: 110 })
          Row() {
            this.stat($r('app.string.heart_resting_hr'),
              this.latest?.restingHr === undefined ? '--' : `${this.latest?.restingHr}`)
            this.stat($r('app.string.heart_hrv'), this.latest?.hrv === undefined ? '--' :
              `${Math.round(this.latest?.hrv ?? 0)} ms`)
            this.stat($r('app.string.heart_rhythm'), this.latest?.irregular === true ? 'Irregular' : 'Regular')
          }
          .width('100%')
        }
        .width('100%')
        .padding(20)
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius($r('app.float.radius_l'))
        .onAreaChange((oldArea: Area, newArea: Area) => {
          this.chartWidth = Math.max(100, (newArea.width as number) - 40);
        })

        SectionHeader({ title: $r('app.string.heart_alerts') })
        if (this.alerts.length === 0) {
          Text($r('app.string.heart_no_alerts'))
            .fontSize($r('app.float.font_body'))
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
            .padding(20)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius($r('app.float.radius_m'))
        } else {
          ForEach(this.alerts.slice(0, 6), (a: VitalsAlert) => {
            this.alertRow(a)
          }, (a: VitalsAlert) => `${a.ts}-${a.kind}`)
        }

        // Simulation controls — the emulator has no watch, so the data source is simulated and says so.
        Column({ space: 10 }) {
          Row() {
            Text($r('app.string.heart_sim_controls'))
              .fontSize($r('app.float.font_small'))
              .fontColor($r('app.color.sim_badge'))
              .layoutWeight(1)
            Image($r('app.media.ic_chevron_right'))
              .width(16)
              .height(16)
              .fillColor($r('app.color.sim_badge'))
              .rotate({ angle: this.showSim ? 90 : 0 })
          }
          .width('100%')
          .onClick(() => {
            this.showSim = !this.showSim;
          })
          if (this.showSim) {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(SCENARIOS, (name: ScenarioName) => {
                Text(name.replace(/_/g, ' '))
                  .fontSize($r('app.float.font_small'))
                  .fontColor(this.scenario === name ? $r('app.color.on_accent') : $r('app.color.sim_badge'))
                  .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                  .margin({ right: 8, bottom: 8 })
                  .backgroundColor(this.scenario === name ? $r('app.color.sim_badge') : $r('app.color.sim_badge_soft'))
                  .borderRadius(100)
                  .onClick(() => {
                    this.scenario = name;
                    VitalsService.get().runScenario(name);
                  })
              }, (name: ScenarioName) => name)
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius($r('app.float.radius_m'))
      }
      .padding({ left: 16, right: 16, bottom: 24 })
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .backgroundColor($r('app.color.page_bg'))
  }
}
