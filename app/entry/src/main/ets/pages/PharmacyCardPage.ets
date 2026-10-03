// Pharmacy card (F-40): a full-screen message to show at a pharmacy counter, with my current medicines.
// English for now (other languages are kept in emergency/PharmacyStrings.ets). Screen stays on, brightness up.

import { LocalStore } from '../data/LocalStore';
import { Profile } from '../model/Profile';
import { Medication } from '../model/Medication';
import { pharmacyText, PharmacyText } from '../emergency/PharmacyStrings';
import { emergencyFor, systemCountry } from '../common/EmergencyNumbers';
import { medLine } from '../emergency/CardContent';
import { keepScreenOn, setBrightness } from '../common/Screen';

@ComponentV2
export struct PharmacyCardPage {
  @Local profile: Profile | undefined = undefined;
  @Local meds: Medication[] = [];

  aboutToAppear(): void {
    this.load();
    keepScreenOn(this.getUIContext().getHostContext()!, true);
    setBrightness(this.getUIContext().getHostContext()!, 1);
  }

  aboutToDisappear(): void {
    keepScreenOn(this.getUIContext().getHostContext()!, false);
    setBrightness(this.getUIContext().getHostContext()!, -1);
  }

  private async load(): Promise<void> {
    this.profile = await LocalStore.get().getProfile();
    this.meds = await LocalStore.get().listMeds();
  }

  @Builder
  message(t: PharmacyText, big: boolean) {
    Column({ space: 8 }) {
      Text(t.headline)
        .fontSize(big ? 28 : 18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#B42318')
      Text(t.body)
        .fontSize(big ? 20 : 15)
        .fontColor('#101828')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 20 }) {
          this.message(pharmacyText('en'), true)
          Divider().color('#E4E7EC')
          Text(this.meds.length === 0 ? '—' : this.meds.map((m: Medication) => medLine(m)).join('\n'))
            .fontSize(18)
            .fontColor('#101828')
            .width('100%')
          Text(emergencyFor(this.profile?.country ?? systemCountry()).name)
            .fontSize(12)
            .fontColor('#667085')
        }
        .padding(24)
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .backgroundColor('#FFFFFF')
    }
    .title($r('app.string.ph_title'))
    .backgroundColor('#FFFFFF')
  }
}
