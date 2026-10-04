import { WatchController } from '../controller/WatchController';
import { Icon, PillButton } from './Parts';
import { Theme } from './Theme';

/**
 * A symptom answered within 24 h of a QT-risk drug the user took: a stronger warning than "logged for your doctor".
 * Fixed text from a deterministic rule (DrugBadge.symptomAfterDrugTitle), never from the LLM.
 */
@ComponentV2
export struct DrugWarningGlance {
  @Param @Require ctrl: WatchController;

  build() {
    Column({ space: 2 }) {
      Icon({ src: $r('app.media.ic_risk_known'), color: Theme.RISK_KNOWN, glyph: 30 })
      Text(this.ctrl.drugWarning)
        .fontSize(Theme.TITLE)
        .fontWeight(FontWeight.Bolder)
        .fontColor(Theme.TEXT)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .width(170)
        .margin({ top: 4 })
      Text("Don't take the next dose.\nCall your doctor today.")
        .fontSize(Theme.SMALL)
        .fontColor(Theme.TEXT)
        .textAlign(TextAlign.Center)
      Text('If you faint, call 112.')
        .fontSize(Theme.SMALL)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.RISK_KNOWN_TEXT)
        .margin({ bottom: 6 })
      Row({ space: 8 }) {
        PillButton({ label: 'OK', pillWidth: 72, onTap: () => {
          this.ctrl.dismissDrugWarning();
        } })
        PillButton({ label: 'Need help', bg: Theme.ALERT, pillWidth: 94, onTap: () => {
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
