// Verdict card (DESIGN.md §6.4; F-07, F-19..F-21). Anatomy: risk header band (shape + word + subtitle),
// name → ingredient, reason, actions (ink + secondary, never coral), quiet source line. The sheet size adds the
// interaction with my meds, alternatives and the "How we know" trace. Colour always comes from the
// deterministic verdict, never from model output.

import { ComboVerdict, DrugVerdict, LookupStep, RiskLevel } from '../model/DrugVerdict';
import { Genotype } from '../model/Profile';
import { RiskUi } from '../common/RiskUi';
import { copyText } from '../common/Clipboard';
import { InkButton, resText, RiskShape, SecondaryButton } from './Common';
import { Motion } from '../common/Motion';
import { toast } from '../common/Toast';

// The medicines I already take that the checked one interacts with, each once.
export function interactingDrugs(combos: ComboVerdict[]): string[] {
  const out: string[] = [];
  for (const c of combos) {
    for (const d of c.drugs.slice(1)) {
      if (!out.includes(d)) {
        out.push(d);
      }
    }
  }
  return out;
}

export function doctorQuestion(v: DrugVerdict, genotype: Genotype, combos: ComboVerdict[]): string {
  const gt: string = genotype === 'UNKNOWN' ? '' : ` (${genotype})`;
  const name: string = v.ingredient === '' ? v.query : `${v.query} (${v.ingredient})`;
  let q: string = `I have long QT syndrome${gt}. I was offered ${name}, which is listed as ${RiskUi.plain(v.risk)}. `;
  const others: string[] = interactingDrugs(combos);
  if (others.length > 0) {
    q += `It may also interact with ${others.join(', ')} that I already take. `;
  }
  const alts: string[] = v.alternatives ?? [];
  if (alts.length > 0) {
    q += `Could ${alts.join(' or ')} be a safer option for me? `;
  } else {
    q += 'Is there a safer option, or what precautions (ECG, potassium, magnesium) should we take? ';
  }
  return q.trim();
}

export type VerdictSize = 'INLINE' | 'SHEET';

@ComponentV2
export struct VerdictCard {
  @Param verdict: DrugVerdict | undefined = undefined;
  @Param combo: ComboVerdict | undefined = undefined;
  // Every interaction with my medicines, and the risk after the interaction rules. Both deterministic
  // (CheckService). Without them the card shows the medicine on its own.
  @Param combos: ComboVerdict[] = [];
  @Param combinedRisk: RiskLevel | undefined = undefined;
  @Param genotype: Genotype = 'UNKNOWN';
  @Param variant: VerdictSize = 'SHEET';
  // Second action ("Add to meds", "Open check"). Hidden when empty.
  @Param actionLabel: ResourceStr = '';
  @Event onAction: () => void = () => {
  };
  @Local showTrace: boolean = false;
  @Local shown: boolean = false;

  private async copyQuestion(v: DrugVerdict): Promise<void> {
    const ok: boolean = await copyText(doctorQuestion(v, this.genotype, this.allCombos()));
    toast(this.getUIContext(), ok ? $r('app.string.verdict_copied') : $r('app.string.error_generic'));
  }

  private allCombos(): ComboVerdict[] {
    if (this.combos.length > 0) {
      return this.combos;
    }
    return this.combo !== undefined && this.combo.kind !== 'NONE' ? [this.combo] : [];
  }

  // The risk the header shows: the medicine's own category, raised when it interacts with my medicines.
  private headline(v: DrugVerdict): RiskLevel {
    return this.combinedRisk ?? v.risk;
  }

  private title(v: DrugVerdict): string {
    const name: string = v.query.length > 0 ? v.query.charAt(0).toUpperCase() + v.query.slice(1) : v.query;
    if (v.ingredient === '' || v.query.toLowerCase() === v.ingredient.toLowerCase()) {
      return name;
    }
    return `${name} → ${v.ingredient}`;
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
        .fontColor($r('app.color.ink_3'))
        .layoutWeight(1)
    }
    .width('100%')
    .accessibilityGroup(true)
  }

  @Builder
  header(v: DrugVerdict) {
    Row({ space: 10 }) {
      RiskShape({ risk: this.headline(v), dim: this.variant === 'SHEET' ? 40 : 32 })
        .accessibilityLevel('no-hide-descendants')   // the word is the next text
      Column({ space: 1 }) {
        Text(RiskUi.label(this.headline(v)))
          .fontSize(this.variant === 'SHEET' ? $r('app.float.font_title_3') : $r('app.float.font_body'))
          .fontWeight(800)
          .fontColor(RiskUi.text(this.headline(v)))
        Text(this.headline(v) !== v.risk ? $r('app.string.verdict_sub_with_meds') : RiskUi.subtitle(v.risk))
          .fontSize(this.variant === 'SHEET' ? $r('app.float.font_small') : $r('app.float.font_caption'))
          .fontColor(this.headline(v) === 'KNOWN_RISK' ? $r('app.color.risk_known_subtitle') :
            RiskUi.text(this.headline(v)))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor(RiskUi.tint(this.headline(v)))
    .borderRadius(this.variant === 'SHEET' ? $r('app.float.radius_m') : 0)
    // Announced by its word and subtitle ("Known risk, Can affect heart rhythm"), never by colour.
    .accessibilityGroup(true)
  }

  @Builder
  extras(v: DrugVerdict) {
    // Interactions with my medicines, one row each
    ForEach(this.allCombos(), (c: ComboVerdict) => {
      Row({ space: 10 }) {
        RiskShape({ risk: 'POSSIBLE_RISK', dim: 20 })
          .accessibilityLevel('no-hide-descendants')
        Column({ space: 4 }) {
          Text(c.kind === 'CYP_INTERACTION' ? $r('app.string.combo_cyp_title') :
            $r('app.string.combo_additive_title'))
            .fontSize($r('app.float.font_small'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.risk_possible_text'))
          Text(c.reason)
            .fontSize($r('app.float.font_small'))
            .fontColor($r('app.color.ink_2'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .alignItems(VerticalAlign.Top)
      .width('100%')
      .padding(12)
      .backgroundColor($r('app.color.risk_possible_tint'))
      .borderRadius($r('app.float.radius_s'))
      .accessibilityGroup(true)
    }, (c: ComboVerdict) => c.drugs.join('+') + c.kind)

    if ((v.alternatives ?? []).length > 0) {
      Column({ space: 4 }) {
        Text($r('app.string.verdict_alternatives'))
          .fontSize($r('app.float.font_caption'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink_3'))
        Text((v.alternatives ?? []).join(' · '))
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink'))
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .accessibilityGroup(true)
    }

    if (this.headline(v) !== 'NOT_LISTED') {
      Text($r('app.string.verdict_dont_stop'))
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.ink_3'))
    }
  }

  @Builder
  trace(v: DrugVerdict) {
    Column({ space: 8 }) {
      Row() {
        Text($r('app.string.verdict_how_we_know'))
          .fontSize($r('app.float.font_small'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ink_2'))
          .layoutWeight(1)
        Text(v.confidence === undefined ? '' : `${Math.round((v.confidence ?? 0) * 100)}%`)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.ink_3'))
        Image($r('app.media.ic_chevron_right'))
          .width(16)
          .height(16)
          .fillColor($r('app.color.ink_4'))
          .rotate({ angle: this.showTrace ? 90 : 0 })
          .animation({ duration: 180, curve: Curve.EaseOut })
      }
      .width('100%')
      .height($r('app.float.chip_height'))
      .accessibilityGroup(true)
      .accessibilityDescription(resText(this.getUIContext(), this.showTrace ? $r('app.string.a11y_trace_expanded') :
        $r('app.string.a11y_trace_collapsed')))
      .onClick(() => {
        this.showTrace = !this.showTrace;
      })

      if (this.showTrace) {
        Column({ space: 6 }) {
          ForEach(v.trace ?? [], (step: LookupStep) => {
            this.traceRow(step)
          }, (step: LookupStep, i: number) => `${i}-${step.token}`)
          Text(v.source)
            .fontSize($r('app.float.font_micro'))
            .fontColor($r('app.color.ink_4'))
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .transition(TransitionEffect.OPACITY.animation({ duration: 150 }))
      }
    }
    .width('100%')
    .border({ width: { top: 1 }, color: $r('app.color.divider') })
  }

  @Builder
  actions(v: DrugVerdict) {
    Row({ space: 8 }) {
      // Not listed: adding it is the natural next step. Otherwise the doctor question comes first.
      if (this.headline(v) === 'NOT_LISTED' && this.actionLabel !== '') {
        InkButton({ label: this.actionLabel, large: this.variant === 'SHEET', onTap: () => this.onAction() })
          .layoutWeight(1)
        SecondaryButton({
          label: $r('app.string.verdict_ask_doctor_short'),
          large: this.variant === 'SHEET',
          fill: false,
          onTap: () => {
            this.copyQuestion(v);
          }
        })
      } else {
        InkButton({
          label: this.variant === 'SHEET' ? $r('app.string.verdict_ask_doctor') :
            $r('app.string.verdict_ask_doctor_short'),
          large: this.variant === 'SHEET',
          onTap: () => {
            this.copyQuestion(v);
          }
        })
          .layoutWeight(1)
        if (this.actionLabel !== '') {
          SecondaryButton({
            label: this.actionLabel,
            large: this.variant === 'SHEET',
            fill: false,
            onTap: () => this.onAction()
          })
        }
      }
    }
    .width('100%')
    .margin({ top: 6 })
  }

  build() {
    if (this.verdict !== undefined) {
      Column() {
        this.header(this.verdict)
        Column({ space: this.variant === 'SHEET' ? 10 : 6 }) {
          Text(this.title(this.verdict))
            .fontSize(this.variant === 'SHEET' ? $r('app.float.font_title_3') : $r('app.float.font_headline'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.verdict.reason)
            .fontSize(this.variant === 'SHEET' ? $r('app.float.font_body') : $r('app.float.font_small'))
            .fontColor($r('app.color.ink_2'))
            .lineHeight(this.variant === 'SHEET' ? 23 : 20)
          if (this.variant === 'SHEET') {
            this.extras(this.verdict)
          }
          this.actions(this.verdict)
          if (this.variant === 'SHEET') {
            this.trace(this.verdict)
          }
          Text(this.variant === 'SHEET' ? $r('app.string.verdict_source') : $r('app.string.verdict_source_short'))
            .fontSize($r('app.float.font_micro'))
            .fontColor($r('app.color.ink_4'))
            .textAlign(this.variant === 'SHEET' ? TextAlign.Center : TextAlign.Start)
            .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(this.variant === 'SHEET' ? { top: 14 } : { left: 14, right: 14, top: 12, bottom: 12 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(this.variant === 'SHEET' ? Color.Transparent : $r('app.color.surface'))
      .borderRadius(this.variant === 'SHEET' ? 0 : $r('app.float.radius_ml'))
      .border({ width: this.variant === 'SHEET' ? 0 : 1.5, color: RiskUi.border(this.headline(this.verdict)) })
      .clip(this.variant !== 'SHEET')
      // Verdict reveal: slide up 12 vp and fade in. No bounce, even for Known risk.
      .opacity(this.shown ? 1 : 0)
      .translate({ y: this.shown ? 0 : 12 })
      .animation(Motion.reduced ? undefined : { duration: Motion.REVEAL_MS, curve: Curve.EaseOut })
      .onAppear(() => {
        this.shown = true;
      })
    }
  }
}
