// "Teach this barcode" (F-36): a box we don't know yet (Bulgarian and other non-Polish boxes have no open
// barcode list). The user types the name on the box once; the mapping stays on this phone and the next scan of
// the same box resolves instantly. The check itself stays deterministic — an unrecognised name is UNKNOWN_DRUG.

import { DrugChecker } from '../drugs/DrugChecker';
import { DrugEntry } from '../drugs/DrugDataset';
import { gtinCountry } from '../drugs/Gs1';
import { learnBox } from '../drugs/BarcodeService';
import { emergencyFor } from '../common/EmergencyNumbers';
import { fmtText, PrimaryButton, RiskBadge } from './Common';

@ComponentV2
export struct TeachBoxForm {
  @Param gtin: string = '';
  @Event onSaved: (gtin: string) => void = (gtin: string) => {
  };
  @Local name: string = '';
  @Local strength: string = '';
  @Local resolved: DrugEntry | undefined = undefined;
  @Local saving: boolean = false;

  private countryLine(): string {
    const code: string = gtinCountry(this.gtin);
    return code.length === 0 ? fmtText(this.getUIContext(), $r('app.string.teach_barcode'), this.gtin) :
      fmtText(this.getUIContext(), $r('app.string.teach_country_box'), emergencyFor(code).name, this.gtin);
  }

  private async save(): Promise<void> {
    const n: string = this.name.trim();
    if (n.length === 0 || this.saving) {
      return;
    }
    this.saving = true;
    const e: DrugEntry | undefined = this.resolved ?? DrugChecker.get().resolve(n);
    await learnBox(this.gtin, n, e?.ingredient ?? n, this.strength.trim());
    this.saving = false;
    this.name = '';
    this.strength = '';
    this.resolved = undefined;
    this.onSaved(this.gtin);
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Text($r('app.string.teach_title'))
          .fontSize($r('app.float.font_title'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Text(this.countryLine())
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.ink_2'))
        Text($r('app.string.teach_body'))
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.ink_2'))
        TextInput({ text: this.name, placeholder: $r('app.string.teach_name_hint') })
          .height(48)
          .backgroundColor($r('app.color.surface_alt'))
          .onChange((v: string) => {
            this.name = v;
            this.resolved = v.trim().length >= 3 ? DrugChecker.get().resolve(v) : undefined;
          })
        TextInput({ text: this.strength, placeholder: $r('app.string.teach_strength_hint') })
          .height(48)
          .backgroundColor($r('app.color.surface_alt'))
          .onChange((v: string) => {
            this.strength = v;
          })
        if (this.name.trim().length >= 3) {
          Row({ space: 8 }) {
            Text(this.resolved === undefined ? $r('app.string.teach_unrecognised') : this.resolved.ingredient)
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.ink_2'))
              .layoutWeight(1)
            RiskBadge({ risk: this.resolved === undefined ? 'UNKNOWN_DRUG' : this.resolved.risk, compact: true })
          }
          .width('100%')
        }
        PrimaryButton({
          label: $r('app.string.teach_save'),
          icon: $r('app.media.ic_search'),
          active: this.name.trim().length > 0 && !this.saving,
          onTap: () => {
            this.save();
          }
        })
        Text($r('app.string.teach_privacy'))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.ink_3'))
      }
      .padding(20)
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
  }
}
