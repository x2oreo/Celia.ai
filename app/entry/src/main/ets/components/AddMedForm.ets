// "Add a medicine" form with autocomplete and a live risk chip. Used in the Medicines sheet and onboarding.

import { DrugChecker } from '../drugs/DrugChecker';
import { DrugEntry } from '../drugs/DrugDataset';
import { LocalStore } from '../data/LocalStore';
import { RiskLevel } from '../model/DrugVerdict';
import { PrimaryButton, RiskBadge } from './Common';

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

  private riskOf(e: DrugEntry | undefined): RiskLevel {
    return e === undefined ? 'UNKNOWN_DRUG' : e.risk;
  }

  build() {
    Column({ space: 12 }) {
      TextInput({ text: this.name, placeholder: $r('app.string.meds_name_hint') })
        .height(48)
        .backgroundColor($r('app.color.field_bg'))
        .onChange((v: string) => this.onNameChange(v))
      if (this.suggestions.length > 0) {
        Column() {
          ForEach(this.suggestions, (e: DrugEntry) => {
            Row({ space: 8 }) {
              Text(e.ingredient)
                .fontSize($r('app.float.font_body'))
                .fontColor($r('sys.color.font_primary'))
                .layoutWeight(1)
              RiskBadge({ risk: e.risk, compact: true })
            }
            .width('100%')
            .padding({ top: 10, bottom: 10, left: 12, right: 12 })
            .onClick(() => this.pick(e))
          }, (e: DrugEntry) => e.ingredient)
        }
        .width('100%')
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius($r('app.float.radius_s'))
        .border({ width: 1, color: $r('app.color.divider') })
      }
      if (this.name.trim().length >= 3) {
        Row({ space: 8 }) {
          Text(this.resolved === undefined ? $r('app.string.meds_not_recognised') : this.resolved.ingredient)
            .fontSize($r('app.float.font_small'))
            .fontColor($r('sys.color.font_secondary'))
            .layoutWeight(1)
          RiskBadge({ risk: this.riskOf(this.resolved), compact: true })
        }
        .width('100%')
      }
      TextInput({ text: this.dose, placeholder: $r('app.string.meds_dose_hint') })
        .height(48)
        .backgroundColor($r('app.color.field_bg'))
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
