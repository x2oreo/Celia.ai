import { WatchController } from '../controller/WatchController';
import { Theme } from './Theme';

@ComponentV2
export struct EmergencyOverlay {
  @Param @Require ctrl: WatchController;

  build() {
    Column({ space: 6 }) {
      Text('SOS').fontSize(28).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
      Text(this.ctrl.emergencyText)
        .fontSize(13)
        .fontColor(Theme.TEXT)
        .textAlign(TextAlign.Center)
        .width(160)
      Text('I have Long QT syndrome. Call 112.')
        .fontSize(11)
        .fontColor(Theme.TEXT)
        .opacity(0.9)
        .textAlign(TextAlign.Center)
        .width(150)
      Button('Dismiss')
        .width(90)
        .height(30)
        .backgroundColor(Theme.TEXT)
        .fontColor(Theme.DANGER)
        .onClick(() => {
          this.ctrl.dismissEmergency();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Theme.DANGER)
  }
}
