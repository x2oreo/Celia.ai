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
import { NavRow, PageTitle, QuietButton, SecondaryButton, SectionHeader } from '../components/Common';
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
        .fontSize($r('app.float.font_caption'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.card_fixed_ink_3'))
      Text(value)
        .fontSize($r('app.float.font_subtitle'))
        .fontColor($r('app.color.card_fixed_ink'))
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  card() {
    // Always light, high-contrast colours: read by strangers, often outdoors.
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Image($r('app.media.ic_tab_heart')).width(26).height(26).fillColor($r('app.color.on_accent'))
        Text(cardText(this.lang).title)
          .fontSize($r('app.float.font_title_3'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.on_accent'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.card_fixed_alert'))
      .borderRadius({ topLeft: 18, topRight: 18 })

      Column({ space: 14 }) {
        if ((this.cardProfile().name ?? '').length > 0) {
          Text(this.cardProfile().name ?? '').fontSize($r('app.float.font_title')).fontWeight(FontWeight.Bold).fontColor($r('app.color.card_fixed_ink'))
        }
        Text(cardText(this.lang).condition)
          .fontSize($r('app.float.font_title_3'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.card_fixed_alert'))
        Row({ space: 16 }) {
          this.cardLine(cardText(this.lang).genotype, this.cardProfile().genotype === 'UNKNOWN' ? '?' : this.cardProfile().genotype)
        }
        .width('100%')
        Text(this.cardProfile().hasIcd ? cardText(this.lang).icdYes : cardText(this.lang).icdNo)
          .fontSize($r('app.float.font_subtitle'))
          .fontWeight(this.cardProfile().hasIcd ? FontWeight.Bold : FontWeight.Normal)
          .fontColor($r('app.color.card_fixed_ink'))
        Text(cardText(this.lang).avoid)
          .fontSize($r('app.float.font_subtitle'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.card_fixed_ink'))
          .padding(12)
          .backgroundColor($r('app.color.card_fixed_alert_tint'))
          .borderRadius(12)
          .width('100%')
        Text(cardText(this.lang).treatment)
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.card_fixed_ink_2'))
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
    .backgroundColor($r('app.color.card_fixed_bg'))
    .borderRadius(20)
    .border({ width: 2, color: $r('app.color.card_fixed_alert') })
  }

  private conditionLine(): string {
    const g: string = this.cardProfile().genotype;
    return g === 'UNKNOWN' ? 'Long QT syndrome' : `Long QT syndrome, type ${g.replace('LQT', '')}`;
  }

  private factsLine(): string {
    const icd: string = this.cardProfile().hasIcd ? 'ICD' : 'No ICD';
    return this.meds.length === 0 ? icd : `${icd} · ${this.meds.slice(0, 2).map((m: Medication) => medLine(m)).join(', ')}`;
  }

  // Medical alert card (same layout as the home-screen widget, design B6). Always light.
  @Builder
  alertCard() {
    Row({ space: 14 }) {
      Column() {
        Text($r('app.string.em_call'))
          .fontSize($r('app.float.font_badge'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.on_accent'))
        Text(this.info().ambulance)
          .fontSize($r('app.float.font_title_1'))
          .fontWeight(800)
          .fontColor($r('app.color.on_accent'))
      }
      .width(104)
      .height(104)
      .justifyContent(FlexAlign.Center)
      .borderRadius(52)
      .backgroundColor($r('app.color.danger'))
      .border({ width: 5, color: $r('app.color.risk_known_border') })
      .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.96 })
      .accessibilityText(`Call ${this.info().ambulance}`)
      .onClick(() => {
        this.call(this.info().ambulance);
      })

      Column({ space: 3 }) {
        Text($r('app.string.em_alert_label'))
          .fontSize($r('app.float.font_caption'))
          .fontWeight(800)
          .letterSpacing(0.6)
          .fontColor($r('app.color.card_fixed_alert'))
        Text(this.conditionLine())
          .fontSize($r('app.float.font_headline'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.card_fixed_ink'))
        Text(this.factsLine())
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.card_fixed_ink_2'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text($r('app.string.em_avoid'))
          .fontSize($r('app.float.font_small'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.card_fixed_alert'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_fixed_bg'))
    .border({ width: 1, color: $r('app.color.card_fixed_border') })
    .borderRadius($r('app.float.radius_l'))
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        PageTitle({ title: $r('app.string.emergency_title') })

        this.alertCard()

        // Contacts: one tap to call
        ForEach(this.profile?.contacts ?? [], (c: Contact) => {
          QuietButton({
            label: `Call ${c.name} (${c.relation === '' ? 'ICE' : c.relation})`,
            icon: $r('app.media.ic_phone'),
            onTap: () => {
              this.call(c.phone);
            }
          })
        }, (c: Contact) => `${c.name}-${c.phone}`)
        if (this.info().general !== this.info().ambulance) {
          SecondaryButton({
            label: `${this.info().general} · General emergency`,
            icon: $r('app.media.ic_phone'),
            onTap: () => {
              this.call(this.info().general);
            }
          })
        }

        NavRow({
          icon: $r('app.media.ic_bell'),
          title: $r('app.string.em_sos_title'),
          subtitle: $r('app.string.em_sos_sub'),
          onTap: () => {
            this.navStack.pushPathByName(Routes.SOS, null);
          }
        })
          .margin({ top: 8 })
        NavRow({
          icon: $r('app.media.ic_hand'),
          title: $r('app.string.emergency_bystander'),
          subtitle: $r('app.string.em_bystander_sub'),
          onTap: () => {
            this.navStack.pushPathByName(Routes.BYSTANDER, null);
          }
        })
        NavRow({
          icon: $r('app.media.ic_pill'),
          title: $r('app.string.ph_title'),
          subtitle: $r('app.string.ph_subtitle'),
          onTap: () => {
            this.navStack.pushPathByName(Routes.PHARMACY_CARD, null);
          }
        })

        if (this.profile === undefined) {
          Text($r('app.string.emergency_no_profile'))
            .fontSize($r('app.float.font_small'))
            .fontColor($r('app.color.ink_3'))
            .padding(20)
        } else {
          SectionHeader({ title: $r('app.string.em_full_card') })
          this.card()

          // Offline QR: any phone camera can read the card, no app and no internet needed
          Column({ space: 12 }) {
            Row({ space: 12 }) {
              Image($r('app.media.ic_qr')).width(20).height(20).fillColor($r('app.color.ink_2'))
              Text($r('app.string.emergency_qr'))
                .fontSize($r('app.float.font_body'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.ink'))
                .layoutWeight(1)
              Image($r('app.media.ic_chevron_right'))
                .width(16)
                .height(16)
                .fillColor($r('app.color.ink_4'))
                .rotate({ angle: this.showQr ? 90 : 0 })
                .animation({ duration: 180, curve: Curve.EaseOut })
            }
            .width('100%')
            .height($r('app.float.chip_height'))
            .onClick(() => {
              this.showQr = !this.showQr;
            })
            if (this.showQr) {
              QRCode(cardPlainText(this.profile, this.meds))
                .width(240)
                .height(240)
                .color($r('app.color.card_fixed_ink'))
                .backgroundColor($r('app.color.card_fixed_bg'))
              Text($r('app.string.emergency_qr_hint'))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.ink_3'))
                .textAlign(TextAlign.Center)
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 6, bottom: this.showQr ? 16 : 6 })
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.border') })
          .borderRadius($r('app.float.radius_m'))
          .alignItems(HorizontalAlign.Center)
        }
      }
      .padding({ left: $r('app.float.space_screen'), right: $r('app.float.space_screen'), bottom: 24 })
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .backgroundColor($r('app.color.bg'))
  }
}
