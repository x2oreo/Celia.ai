import { WatchController } from '../controller/WatchController';
import { Theme } from './Theme';

/**
 * Demo controls for things the emulator can't produce: a fall, putting the watch on/off, and forcing
 * rest/active. Everything recorded while simulating is still labelled with its real source.
 */
@ComponentV2
export struct SimulatePage {
  @Param @Require ctrl: WatchController;

  activityLabel(): string {
    switch (this.ctrl.activityOverride) {
      case 'REST':
        return 'Activity: rest';
      case 'ACTIVE':
        return 'Activity: active';
      default:
        return 'Activity: auto';
    }
  }

  build() {
    Column({ space: 6 }) {
      Text('Simulate').fontSize(13).fontColor(Theme.MUTED)
      Button('Fall')
        .fontSize(13)
        .width(140)
        .height(32)
        .backgroundColor(Theme.WARN)
        .fontColor('#000000')
        .onClick(() => {
          this.ctrl.simulateFall();
        })
      Button(this.ctrl.onWrist ? 'Take watch off' : 'Put watch on')
        .fontSize(13)
        .width(140)
        .height(32)
        .backgroundColor(Theme.CARD)
        .fontColor(Theme.TEXT)
        .onClick(() => {
          this.ctrl.toggleWorn();
        })
      Button(this.activityLabel())
        .fontSize(13)
        .width(140)
        .height(32)
        .backgroundColor(Theme.CARD)
        .fontColor(Theme.TEXT)
        .onClick(() => {
          this.ctrl.cycleActivityOverride();
        })
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: 10 })
    .justifyContent(FlexAlign.Center)
  }
}
