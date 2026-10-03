import { WatchController } from '../controller/WatchController';
import { Theme } from './Theme';

@ComponentV2
struct SettingRow {
  @Param @Require label: string;
  @Param @Require value: string;
  @Event onTap: () => void = () => {};

  build() {
    Column({ space: 2 }) {
      Text(this.label).fontSize(10).fontColor(Theme.MUTED)
      Text(this.value).fontSize(13).fontColor(Theme.TEXT).maxLines(1)
    }
    .width(150)
    .padding({ top: 5, bottom: 5 })
    .borderRadius(16)
    .backgroundColor(Theme.CARD)
    .onClick(() => this.onTap())
  }
}

@ComponentV2
export struct SettingsPage {
  @Param @Require ctrl: WatchController;

  sourceName(): string {
    return this.ctrl.sourceKind === 'SENSOR' ? 'Watch sensor' : 'Demo data';
  }

  build() {
    Column({ space: 6 }) {
      SettingRow({
        label: 'Source (tap to change)',
        value: this.sourceName(),
        onTap: () => {
          this.ctrl.cycleSource();
        }
      })
      if (this.ctrl.sourceKind === 'SIMULATED') {
        SettingRow({
          label: 'Scenario (tap to change)',
          value: this.ctrl.scenarioLabel,
          onTap: () => {
            this.ctrl.cycleScenario();
          }
        })
      }
      Text(`Alert below ${this.ctrl.lowBpm} / above ${this.ctrl.highBpm} bpm`)
        .fontSize(10)
        .fontColor(Theme.MUTED)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
