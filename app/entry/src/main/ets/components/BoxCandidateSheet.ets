// Scan → a box we don't know yet (DESIGN.md §10.2 "Scan → box we don't know yet"). While /box-identify looks the
// barcode up it shows progress; then "Is this your box?" with the brand, ingredients and where it was found.
// Identification only — no risk colour here; the verdict comes after "Yes, check it" from CheckService.

import { BoxCandidate } from '../drugs/BoxIdentifyClient';
import { gtinCountry } from '../drugs/Gs1';
import { emergencyFor } from '../common/EmergencyNumbers';
import { InkButton, SecondaryButton, SourceBadge } from './Common';

export type LookupPhase = 'FAST' | 'DEEP' | 'FOUND';

@ComponentV2
export struct BoxCandidateSheet {
  @Param gtin: string = '';
  @Param phase: LookupPhase = 'FAST';
  @Param candidate: BoxCandidate | undefined = undefined;
  @Event onYes: () => void = () => {
  };
  @Event onNo: () => void = () => {
  };

  private barcodeLine(): string {
    const code: string = gtinCountry(this.gtin);
    return code.length === 0 ? `Barcode ${this.gtin}` : `${emergencyFor(code).name} box · ${this.gtin}`;
  }

  private detailLine(c: BoxCandidate): string {
    return [c.strength, c.form].filter((s: string) => s.length > 0).join(' · ');
  }

  @Builder
  looking() {
    Column({ space: 12 }) {
      LoadingProgress()
        .width(32)
        .height(32)
        .color($r('app.color.brand_accent'))
        .accessibilityText($r('app.string.a11y_box_lookup'))
      Text(this.phase === 'FAST' ? $r('app.string.scan_lookup_title') : $r('app.string.scan_lookup_web'))
        .fontSize($r('app.float.font_headline'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
      Text(this.phase === 'FAST' ? this.barcodeLine() : $r('app.string.scan_lookup_web_caption'))
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.ink_3'))
      SecondaryButton({
        label: $r('app.string.scan_type_instead'),
        onTap: () => {
          this.onNo();
        }
      })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  found(c: BoxCandidate) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text($r('app.string.scan_candidate_title'))
          .fontSize($r('app.float.font_title_3'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .layoutWeight(1)
        if (c.method === 'AI_WEB') {
          SourceBadge({ label: $r('app.string.scan_candidate_ai_badge') })
        }
      }
      .width('100%')
      Text(c.brand)
        .fontSize($r('app.float.font_headline'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
      Text(c.ingredients.join(' + '))
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.ink'))
      if (this.detailLine(c).length > 0) {
        Text(this.detailLine(c))
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink_3'))
      }
      if (c.unresolved.length > 0) {
        Text($r('app.string.scan_candidate_unconfirmed', c.unresolved.join(', ')))
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink_3'))
      }
      if (c.method === 'AI_WEB') {
        Text($r('app.string.scan_candidate_ai_caption'))
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink_2'))
      }
      Text(`${c.source} · ${this.barcodeLine()}`)
        .fontSize($r('app.float.font_micro'))
        .fontColor($r('app.color.ink_4'))
      Row({ space: 8 }) {
        InkButton({
          label: $r('app.string.scan_candidate_yes'),
          large: true,
          onTap: () => {
            this.onYes();
          }
        })
          .layoutWeight(1)
        SecondaryButton({
          label: $r('app.string.scan_candidate_no'),
          large: true,
          fill: false,
          onTap: () => {
            this.onNo();
          }
        })
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  build() {
    Scroll() {
      Column() {
        if (this.phase === 'FOUND' && this.candidate !== undefined) {
          this.found(this.candidate)
        } else {
          this.looking()
        }
      }
      .padding(20)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
  }
}
