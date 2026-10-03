// "Add a medicine" form with autocomplete and a live risk chip. Used in the Medicines sheet and onboarding.

import { DrugChecker } from '../drugs/DrugChecker';
import { DrugEntry } from '../drugs/DrugDataset';
import { DrugInfo, drugInfo } from '../drugs/DrugInfo';
import { LocalStore } from '../data/LocalStore';
import { RiskLevel } from '../model/DrugVerdict';
import { PrimaryButton, resText, RiskBadge } from './Common';
import { RiskUi } from '../common/RiskUi';

@ComponentV2
export struct AddMedForm {
  @Event onAdded: () => void = () => {
  };
  @Local name: string = '';
  @Local dose: string = '';
  @Local suggestions: DrugEntry[] = [];
  @Local resolved: DrugEntry | undefined = undefined;

  private onNameChange(value: string): void {
    this.name = value;
    // Hide the list once the text is exactly a known name (e.g. right after picking a suggestion).
    const exact: boolean = DrugChecker.get().entry(value.trim()) !== undefined;
    this.suggestions = exact ? [] : DrugChecker.get().suggest(value, 5);
    this.resolved = value.trim().length >= 3 ? DrugChecker.get().resolve(value) : undefined;
  }

  private pick(e: DrugEntry): void {
    // Keep a brand the user typed ("Concor"); otherwise use the generic name.
    if (!e.aliases.includes(this.name.trim().toLowerCase())) {
      this.name = e.ingredient;
    }
    this.resolved = e;
    this.suggestions = [];
  }

  private async save(): Promise<void> {
    const n: string = this.name.trim();
    if (n.length === 0) {
      return;
    }
    const e: DrugEntry | undefined = this.resolved ?? DrugChecker.get().resolve(n);
    await LocalStore.get().addMed(n, e?.ingredient ?? '', this.dose.trim());
    this.name = '';
    this.dose = '';
    this.resolved = undefined;
    this.suggestions = [];
    this.onAdded();
  }

  private infoOf(e: DrugEntry): DrugInfo | undefined {
    return drugInfo(e.ingredient);
  }

  private riskOf(e: DrugEntry | undefined): RiskLevel {
    return e === undefined ? 'UNKNOWN_DRUG' : e.risk;
  }

  build() {
    Column({ space: 12 }) {
      TextInput({ text: this.name, placeholder: $r('app.string.meds_name_hint') })
        .height(48)
        .backgroundColor($r('app.color.surface_alt'))
        .onChange((v: string) => this.onNameChange(v))
      if (this.suggestions.length > 0) {
        Column() {
          ForEach(this.suggestions, (e: DrugEntry) => {
            Row({ space: 8 }) {
              Text(e.ingredient)
                .fontSize($r('app.float.font_body'))
                .fontColor($r('app.color.ink'))
                .layoutWeight(1)
              RiskBadge({ risk: e.risk, compact: true })
            }
            .width('100%')
            .padding({ top: 10, bottom: 10, left: 12, right: 12 })
            .accessibilityGroup(true)
            .accessibilityText(`${e.ingredient}, ${resText(this.getUIContext(), RiskUi.label(e.risk))}`)
            .onClick(() => this.pick(e))
          }, (e: DrugEntry) => e.ingredient)
        }
        .width('100%')
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.border') })
        .borderRadius($r('app.float.radius_s'))
        .border({ width: 1, color: $r('app.color.divider') })
      }
      if (this.name.trim().length >= 3) {
        if (this.resolved === undefined) {
          Row({ space: 8 }) {
            Text($r('app.string.meds_not_recognised'))
              .fontSize($r('app.float.font_small'))
              .fontColor($r('app.color.ink_3'))
              .layoutWeight(1)
            RiskBadge({ risk: this.riskOf(this.resolved), compact: true })
          }
          .width('100%')
        } else {
          // Live preview of what the medicine is, from the curated data (DrugInfo), before it is saved.
          Column({ space: 6 }) {
            Row({ space: 8 }) {
              Column({ space: 2 }) {
                Text(this.resolved.ingredient)
                  .fontSize($r('app.float.font_body'))
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.ink'))
                Text(this.resolved.drugClass)
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.ink_3'))
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              RiskBadge({ risk: this.riskOf(this.resolved), compact: true })
            }
            .width('100%')
            if (this.infoOf(this.resolved) !== undefined) {
              Text(this.infoOf(this.resolved)?.usedFor ?? '')
                .fontSize($r('app.float.font_small'))
                .fontColor($r('app.color.ink_2'))
                .lineHeight(20)
              if ((this.infoOf(this.resolved)?.tips.length ?? 0) > 0) {
                Row({ space: 6 }) {
                  Image($r('app.media.ic_check')).width(12).height(12).fillColor($r('app.color.ink_4'))
                  Text(this.infoOf(this.resolved)?.tips[0] ?? '')
                    .fontSize($r('app.float.font_caption'))
                    .fontColor($r('app.color.ink_3'))
                    .lineHeight(16)
                    .layoutWeight(1)
                }
                .width('100%')
                .alignItems(VerticalAlign.Top)
              }
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(12)
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.border') })
          .borderRadius($r('app.float.radius_s'))
          .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut }))
        }
      }
      TextInput({ text: this.dose, placeholder: $r('app.string.meds_dose_hint') })
        .height(48)
        .backgroundColor($r('app.color.surface_alt'))
        .onChange((v: string) => {
          this.dose = v;
        })
      PrimaryButton({
        label: $r('app.string.meds_add'),
        icon: $r('app.media.ic_plus'),
        active: this.name.trim().length > 0,
        onTap: () => {
          this.save();
        }
      })
    }
    .width('100%')
  }
}
