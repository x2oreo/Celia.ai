import { ArcList, ArcListAttribute, ArcListItem, ArcListItemAttribute, LengthMetrics } from '@kit.ArkUI';
import { WatchController } from '../controller/WatchController';
import { Caps, Icon } from './Parts';
import { Theme } from './Theme';

/** A setting the simulator cycles through on tap: label left, current value right. */
@ComponentV2
struct SimSetting {
  @Param @Require label: string;
  @Param @Require value: string;
  @Param on: boolean = false;
  @Event onTap: () => void = () => {};

  build() {
    Row({ space: 6 }) {
      Text(this.label).fontSize(Theme.SMALL).fontColor(Theme.TEXT_2).maxLines(1)
      Blank()
      Text(this.value)
        .fontSize(Theme.SMALL)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.on ? Theme.ON_LIGHT : Theme.TEXT)
        .maxLines(1)
        .padding({ left: 8, right: 8 })
        .height(24)
        .borderRadius(12)
        .backgroundColor(this.on ? Theme.ELEVATED : Theme.BUTTON)
    }
    .width(Theme.LIST_WIDTH)
    .height(44)
    .padding({ left: 14, right: 8 })
    .borderRadius(22)
    .backgroundColor(Theme.SURFACE)
    .border({ width: 1, color: Theme.BORDER, style: BorderStyle.Dashed })
    .accessibilityGroup(true)
    .accessibilityText(`${this.label}: ${this.value}. Tap to change.`)
    .onClick(() => this.onTap())
  }
}

/** A one-shot event (fall, irregular rhythm...): icon + verb. */
@ComponentV2
struct SimEvent {
  @Param @Require icon: Resource;
  @Param @Require label: string;
  @Param active: boolean = false;
  @Event onTap: () => void = () => {};

  build() {
    Row({ space: 8 }) {
      Icon({ src: this.icon, color: this.active ? Theme.ON_LIGHT : Theme.ELEVATED, glyph: 16 })
      Text(this.label)
        .fontSize(Theme.BODY)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.active ? Theme.ON_LIGHT : Theme.TEXT)
        .maxLines(1)
    }
    .width(Theme.LIST_WIDTH)
    .height(44)
    .padding({ left: 16, right: 12 })
    .borderRadius(22)
    .backgroundColor(this.active ? Theme.ELEVATED : Theme.SURFACE)
    .border({ width: 1, color: this.active ? Theme.ELEVATED : Theme.BORDER, style: BorderStyle.Dashed })
    .accessibilityGroup(true)
    .accessibilityText(`Simulate: ${this.label}`)
    .onClick(() => this.onTap())
  }
}

@ComponentV2
struct SimSection {
  @Param @Require title: string;

  build() {
    Row() {
      Caps({ text: this.title, color: Theme.ELEVATED })
    }
    .width(Theme.LIST_WIDTH)
    .padding({ left: 14, top: 8 })
  }
}

/**
 * The simulator: every demo control in one panel, the last page, only in a DEMO_MODE build. It drives what the
 * emulator can't produce (a fall, the wear sensor, HRV / oxygen / rhythm, the phone's context) through the same
 * controller methods the real signals use.
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

  stateValue(): string {
    switch (this.ctrl.activityOverride) {
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

  build() {
    ArcList({ initialIndex: 2 }) {
      ArcListItem() {
        Column({ space: 2 }) {
          Row({ space: 5 }) {
            Icon({ src: $r('app.media.ic_flask'), color: Theme.ELEVATED, glyph: 14 })
            Text('Simulator').fontSize(Theme.TITLE).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
          }
          Text('Demo build. Not real data.').fontSize(Theme.MICRO).fontColor(Theme.TEXT_3)
        }
        .width('100%')
        .padding({ top: 4, bottom: 2 })
      }

      ArcListItem() {
        SimSection({ title: 'HEART RATE' })
      }
      ArcListItem() {
        SimSetting({ label: 'Source', value: this.ctrl.sourceKind === 'SENSOR' ? 'Sensor' : 'Demo',
          on: this.ctrl.sourceKind === 'SIMULATED', onTap: () => {
            this.ctrl.cycleSource();
          } })
      }
      if (this.ctrl.sourceKind === 'SIMULATED') {
        ArcListItem() {
          SimSetting({ label: 'Scenario', value: this.ctrl.scenarioLabel, onTap: () => {
            this.ctrl.cycleScenario();
          } })
        }
        ArcListItem() {
          SimSetting({ label: 'Speed', value: `${this.ctrl.demoSpeed}x`, onTap: () => {
            this.ctrl.cycleDemoSpeed();
          } })
        }
      }

      ArcListItem() {
        SimSection({ title: 'EVENTS' })
      }
      ArcListItem() {
        SimEvent({ icon: $r('app.media.ic_zap'), label: 'Fall', onTap: () => {
          this.ctrl.simulateFall();
        } })
      }
      ArcListItem() {
        SimEvent({ icon: $r('app.media.ic_rhythm'), label: 'Irregular rhythm', active: this.ctrl.anomaly === 'rhythm',
          onTap: () => {
            this.ctrl.triggerAnomaly('rhythm');
          } })
      }
      ArcListItem() {
        SimEvent({ icon: $r('app.media.ic_hrv'), label: 'Low HRV', active: this.ctrl.anomaly === 'hrv', onTap: () => {
          this.ctrl.triggerAnomaly('hrv');
        } })
      }
      ArcListItem() {
        SimEvent({ icon: $r('app.media.ic_spo2'), label: 'Low oxygen', active: this.ctrl.anomaly === 'spo2',
          onTap: () => {
            this.ctrl.triggerAnomaly('spo2');
          } })
      }
      ArcListItem() {
        SimEvent({ icon: $r('app.media.ic_watch'), label: this.ctrl.onWrist ? 'Take watch off' : 'Put watch on',
          active: !this.ctrl.onWrist, onTap: () => {
            this.ctrl.toggleWorn();
          } })
      }

      ArcListItem() {
        SimSection({ title: 'CONTEXT' })
      }
      ArcListItem() {
        SimSetting({ label: 'State', value: this.stateValue(), on: this.ctrl.activityOverride !== 'AUTO',
          onTap: () => {
            this.ctrl.cycleActivityOverride();
          } })
      }
      ArcListItem() {
        SimSetting({ label: 'Genotype', value: this.ctrl.genotype === 'UNKNOWN' ? 'None' : this.ctrl.genotype,
          onTap: () => {
            this.ctrl.cycleGenotype();
          } })
      }
      ArcListItem() {
        SimSetting({ label: 'Risky drug', value: this.ctrl.riskyDrug.length > 0 ? 'On' : 'Off',
          on: this.ctrl.riskyDrug.length > 0, onTap: () => {
            this.ctrl.toggleRiskyDrug();
          } })
      }
      ArcListItem() {
        SimSetting({ label: 'Beta-blocker', value: this.ctrl.betaBlockerMissed ? 'Missed' : 'Taken',
          on: this.ctrl.betaBlockerMissed, onTap: () => {
            this.ctrl.toggleMissedBetaBlocker().then((ok: boolean) => {
              if (!ok) {
                this.toast('Server not ready (see log)');
              }
            });
          } })
      }
      ArcListItem() {
        SimEvent({ icon: $r('app.media.ic_pill'), label: 'Dose nudge', onTap: () => {
          this.ctrl.showDoseNudgeNow();
        } })
      }
      ArcListItem() {
        SimEvent({ icon: $r('app.media.ic_bell'), label: 'Reminder in 10 s', onTap: () => {
          this.ctrl.testMedicationReminder().then((ok: boolean) => {
            this.toast(ok ? 'Reminder set. You can close the app.' : 'Reminder failed');
          });
        } })
      }
      ArcListItem() {
        Column().height(48)
      }
    }
    .space(LengthMetrics.vp(6))
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
  }
}
