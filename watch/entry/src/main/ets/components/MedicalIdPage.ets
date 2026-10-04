import { WatchController } from '../controller/WatchController';
import { shortDrugName } from '../vitals/DrugBadge';
import { Caps } from './Parts';
import { Theme } from './Theme';

/**
 * Medical ID for a bystander or paramedic: one swipe from Home, readable without the phone. Only what the watch
 * already knows (condition, genotype, a QT-risk drug taken in the last 72 h). Names and phone numbers stay on the
 * phone; the watch never dials by itself.
 */
@ComponentV2
export struct MedicalIdPage {
  @Param @Require ctrl: WatchController;

  riskWord(): string {
    switch (this.ctrl.riskyDrugRisk) {
      case 'POSSIBLE_RISK':
        return 'possible QT risk';
      case 'CONDITIONAL_RISK':
        return 'conditional QT risk';
      default:
        return 'known QT risk';
    }
  }

  build() {
    Column({ space: 3 }) {
      Caps({ text: 'MEDICAL ID', color: Theme.RISK_KNOWN_TEXT })
      Text('Long QT syndrome')
        .fontSize(Theme.TITLE)
        .fontWeight(FontWeight.Bolder)
        .fontColor(Theme.TEXT)
      if (this.ctrl.genotype !== 'UNKNOWN') {
        Text(`Type ${this.ctrl.genotype}`).fontSize(Theme.SMALL).fontColor(Theme.TEXT_2)
      }
      Text('Avoid QT-prolonging drugs')
        .fontSize(Theme.SMALL)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)
        .margin({ top: 4 })
      if (this.ctrl.riskyDrug.length > 0) {
        Text(`Took ${shortDrugName(this.ctrl.riskyDrug)} (${this.riskWord()})`)
          .fontSize(Theme.CAPS)
          .fontColor(Theme.ELEVATED)
          .textAlign(TextAlign.Center)
          .maxLines(2)
          .width(170)
      }
      Text('Call 112')
        .fontSize(Theme.TITLE + 3)
        .fontWeight(FontWeight.Bolder)
        .fontColor(Theme.TEXT)
        .padding({ left: 16, right: 16, top: 4, bottom: 4 })
        .borderRadius(16)
        .backgroundColor(Theme.ALERT)
        .margin({ top: 6 })
      Text(this.ctrl.pairState === 'PAIRED' ? 'Emergency contacts: on my phone' : 'Unlock my phone for contacts')
        .fontSize(Theme.CAPS)
        .fontColor(Theme.TEXT_2)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .width(130)
        .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Theme.BG)
  }
}
