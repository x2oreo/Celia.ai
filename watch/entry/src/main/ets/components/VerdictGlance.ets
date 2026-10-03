import { WatchController } from '../controller/WatchController';
import { Pill } from './Pill';
import { Theme } from './Theme';

/** W6: a QT-risk drug was just scanned on the phone. Deterministic verdict from the drug list, never from the LLM. */
@ComponentV2
export struct VerdictGlance {
  @Param @Require ctrl: WatchController;

  riskLabel(): string {
    switch (this.ctrl.riskyDrugRisk) {
      case 'POSSIBLE_RISK':
        return 'Possible risk';
      case 'CONDITIONAL_RISK':
        return 'Conditional risk';
      default:
        return 'Known risk';
    }
  }

  build() {
    Column({ space: 4 }) {
      Stack() {
        Polygon({ width: 36, height: 36 })
          .points([[11, 0], [25, 0], [36, 11], [36, 25], [25, 36], [11, 36], [0, 25], [0, 11]])
          .fill(Theme.DANGER)
        Text('×').fontSize(26).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
      }
      .margin({ bottom: 4 })
      Text(this.ctrl.verdictDrug).fontSize(18).fontWeight(FontWeight.Bolder).fontColor(Theme.TEXT).maxLines(1)
      Text(this.riskLabel()).fontSize(13).fontWeight(FontWeight.Bold).fontColor(Theme.DANGER)
      Text('Ask your doctor.').fontSize(12).fontColor(Theme.TEXT).margin({ bottom: 6 })
      Pill({ label: 'Got it', pillWidth: 100, onTap: () => {
        this.ctrl.dismissVerdict();
      } })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Theme.BG)
  }
}
