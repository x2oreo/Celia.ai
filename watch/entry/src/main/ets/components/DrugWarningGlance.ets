import { WatchController } from '../controller/WatchController';
import { Pill } from './Pill';
import { Theme } from './Theme';

/**
 * A symptom answered within 24 h of a QT-risk drug the user took: a stronger warning than "logged for your doctor".
 * Fixed text from a deterministic rule (DrugBadge.symptomAfterDrugTitle), never from the LLM.
 */
@ComponentV2
export struct DrugWarningGlance {
  @Param @Require ctrl: WatchController;

  build() {
    Column({ space: 4 }) {
      Stack() {
        Polygon({ width: 32, height: 32 })
          .points([[10, 0], [22, 0], [32, 10], [32, 22], [22, 32], [10, 32], [0, 22], [0, 10]])
          .fill(Theme.DANGER)
        Text('!').fontSize(22).fontWeight(FontWeight.Bolder).fontColor(Theme.TEXT)
      }
      .margin({ bottom: 2 })
      Text(this.ctrl.drugWarning)
        .fontSize(15)
        .fontWeight(FontWeight.Bolder)
        .fontColor(Theme.TEXT)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .width(170)
      Text("Don't take the next dose.\nCall your doctor today.")
        .fontSize(12)
        .fontColor(Theme.TEXT)
        .textAlign(TextAlign.Center)
      Text('If you faint, call 112.')
        .fontSize(11)
        .fontColor(Theme.DANGER)
        .margin({ bottom: 4 })
      Row({ space: 8 }) {
        Pill({ label: 'OK', pillWidth: 70, pillHeight: 30, fontSize: 12, onTap: () => {
          this.ctrl.dismissDrugWarning();
        } })
        Pill({ label: 'Need help', bg: Theme.DANGER, pillWidth: 82, pillHeight: 30, fontSize: 12, onTap: () => {
          this.ctrl.dismissDrugWarning();
          this.ctrl.needHelp();
        } })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Theme.BG)
  }
}
