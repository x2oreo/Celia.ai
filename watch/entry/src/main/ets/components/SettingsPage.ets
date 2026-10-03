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

  pairLabel(): string {
    switch (this.ctrl.pairState) {
      case 'PAIRED':
        return 'Paired with phone';
      case 'NOT_PAIRED':
        return 'Not paired';
      case 'ERROR':
        return 'Pairing unavailable';
      default:
        return 'Checking…';
    }
  }

  sourceName(): string {
    return this.ctrl.sourceKind === 'SENSOR' ? 'Watch sensor' : 'Demo data';
  }

  build() {
    Column({ space: 6 }) {
      SettingRow({
        label: this.ctrl.deviceIdOverridden ? `Watch ${this.ctrl.deviceId.slice(0, 8)} (from .env)` :
          `Watch ${this.ctrl.deviceId.slice(0, 8)}`,
        value: this.ctrl.pairState === 'PAIRED' ? 'Paired with phone ✓' : 'Pair with phone',
        onTap: () => {
          this.ctrl.startPairing().then((err: string) => {
            if (err.length > 0) {
              try {
                this.getUIContext().getPromptAction().showToast({ message: err, duration: 2000 });
              } catch (e) {
                // Toast is cosmetic.
              }
            }
          });
        }
      })
      if (this.ctrl.pairState !== 'PAIRED') {
        Text(this.pairLabel()).fontSize(10).fontColor(this.ctrl.pairState === 'ERROR' ? Theme.WARN : Theme.MUTED)
      }
      if (!this.ctrl.demoMode) {
        SettingRow({ label: 'Heart rate', value: 'Watch sensor' })
      } else {
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
          SettingRow({
            label: 'Demo speed',
            value: `${this.ctrl.demoSpeed}×`,
            onTap: () => {
              this.ctrl.cycleDemoSpeed();
            }
          })
        }
      }
      Text(`Now: ${this.ctrl.limitLow}–${this.ctrl.limitHigh} bpm (${this.ctrl.limitReason})`)
        .fontSize(10)
        .fontColor(Theme.MUTED)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
