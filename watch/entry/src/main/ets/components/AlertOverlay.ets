import { WatchController } from '../controller/WatchController';
import { Theme } from './Theme';

@ComponentV2
export struct AlertOverlay {
  @Param @Require ctrl: WatchController;

  build() {
    Column({ space: 6 }) {
      Text('!').fontSize(28).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
      Text(this.ctrl.alertText)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT)
        .textAlign(TextAlign.Center)
        .width(160)
      Text('Stop and rest. If you feel faint, call for help.')
        .fontSize(11)
        .fontColor(Theme.TEXT)
        .opacity(0.85)
        .textAlign(TextAlign.Center)
        .width(150)
      Button('OK')
        .width(72)
        .height(30)
        .backgroundColor(Theme.TEXT)
        .fontColor(Theme.DANGER)
        .onClick(() => {
          this.ctrl.dismissAlert();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Theme.DANGER)
  }
}
