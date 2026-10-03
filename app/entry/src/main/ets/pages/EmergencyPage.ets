// Emergency tab (F-08, F-26, F-29, F-30): call the right number for the country, SOS, bystander help, and an
// emergency card a stranger can read — high contrast, English, offline QR.

import { LocalStore, StoreTopic } from '../data/LocalStore';
import { Contact, Profile } from '../model/Profile';
import { Medication } from '../model/Medication';
import { emergencyFor, EmergencyInfo, systemCountry } from '../common/EmergencyNumbers';
import { cardText } from '../common/CardStrings';
import { cardPlainText, medLine } from '../emergency/CardContent';
import { dial } from '../common/Dialer';
import { Routes } from '../common/Routes';
import { PageTitle, PrimaryButton, SecondaryButton } from '../components/Common';
import { toast } from '../common/Toast';

@ComponentV2
export struct EmergencyPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local profile: Profile | undefined = undefined;
  @Local meds: Medication[] = [];
  // English for now; the other 12 languages in common/CardStrings.ets are kept for later.
  private lang: string = 'en';
  @Local showQr: boolean = false;
  private unsubscribe: () => void = () => {
  };

  aboutToAppear(): void {
    this.reload();
    this.unsubscribe = LocalStore.get().onChange((t: StoreTopic) => {
      if (t === 'profile' || t === 'meds') {
        this.reload();
      }
    });
  }

  aboutToDisappear(): void {
    this.unsubscribe();
  }

  private async reload(): Promise<void> {
    this.profile = await LocalStore.get().getProfile();
    this.meds = await LocalStore.get().listMeds();
  }

  // Builders read state through `this` so the card re-renders when the profile changes.
  private cardProfile(): Profile {
    const empty: Profile = { condition: 'LQTS', genotype: 'UNKNOWN', hasIcd: false, notes: '', contacts: [] };
    return this.profile ?? empty;
  }

  private info(): EmergencyInfo {
    return emergencyFor(this.profile?.country ?? systemCountry());
  }

  private async call(number: string): Promise<void> {
    const ok: boolean = await dial(number);
    if (!ok) {
      toast(this.getUIContext(), $r('app.string.emergency_dial_failed'));
    }
  }

  @Builder
  cardLine(label: string, value: string) {
    Column({ space: 2 }) {
      Text(label.toUpperCase())
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#667085')
      Text(value)
        .fontSize(18)
        .fontColor('#101828')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  card() {
    // Always light, high-contrast colours: read by strangers, often outdoors.
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Image($r('app.media.ic_tab_heart')).width(26).height(26).fillColor('#FFFFFF')
        Text(cardText(this.lang).title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .layoutWeight(1)
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#B42318')
      .borderRadius({ topLeft: 20, topRight: 20 })

      Column({ space: 14 }) {
        if ((this.cardProfile().name ?? '').length > 0) {
          Text(this.cardProfile().name ?? '').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#101828')
        }
        Text(cardText(this.lang).condition)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#B42318')
        Row({ space: 16 }) {
          this.cardLine(cardText(this.lang).genotype, this.cardProfile().genotype === 'UNKNOWN' ? '?' : this.cardProfile().genotype)
        }
        .width('100%')
        Text(this.cardProfile().hasIcd ? cardText(this.lang).icdYes : cardText(this.lang).icdNo)
          .fontSize(18)
          .fontWeight(this.cardProfile().hasIcd ? FontWeight.Bold : FontWeight.Normal)
          .fontColor('#101828')
        Text(cardText(this.lang).avoid)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#101828')
          .padding(12)
          .backgroundColor('#FEF3F2')
          .borderRadius(12)
          .width('100%')
        Text(cardText(this.lang).treatment)
          .fontSize(16)
          .fontColor('#344054')
        this.cardLine(cardText(this.lang).meds, this.meds.length === 0 ? cardText(this.lang).noMeds :
          this.meds.map((m: Medication) => medLine(m)).join('\n'))
        if (this.cardProfile().contacts.length > 0) {
          this.cardLine(cardText(this.lang).contacts,
            this.cardProfile().contacts.map((c: Contact) => `${c.name} (${c.relation}) ${c.phone}`).join('\n'))
        }
        if (this.cardProfile().notes.length > 0) {
          this.cardLine(cardText(this.lang).notes, this.cardProfile().notes)
        }
      }
      .padding({ left: 16, right: 16, bottom: 16 })
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .border({ width: 2, color: '#B42318' })
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        PageTitle({ title: $r('app.string.emergency_title'), subtitle: $r('app.string.emergency_subtitle') })

        PrimaryButton({
          label: `${this.info().ambulance} · Call ambulance${this.info().code === '' ? '' : ` (${this.info().code})`}`,
          icon: $r('app.media.ic_phone'),
          danger: true,
          large: true,
          onTap: () => {
            this.call(this.info().ambulance);
          }
        })
        if (this.info().general !== this.info().ambulance) {
          SecondaryButton({
            label: `${this.info().general} · General emergency`,
            icon: $r('app.media.ic_phone'),
            onTap: () => {
              this.call(this.info().general);
            }
          })
        }
        Row({ space: 12 }) {
          SecondaryButton({
            label: $r('app.string.emergency_sos'),
            icon: $r('app.media.ic_bell'),
            onTap: () => {
              this.navStack.pushPathByName(Routes.SOS, null);
            }
          })
            .layoutWeight(1)
          SecondaryButton({
            label: $r('app.string.emergency_bystander'),
            icon: $r('app.media.ic_hand'),
            onTap: () => {
              this.navStack.pushPathByName(Routes.BYSTANDER, null);
            }
          })
            .layoutWeight(1)
        }
        .width('100%')

        SecondaryButton({
          label: $r('app.string.ph_title'),
          icon: $r('app.media.ic_pill'),
          onTap: () => {
            this.navStack.pushPathByName(Routes.PHARMACY_CARD, null);
          }
        })

        if (this.profile === undefined) {
          Text($r('app.string.emergency_no_profile'))
            .fontSize($r('app.float.font_body'))
            .fontColor($r('sys.color.font_secondary'))
            .padding(20)
        } else {
          this.card()

          // Contacts: one tap to call
          ForEach(this.profile.contacts, (c: Contact) => {
            SecondaryButton({
              label: `Call ${c.name} (${c.relation})`,
              icon: $r('app.media.ic_phone'),
              onTap: () => {
                this.call(c.phone);
              }
            })
          }, (c: Contact) => `${c.name}-${c.phone}`)

          // Offline QR: any phone camera can read the card, no app and no internet needed
          Column({ space: 12 }) {
            Row() {
              Image($r('app.media.ic_qr')).width(22).height(22).fillColor($r('app.color.brand_accent'))
              Text($r('app.string.emergency_qr'))
                .fontSize($r('app.float.font_body'))
                .fontColor($r('sys.color.font_primary'))
                .margin({ left: 12 })
                .layoutWeight(1)
              Image($r('app.media.ic_chevron_right'))
                .width(16)
                .height(16)
                .fillColor($r('sys.color.icon_secondary'))
                .rotate({ angle: this.showQr ? 90 : 0 })
            }
            .width('100%')
            .onClick(() => {
              this.showQr = !this.showQr;
            })
            if (this.showQr) {
              QRCode(cardPlainText(this.profile, this.meds))
                .width(240)
                .height(240)
                .color('#101828')
                .backgroundColor('#FFFFFF')
              Text($r('app.string.emergency_qr_hint'))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('sys.color.font_secondary'))
                .textAlign(TextAlign.Center)
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius($r('app.float.radius_m'))
          .alignItems(HorizontalAlign.Center)
        }
      }
      .padding({ left: 16, right: 16, bottom: 24 })
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .backgroundColor($r('app.color.page_bg'))
  }
}
