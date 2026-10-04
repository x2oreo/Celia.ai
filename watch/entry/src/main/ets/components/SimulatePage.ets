import { ArcList, ArcListAttribute, ArcListItem, ArcListItemAttribute, LengthMetrics } from '@kit.ArkUI';
import { ActivityOverride, WatchController } from '../controller/WatchController';
import { Genotype } from '../model/WatchMetric';
import { SCENARIOS, Scenario } from '../vitals/Scenarios';
import { Icon, OutlineBadge } from './Parts';
import { Theme } from './Theme';

/** An event stays in the running line this long, then the line goes back to the scenario. */
const EVENT_LINE_MS: number = 6000;
const SPEEDS: number[] = [1, 2, 4, 8];
const STATES: ActivityOverride[] = ['AUTO', 'REST', 'ACTIVE', 'ASLEEP'];
const GENOTYPES: Genotype[] = ['UNKNOWN', 'LQT1', 'LQT2', 'LQT3'];

function stateLabel(o: ActivityOverride): string {
  switch (o) {
    case 'REST':
      return 'Rest';
    case 'ACTIVE':
      return 'Active';
    case 'ASLEEP':
      return 'Asleep';
    default:
      return 'Auto';
  }
}

function clock(sec: number): string {
  const s = Math.max(0, sec);
  const r = s % 60;
  return `${Math.floor(s / 60)}:${r < 10 ? '0' : ''}${r}`;
}

/** Selected = white fill, dark text; the rest sit on `BUTTON`. */
@ComponentV2
struct SimChip {
  @Param @Require label: string;
  @Param on: boolean = false;
  @Event onTap: () => void = () => {};

  build() {
    Text(this.label)
      .fontSize(Theme.SMALL - 1)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.on ? Theme.ON_LIGHT : Theme.TEXT)
      .maxLines(1)
      .height(26)
      .padding({ left: 8, right: 8 })
      .borderRadius(13)
      .backgroundColor(this.on ? Theme.TEXT : Theme.BUTTON)
      .accessibilityText(`${this.label}${this.on ? ', selected' : ''}`)
      .onClick(() => this.onTap())
  }
}

/** A labelled group of chips that wraps. */
@ComponentV2
struct SimGroup {
  @Param label: string = '';
  @BuilderParam chips: () => void;

  build() {
    Column({ space: 5 }) {
      if (this.label.length > 0) {
        Text(this.label).fontSize(Theme.SMALL).fontColor(Theme.TEXT_2)
      }
      Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(5), cross: LengthMetrics.vp(5) } }) {
        this.chips()
      }
    }
    .width(Theme.LIST_WIDTH)
    .alignItems(HorizontalAlign.Start)
  }
}

/**
 * 06 Simulator: every demo control, the last page, only in a DEMO_MODE build. It drives what the emulator can't
 * produce (a fall, the wear sensor, HRV / oxygen / rhythm, the phone's context) through the same controller methods
 * the real signals use.
 */
@ComponentV2
export struct SimulatePage {
  @Param @Require ctrl: WatchController;

  toast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1500 });
    } catch (e) {
      // Toast is cosmetic.
    }
  }

  /** "LQT2 startle · 0:42" (after a play mark), or the event that just fired. Reads monitoringSec so it ticks every second. */
  runningLine(): string {
    const sec = this.ctrl.monitoringSec;
    if (this.ctrl.simEvent.length > 0 && Date.now() - this.ctrl.simEventAt < EVENT_LINE_MS) {
      return this.ctrl.simEvent;
    }
    const what = this.ctrl.sourceKind === 'SIMULATED' ? this.ctrl.scenarioLabel : 'Sensor';
    return `${what} · ${clock(sec)}`;
  }

  build() {
    ArcList({ initialIndex: 1 }) {
      ArcListItem() {
        Column({ space: 4 }) {
          OutlineBadge({ label: 'SIMULATOR · DEMO BUILD', dashed: true, color: Theme.TEXT })
          Row({ space: 5 }) {
            Icon({ src: $r('app.media.ic_tri_right'), color: Theme.ELEVATED, glyph: 10 })
            Text(this.runningLine())
              .fontSize(Theme.BODY)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.ELEVATED)
              .maxLines(1)
          }
        }
        .width('100%')
        .padding({ top: 6 })
      }
      .autoScale(false)
      ArcListItem() {
        SimGroup({ label: 'Source' }) {
          SimChip({ label: 'Sensor', on: this.ctrl.sourceKind === 'SENSOR', onTap: () => {
            this.ctrl.setSource('SENSOR');
          } })
          SimChip({ label: 'Demo', on: this.ctrl.sourceKind === 'SIMULATED', onTap: () => {
            this.ctrl.setSource('SIMULATED');
          } })
        }
      }
      .autoScale(false)
      ArcListItem() {
        SimGroup({ label: 'Scenario' }) {
          ForEach(SCENARIOS, (s: Scenario, i: number) => {
            SimChip({ label: s.label, on: this.ctrl.sourceKind === 'SIMULATED' && this.ctrl.scenarioIdx === i,
              onTap: () => {
                this.ctrl.setScenario(i);
                this.ctrl.setSource('SIMULATED');
              } })
          }, (s: Scenario) => s.id)
        }
      }
      .autoScale(false)
      ArcListItem() {
        SimGroup({ label: 'Speed' }) {
          ForEach(SPEEDS, (n: number) => {
            SimChip({ label: `${n}x`, on: this.ctrl.demoSpeed === n, onTap: () => {
              this.ctrl.setDemoSpeed(n);
            } })
          }, (n: number) => `${n}`)
        }
      }
      .autoScale(false)
      ArcListItem() {
        SimGroup({ label: 'Events' }) {
          SimChip({ label: 'Fall', onTap: () => {
            this.ctrl.simulateFall();
          } })
          SimChip({ label: 'High heart rate', on: this.ctrl.anomaly === 'hr', onTap: () => {
            this.ctrl.triggerAnomaly('hr');
          } })
          SimChip({ label: 'Irregular rhythm', on: this.ctrl.anomaly === 'rhythm', onTap: () => {
            this.ctrl.triggerAnomaly('rhythm');
          } })
          SimChip({ label: 'Low HRV', on: this.ctrl.anomaly === 'hrv', onTap: () => {
            this.ctrl.triggerAnomaly('hrv');
          } })
          SimChip({ label: 'Low oxygen', on: this.ctrl.anomaly === 'spo2', onTap: () => {
            this.ctrl.triggerAnomaly('spo2');
          } })
          SimChip({ label: this.ctrl.onWrist ? 'Take watch off' : 'Put watch on', on: !this.ctrl.onWrist, onTap: () => {
            this.ctrl.toggleWorn();
          } })
        }
      }
      .autoScale(false)
      ArcListItem() {
        SimGroup({ label: 'State' }) {
          ForEach(STATES, (o: ActivityOverride) => {
            SimChip({ label: stateLabel(o), on: this.ctrl.activityOverride === o, onTap: () => {
              this.ctrl.setActivityOverride(o);
            } })
          }, (o: ActivityOverride) => o)
        }
      }
      .autoScale(false)
      ArcListItem() {
        SimGroup({ label: 'Genotype' }) {
          ForEach(GENOTYPES, (g: Genotype) => {
            SimChip({ label: g === 'UNKNOWN' ? 'None' : g, on: this.ctrl.genotype === g, onTap: () => {
              this.ctrl.setGenotype(g);
            } })
          }, (g: Genotype) => g)
        }
      }
      .autoScale(false)
      ArcListItem() {
        SimGroup({ label: 'Risky medicine' }) {
          SimChip({ label: 'On', on: this.ctrl.riskyDrug.length > 0, onTap: () => {
            this.ctrl.setRiskyDrugOn(true);
          } })
          SimChip({ label: 'Off', on: this.ctrl.riskyDrug.length === 0, onTap: () => {
            this.ctrl.setRiskyDrugOn(false);
          } })
        }
      }
      .autoScale(false)
      ArcListItem() {
        SimGroup({ label: 'Beta-blocker' }) {
          SimChip({ label: 'Taken', on: !this.ctrl.betaBlockerMissed, onTap: () => {
            this.setMissed(false);
          } })
          SimChip({ label: 'Missed', on: this.ctrl.betaBlockerMissed, onTap: () => {
            this.setMissed(true);
          } })
        }
      }
      .autoScale(false)
      ArcListItem() {
        SimGroup() {
          SimChip({ label: 'Dose nudge now', onTap: () => {
            this.ctrl.showDoseNudgeNow();
          } })
          SimChip({ label: 'Reminder in 10 s', onTap: () => {
            this.ctrl.testMedicationReminder().then((ok: boolean) => {
              this.toast(ok ? 'Reminder set. You can close the app.' : 'Reminder failed');
            });
          } })
        }
      }
      .autoScale(false)
      ArcListItem() {
        Column().height(48)
      }
      .autoScale(false)
    }
    .space(LengthMetrics.vp(10))
    .scrollBar(BarState.Auto)
    .width('100%')
    .height('100%')
  }

  setMissed(missed: boolean): void {
    this.ctrl.setBetaBlockerMissed(missed).then((ok: boolean) => {
      if (!ok) {
        this.toast('Server not ready (see log)');
      }
    });
  }
}
