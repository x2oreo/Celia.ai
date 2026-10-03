import { WatchController } from '../controller/WatchController';
import { Theme } from './Theme';

/** "Are you OK?" countdown after a hard fall. No answer → fall_detected(no_response) → phone emergency flow. */
@ComponentV2
export struct FallOverlay {
  @Param @Require ctrl: WatchController;

  build() {
    Column({ space: 6 }) {
      Text('Fall detected').fontSize(13).fontColor(Theme.TEXT).opacity(0.85)
      Text('Are you OK?').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
      Text(`${this.ctrl.fallCountdown}`).fontSize(40).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
      Button("I'm OK")
        .width(110)
        .height(38)
        .fontSize(16)
        .backgroundColor(Theme.TEXT)
        .fontColor(Theme.WARN)
        .onClick(() => {
          this.ctrl.confirmOk();
        })
      Text('No answer = alert your contacts').fontSize(10).fontColor(Theme.TEXT).opacity(0.85)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Theme.WARN)
  }
}
