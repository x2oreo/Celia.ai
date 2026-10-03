// Verdict card (F-07, F-19..F-21): risk badge, ingredient, reason, interaction with my meds, alternatives,
// "How we know" trace and an "Ask your doctor" question to copy. Used by the check result, history and Home.

import { ComboVerdict, DrugVerdict, LookupStep } from '../model/DrugVerdict';
import { Genotype } from '../model/Profile';
import { RiskUi } from '../common/RiskUi';
import { copyText } from '../common/Clipboard';
import { RiskBadge, SecondaryButton } from './Common';
import { toast } from '../common/Toast';

export function doctorQuestion(v: DrugVerdict, genotype: Genotype, combo: ComboVerdict | undefined): string {
  const gt: string = genotype === 'UNKNOWN' ? '' : ` (${genotype})`;
  const name: string = v.ingredient === '' ? v.query : `${v.query} (${v.ingredient})`;
  let q: string = `I have long QT syndrome${gt}. I was offered ${name}, which is listed as ${RiskUi.plain(v.risk)}. `;
  if (combo !== undefined && combo.kind !== 'NONE') {
    q += `It may also interact with ${combo.drugs.slice(1).join(', ')} that I already take. `;
  }
  const alts: string[] = v.alternatives ?? [];
  if (alts.length > 0) {
    q += `Could ${alts.join(' or ')} be a safer option for me? `;
  } else {
    q += 'Is there a safer option, or what precautions (ECG, potassium, magnesium) should we take? ';
  }
  return q.trim();
}

@ComponentV2
export struct VerdictCard {
  @Param verdict: DrugVerdict | undefined = undefined;
  @Param combo: ComboVerdict | undefined = undefined;
  @Param genotype: Genotype = 'UNKNOWN';
  @Local showTrace: boolean = false;

  private async copyQuestion(v: DrugVerdict): Promise<void> {
    const ok: boolean = await copyText(doctorQuestion(v, this.genotype, this.combo));
    toast(this.getUIContext(), ok ? $r('app.string.verdict_copied') : $r('app.string.error_generic'));
  }

  @Builder
  traceRow(step: LookupStep) {
    Row({ space: 8 }) {
      Circle()
        .width(6)
        .height(6)
        .fill(step.kind === 'NOT_FOUND' ? $r('app.color.risk_unknown') : $r('app.color.risk_not_listed'))
      Text(step.detail)
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('sys.color.font_secondary'))
        .layoutWeight(1)
    }
    .width('100%')
  }

  build() {
    if (this.verdict !== undefined) {
      Column({ space: 14 }) {
        // Header: badge + ingredient
        Column({ space: 10 }) {
          RiskBadge({ risk: this.verdict.risk })
          Text(this.verdict.ingredient === '' ? this.verdict.query : this.verdict.ingredient)
            .fontSize($r('app.float.font_title'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.verdict.ingredient !== '' && this.verdict.query.toLowerCase() !== this.verdict.ingredient) {
            Text(this.verdict.query)
              .fontSize($r('app.float.font_small'))
              .fontColor($r('sys.color.font_secondary'))
          }
          Text(this.verdict.reason)
            .fontSize($r('app.float.font_body'))
            .fontColor($r('sys.color.font_primary'))
            .lineHeight(22)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        // Interaction with my medicines
        if (this.combo !== undefined && this.combo.kind !== 'NONE') {
          Row({ space: 10 }) {
            Image($r('app.media.ic_risk_possible')).width(20).height(20).fillColor($r('app.color.risk_known'))
            Column({ space: 4 }) {
              Text(this.combo.kind === 'CYP_INTERACTION' ? $r('app.string.combo_cyp_title') :
                $r('app.string.combo_additive_title'))
                .fontSize($r('app.float.font_small'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.risk_known'))
              Text(this.combo.reason)
                .fontSize($r('app.float.font_small'))
                .fontColor($r('sys.color.font_primary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .alignItems(VerticalAlign.Top)
          .width('100%')
          .padding(12)
          .backgroundColor($r('app.color.risk_known_soft'))
          .borderRadius($r('app.float.radius_s'))
        }

        // Alternatives
        if ((this.verdict.alternatives ?? []).length > 0) {
          Column({ space: 6 }) {
            Text($r('app.string.verdict_alternatives'))
              .fontSize($r('app.float.font_small'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_secondary'))
            Text((this.verdict.alternatives ?? []).join(' · '))
              .fontSize($r('app.float.font_body'))
              .fontColor($r('sys.color.font_primary'))
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
        }

        if (this.verdict.risk !== 'NOT_LISTED') {
          Text($r('app.string.verdict_dont_stop'))
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('sys.color.font_secondary'))
        }

        // How we know
        Column({ space: 8 }) {
          Row() {
            Text($r('app.string.verdict_how_we_know'))
              .fontSize($r('app.float.font_small'))
              .fontColor($r('app.color.brand_accent'))
              .layoutWeight(1)
            Text(this.verdict.confidence === undefined ? '' :
              `${Math.round((this.verdict.confidence ?? 0) * 100)}%`)
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('sys.color.font_secondary'))
            Image($r('app.media.ic_chevron_right'))
              .width(16)
              .height(16)
              .fillColor($r('sys.color.icon_secondary'))
              .rotate({ angle: this.showTrace ? 90 : 0 })
              .animation({ duration: 180, curve: Curve.EaseOut })
          }
          .width('100%')
          .onClick(() => {
            this.showTrace = !this.showTrace;
          })
          if (this.showTrace) {
            Column({ space: 6 }) {
              ForEach(this.verdict.trace ?? [], (step: LookupStep) => {
                this.traceRow(step)
              }, (step: LookupStep, i: number) => `${i}-${step.token}`)
              Text(this.verdict.source)
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('sys.color.font_tertiary'))
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .transition(TransitionEffect.OPACITY.animation({ duration: 150 }))
          }
        }
        .width('100%')
        .padding({ top: 10 })
        .border({ width: { top: 1 }, color: $r('app.color.divider') })

        if (this.verdict.risk !== 'NOT_LISTED') {
          SecondaryButton({
            label: $r('app.string.verdict_ask_doctor'),
            icon: $r('app.media.ic_doctor'),
            onTap: () => {
              if (this.verdict !== undefined) {
                this.copyQuestion(this.verdict);
              }
            }
          })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(20)
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius($r('app.float.radius_l'))
      .border({ width: { top: 6 }, color: RiskUi.color(this.verdict.risk) })
    }
  }
}
