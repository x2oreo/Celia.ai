import { WatchController } from '../controller/WatchController';
import { shortDrugName } from '../vitals/DrugBadge';
import { Icon, PillButton } from './Parts';
import { Theme } from './Theme';

/**
 * 14 Risky medicine verdict, pushed from the phone after a check. Shape + colour + word, the same as the phone
 * (DESIGN.md §3); the level comes from the deterministic drug list, never from the LLM.
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

  solid(): string {
    switch (this.ctrl.riskyDrugRisk) {
      case 'POSSIBLE_RISK':
        return Theme.RISK_POSSIBLE;
      case 'CONDITIONAL_RISK':
        return Theme.RISK_CONDITIONAL;
      default:
        return Theme.RISK_KNOWN;
    }
  }

  wordColor(): string {
    switch (this.ctrl.riskyDrugRisk) {
      case 'POSSIBLE_RISK':
        return Theme.RISK_POSSIBLE_TEXT;
      case 'CONDITIONAL_RISK':
        return Theme.RISK_CONDITIONAL_TEXT;
      default:
        return Theme.RISK_KNOWN_TEXT;
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
    Column({ space: 2 }) {
      Icon({ src: this.shape(), color: this.solid(), glyph: 40 })
      Text(shortDrugName(this.ctrl.verdictDrug))
        .fontSize(Theme.TITLE + 3)
        .fontWeight(FontWeight.Bolder)
        .fontColor(Theme.TEXT)
        .maxLines(1)
        .margin({ top: 6 })
      Text(this.label()).fontSize(Theme.BODY + 1).fontWeight(FontWeight.Bolder).fontColor(this.wordColor())
      Text('Ask your doctor before you take it.')
        .fontSize(Theme.BODY)
        .fontWeight(FontWeight.Regular)
        .fontColor(Theme.TEXT)
        .textAlign(TextAlign.Center)
        .width(170)
        .margin({ top: 4 })
      Text('Your watch now watches more closely.')
        .fontSize(Theme.SMALL)
        .fontColor(Theme.TEXT_2)
        .textAlign(TextAlign.Center)
        .width(150)
        .margin({ top: 2, bottom: 8 })
      PillButton({ label: 'Got it', pillWidth: 90, onTap: () => {
        this.ctrl.dismissVerdict();
      } })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Theme.BG)
  }
}
