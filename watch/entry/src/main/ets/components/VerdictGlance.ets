import { WatchController } from '../controller/WatchController';
import { shortDrugName } from '../vitals/DrugBadge';
import { EdgeButton, Icon } from './Parts';
import { Theme } from './Theme';

/**
 * W6: a QT-risk drug was just checked on the phone. The level, colour and shape come from the deterministic drug
 * list (DESIGN.md §3), never from the LLM.
 */
@ComponentV2
export struct VerdictGlance {
  @Param @Require ctrl: WatchController;

  label(): string {
    switch (this.ctrl.riskyDrugRisk) {
      case 'POSSIBLE_RISK':
        return 'Possible risk';
      case 'CONDITIONAL_RISK':
        return 'Conditional risk';
      default:
        return 'Known risk';
    }
  }

  color(): string {
    switch (this.ctrl.riskyDrugRisk) {
      case 'POSSIBLE_RISK':
        return Theme.RISK_POSSIBLE;
      case 'CONDITIONAL_RISK':
        return Theme.RISK_CONDITIONAL;
      default:
        return Theme.RISK_KNOWN;
    }
  }

  shape(): Resource {
    switch (this.ctrl.riskyDrugRisk) {
      case 'POSSIBLE_RISK':
        return $r('app.media.ic_risk_possible');
      case 'CONDITIONAL_RISK':
        return $r('app.media.ic_risk_conditional');
      default:
        return $r('app.media.ic_risk_known');
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column({ space: 3 }) {
        Icon({ src: this.shape(), color: this.color(), glyph: 40 })
        Text(shortDrugName(this.ctrl.verdictDrug))
          .fontSize(Theme.TITLE + 3)
          .fontWeight(FontWeight.Bolder)
          .fontColor(Theme.TEXT)
          .maxLines(1)
          .margin({ top: 4 })
        Text(this.label()).fontSize(Theme.BODY).fontWeight(FontWeight.Bold).fontColor(this.color())
        Text('Ask your doctor before you take it.')
          .fontSize(Theme.SMALL)
          .fontColor(Theme.TEXT_2)
          .textAlign(TextAlign.Center)
          .width(150)
        Text('Your watch now watches more closely.')
          .fontSize(Theme.MICRO)
          .fontColor(Theme.TEXT_3)
          .textAlign(TextAlign.Center)
          .width(150)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ bottom: 36 })
      .accessibilityGroup(true)
      .accessibilityText(`${this.ctrl.verdictDrug}: ${this.label()}. Ask your doctor before you take it.`)

      EdgeButton({ label: 'Got it', onTap: () => {
        this.ctrl.dismissVerdict();
      } })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
