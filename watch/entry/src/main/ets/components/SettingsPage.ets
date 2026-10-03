import { WatchController } from '../controller/WatchController';
import { Theme } from './Theme';

@ComponentV2
export struct SettingsPage {
  @Param @Require ctrl: WatchController;

  sourceName(): string {
    if (this.ctrl.sourceKind === 'SENSOR') {
      return 'Watch sensor';
    }
    if (this.ctrl.sourceKind === 'BRIDGE') {
      return 'GT 6 Pro (Mac)';
    }
    return 'Demo data';
  }

  @Builder
  row(label: string, value: string, action: () => void) {
    Column({ space: 2 }) {
      Text(label).fontSize(12).fontColor(Theme.MUTED)
      Text(value).fontSize(16).fontColor(Theme.TEXT).maxLines(1)
    }
    .width(220)
    .padding({ top: 8, bottom: 8 })
    .borderRadius(20)
    .backgroundColor(Theme.CARD)
    .onClick(action)
  }

  build() {
    Column({ space: 8 }) {
      this.row('Source (tap to change)', this.sourceName(), () => {
        this.ctrl.cycleSource();
      })
      if (this.ctrl.sourceKind === 'SIMULATED') {
        this.row('Scenario (tap to change)', this.ctrl.scenarioLabel, () => {
          this.ctrl.cycleScenario();
        })
      }
      Text(`Alert below ${this.ctrl.lowBpm} / above ${this.ctrl.highBpm} bpm`)
        .fontSize(12)
        .fontColor(Theme.MUTED)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
