// Medicine detail sheet (DESIGN.md §6.9): what one of my medicines is, what it is for, how it works, everyday tips,
// how it sits with my other medicines, other names, and an optional AI explanation. The risk badge and the
// interaction rows come only from DrugDataset / DrugChecker (MedFacts); the AI block is labelled and never
// changes them.

import { LengthMetrics } from '@kit.ArkUI';
import { ComboVerdict } from '../model/DrugVerdict';
import { Medication } from '../model/Medication';
import { MedFacts, medFacts } from '../drugs/MedFacts';
import { MedAiInfo, MedAiOutcome, MedAiResult, MedInfoClient } from '../drugs/MedInfoClient';
import { Motion } from '../common/Motion';
import { IntakeCard } from './IntakeCard';
import { riskToLog } from '../drugs/DrugIntake';
import { InkButton, QuietButton, RiskBadge, RiskShape, SecondaryButton, SourceBadge, TypingDots } from './Common';

type AiState = 'IDLE' | 'LOADING' | MedAiResult;

@ComponentV2
export struct MedicineDetailSheet {
  @Param med: Medication | undefined = undefined;
  @Param meds: Medication[] = [];
  @Event onCheck: (m: Medication) => void = () => {
  };
  @Event onRemind: (m: Medication) => void = () => {
  };
  @Event onAsk: (m: Medication) => void = () => {
  };
  @Local facts: MedFacts = new MedFacts();
  @Local ai: MedAiInfo | undefined = undefined;
  @Local aiState: AiState = 'IDLE';

  aboutToAppear(): void {
    this.refresh();
  }

  @Monitor('med', 'meds')
  onMedChanged(): void {
    this.refresh();
  }

  private refresh(): void {
    const m: Medication | undefined = this.med;
    if (m === undefined) {
      return;
    }
    this.facts = medFacts(m, this.meds);
    this.ai = undefined;
    this.aiState = 'IDLE';
    MedInfoClient.cached(m.name, this.facts.ingredient).then((c: MedAiInfo | undefined) => {
      if (c !== undefined && this.med?.id === m.id) {
        this.ai = c;
        this.aiState = 'OK';
      }
    }).catch(() => {
      // No cache: the button stays.
    });
  }

  private async explain(): Promise<void> {
    const m: Medication | undefined = this.med;
    if (m === undefined || this.aiState === 'LOADING') {
      return;
    }
    this.aiState = 'LOADING';
    let out: MedAiOutcome;
    try {
      out = await MedInfoClient.explain(m.name, this.facts.ingredient);
    } catch (e) {
      out = new MedAiOutcome('FAILED', undefined);
    }
    if (this.med?.id !== m.id) {
      return;
    }
    this.ai = out.info;
    this.aiState = out.result;
  }

  private aiMessage(): Resource {
    if (this.aiState === 'NOT_RECOGNISED') {
      return $r('app.string.med_ai_unknown');
    }
    if (this.aiState === 'REJECTED') {
      return $r('app.string.med_ai_rejected');
    }
    return this.aiState === 'FAILED' ? $r('app.string.med_ai_failed') : $r('app.string.med_ai_offline');
  }

  // ── Pieces ─────────────────────────────────────────────────────────────────────────────────
  @Builder
  label(text: ResourceStr) {
    Text(text)
      .fontSize($r('app.float.font_badge'))
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.ink_3'))
      .letterSpacing(0.6)
      .textCase(TextCase.UpperCase)
  }

  @Builder
  tipRow(text: string, icon: Resource) {
    Row({ space: 12 }) {
      Row() {
        Image(icon).width(14).height(14).fillColor($r('app.color.ink_2'))
      }
      .width(28)
      .height(28)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.surface_alt'))
      .borderRadius(8)
      Text(text)
        .fontSize($r('app.float.font_small'))
        .fontColor($r('app.color.ink_2'))
        .lineHeight(20)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .accessibilityGroup(true)
  }

  @Builder
  header() {
    Row({ space: 14 }) {
      Row() {
        Image($r('app.media.ic_pill')).width(24).height(24).fillColor($r('app.color.brand_accent'))
      }
      .width(52)
      .height(52)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.brand_accent_soft'))
      .borderRadius($r('app.float.radius_m'))
      Column({ space: 4 }) {
        Text(this.facts.name)
          .fontSize($r('app.float.font_title'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.subline())
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink_3'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .accessibilityGroup(true)
  }

  private subline(): string {
    const parts: string[] = [];
    if (this.facts.ingredient !== '' && this.facts.ingredient !== this.facts.name.toLowerCase()) {
      parts.push(this.facts.ingredient);
    }
    if (this.facts.drugClass !== '') {
      parts.push(this.facts.drugClass);
    }
    if (this.facts.dose !== '') {
      parts.push(this.facts.dose);
    }
    return parts.join(' · ');
  }

  // Deterministic QT verdict, as a small verdict band (DESIGN.md §6.4 header band).
  @Builder
  riskBand() {
    Column({ space: 8 }) {
      RiskBadge({ risk: this.facts.risk })
      Text(this.facts.known ? this.facts.reason : $r('app.string.med_unknown_body'))
        .fontSize($r('app.float.font_small'))
        .fontColor($r('app.color.ink_2'))
        .lineHeight(20)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .border({
      width: 1.5,
      color: this.facts.risk === 'KNOWN_RISK' ? $r('app.color.risk_known_border') : $r('app.color.border'),
      style: this.facts.risk === 'UNKNOWN_DRUG' ? BorderStyle.Dashed : BorderStyle.Solid
    })
    .borderRadius($r('app.float.radius_ml'))
  }

  @Builder
  aboutCard() {
    Column({ space: 12 }) {
      this.label($r('app.string.med_about'))
      Text(this.facts.usedFor)
        .fontSize($r('app.float.font_headline'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .lineHeight(22)
      if (this.facts.howItWorks !== '') {
        Text(this.facts.howItWorks)
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink_3'))
          .lineHeight(20)
      }
      if (this.facts.tips.length > 0) {
        Divider().color($r('app.color.divider'))
        this.label($r('app.string.med_tips'))
        ForEach(this.facts.tips, (t: string) => {
          this.tipRow(t, $r('app.media.ic_check'))
        }, (t: string) => t)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_ml'))
  }

  @Builder
  interactionsCard() {
    Column({ space: 12 }) {
      this.label($r('app.string.med_with_mine'))
      if (this.facts.interactions.length === 0) {
        Text($r('app.string.med_no_interactions'))
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink_3'))
          .lineHeight(20)
      }
      ForEach(this.facts.interactions, (c: ComboVerdict, i: number) => {
        if (i > 0) {
          Divider().color($r('app.color.divider'))
        }
        Row({ space: 12 }) {
          RiskShape({ risk: 'POSSIBLE_RISK', dim: 20 })
            .accessibilityLevel('no-hide-descendants')
          Column({ space: 2 }) {
            Text(c.drugs.length > 1 ? `+ ${c.drugs[1]}` : '')
              .fontSize($r('app.float.font_body'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.risk_possible_text'))
            Text(c.reason)
              .fontSize($r('app.float.font_small'))
              .fontColor($r('app.color.ink_2'))
              .lineHeight(20)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .accessibilityGroup(true)
      }, (c: ComboVerdict) => c.drugs.join('+'))
      if (this.facts.alternatives.length > 0) {
        Divider().color($r('app.color.divider'))
        Text($r('app.string.med_alternatives', this.facts.alternatives.join(', ')))
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink_2'))
          .lineHeight(20)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_ml'))
  }

  @Builder
  brands() {
    Column({ space: 10 }) {
      this.label($r('app.string.med_brands'))
      Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
        ForEach(this.facts.brands, (b: string) => {
          Text(b)
            .fontSize($r('app.float.font_small'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
            .height(32)
            .padding({ left: 12, right: 12 })
            .backgroundColor($r('app.color.surface_alt'))
            .borderRadius(16)
        }, (b: string) => b)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  aiBlock() {
    if (this.aiState === 'OK' && this.ai !== undefined) {
      Column({ space: 12 }) {
        Row({ space: 8 }) {
          SourceBadge({ label: $r('app.string.med_ai_badge'), solid: true })
          Blank()
        }
        .width('100%')
        Text(this.ai.summary)
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.ink'))
          .lineHeight(23)
        if (this.ai.contains !== '') {
          Column({ space: 4 }) {
            this.label($r('app.string.med_ai_contains'))
            Text(this.ai.contains)
              .fontSize($r('app.float.font_small'))
              .fontColor($r('app.color.ink_2'))
              .lineHeight(20)
          }
          .alignItems(HorizontalAlign.Start)
        }
        if (this.ai.usedFor !== '' && !this.facts.known) {
          Column({ space: 4 }) {
            this.label($r('app.string.med_about'))
            Text(this.ai.usedFor)
              .fontSize($r('app.float.font_small'))
              .fontColor($r('app.color.ink_2'))
              .lineHeight(20)
          }
          .alignItems(HorizontalAlign.Start)
        }
        ForEach(this.ai.tips, (t: string) => {
          this.tipRow(t, $r('app.media.ic_wave'))
        }, (t: string) => t)
        Text($r('app.string.med_ai_caption'))
          .fontSize($r('app.float.font_micro'))
          .fontColor($r('app.color.ink_4'))
          .lineHeight(15)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .backgroundColor($r('app.color.surface_alt'))
      .borderRadius($r('app.float.radius_ml'))
      .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 12 }))
        .animation({ duration: Motion.REVEAL_MS, curve: Curve.EaseOut }))
    } else if (this.aiState === 'LOADING') {
      Row() {
        TypingDots({ label: $r('app.string.med_ai_loading') })
      }
      .width('100%')
      .height($r('app.float.button_height'))
      .padding({ left: 16 })
      .backgroundColor($r('app.color.surface_alt'))
      .borderRadius($r('app.float.radius_btn'))
    } else {
      Column({ space: 8 }) {
        QuietButton({
          label: $r('app.string.med_ai_button'),
          icon: $r('app.media.ic_wave'),
          onTap: () => {
            this.explain();
          }
        })
        if (this.aiState !== 'IDLE') {
          Text(this.aiMessage())
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.ink_3'))
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        this.header()
        this.riskBand()
        if (this.facts.usedFor !== '') {
          this.aboutCard()
        }
        if (this.facts.known) {
          this.interactionsCard()
        }
        if (this.facts.brands.length > 0) {
          this.brands()
        }
        // No backend and nothing cached: no button that can only fail.
        if (MedInfoClient.available() || this.ai !== undefined) {
          this.aiBlock()
        }
        // Taking one of my medicines that has a QT risk (or clashes with another of mine) can be logged for the watch.
        if (riskToLog(this.facts.risk, this.facts.interactions.length > 0) !== '') {
          IntakeCard({
            name: this.facts.ingredient !== '' ? this.facts.ingredient : this.facts.name,
            risk: riskToLog(this.facts.risk, this.facts.interactions.length > 0)
          })
        }
        Row({ space: 10 }) {
          InkButton({
            label: $r('app.string.med_check'),
            onTap: () => {
              if (this.med !== undefined) {
                this.onCheck(this.med);
              }
            }
          })
            .layoutWeight(1)
          SecondaryButton({
            label: $r('app.string.med_remind'),
            icon: $r('app.media.ic_bell'),
            onTap: () => {
              if (this.med !== undefined) {
                this.onRemind(this.med);
              }
            }
          })
            .layoutWeight(1)
        }
        .width('100%')
        QuietButton({
          label: $r('app.string.med_ask'),
          icon: $r('app.media.ic_tab_agent'),
          onTap: () => {
            if (this.med !== undefined) {
              this.onAsk(this.med);
            }
          }
        })
        Text($r('app.string.med_source'))
          .fontSize($r('app.float.font_micro'))
          .fontColor($r('app.color.ink_4'))
          .lineHeight(15)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 20, right: 20, top: 4, bottom: 32 })
    }
    .width('100%')
    .height('100%')   // fill the sheet so the content scrolls inside it instead of being clipped
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}
