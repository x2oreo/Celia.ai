import { WatchController } from '../controller/WatchController';
import { Theme } from './Theme';

@ComponentV2
struct SimButton {
  @Param @Require label: string;
  @Param highlight: boolean = false;
  @Event onTap: () => void = () => {};

  build() {
    Button(this.label)
      .fontSize(12)
      .width(150)
      .height(32)
      .backgroundColor(this.highlight ? Theme.WARN : Theme.CARD)
      .fontColor(this.highlight ? '#000000' : Theme.TEXT)
      .onClick(() => this.onTap())
  }
}

/**
 * Demo controls for things the emulator can't produce: a fall, watch on/off, rest/active/asleep, genotype and a
 * recently scanned risky drug (normally from the phone app via watch_context).
 */
@ComponentV2
export struct SimulatePage {
  @Param @Require ctrl: WatchController;

  activityLabel(): string {
    switch (this.ctrl.activityOverride) {
      case 'REST':
        return 'State: rest';
      case 'ACTIVE':
        return 'State: active';
      case 'ASLEEP':
        return 'State: asleep';
      default:
        return 'State: auto';
    }
  }

  build() {
    // Vertical list (crown / swipe up-down): the round screen can't fit every demo control at once.
    Scroll() {
      Column({ space: 5 }) {
        Text('Simulate').fontSize(11).fontColor(Theme.MUTED)
        SimButton({ label: 'Fall', highlight: true, onTap: () => {
          this.ctrl.simulateFall();
        } })
        SimButton({ label: this.ctrl.onWrist ? 'Take watch off' : 'Put watch on', onTap: () => {
          this.ctrl.toggleWorn();
        } })
        SimButton({ label: this.activityLabel(), onTap: () => {
          this.ctrl.cycleActivityOverride();
        } })
        SimButton({ label: `Genotype: ${this.ctrl.genotype === 'UNKNOWN' ? '—' : this.ctrl.genotype}`, onTap: () => {
          this.ctrl.cycleGenotype();
        } })
        SimButton({ label: this.ctrl.riskyDrug.length > 0 ? 'Risky drug: on' : 'Risky drug: off', onTap: () => {
          this.ctrl.toggleRiskyDrug();
        } })
        SimButton({ label: 'Med reminder in 10 s', onTap: () => {
          this.ctrl.testMedicationReminder().then((ok: boolean) => {
            try {
              this.getUIContext().getPromptAction().showToast({
                message: ok ? 'Reminder set. You can close the app.' : 'Reminder failed', duration: 1500 });
            } catch (e) {
              // Toast is cosmetic.
            }
          });
        } })
      }
      .width('100%')
      .padding({ top: 56, bottom: 64 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}
