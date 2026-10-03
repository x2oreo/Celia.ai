// Emergency tab (F-08, F-26, F-29, F-30): call the right number for the country, SOS, bystander help, and an
// emergency card a stranger can read — high contrast, in the chosen card language (13), read aloud on request,
// and a QR link to the card viewer.

import { LocalStore, StoreTopic } from '../data/LocalStore';
import { CardField, Contact, Profile } from '../model/Profile';
import { Medication } from '../model/Medication';
import { emergencyFor, EmergencyInfo, systemCountry } from '../common/EmergencyNumbers';
import { CARD_TEXTS, CardText, cardLabels, cardText } from '../common/CardStrings';
import { CardRow, detailRows, shownOnCard } from '../emergency/EmergencyDetails';
import { cardSpeech } from '../emergency/CardSpeech';
import { NearbyKind, nearbySearchUrl } from '../emergency/NearbyHelp';
import { VoiceOutput } from '../voice/VoiceOutput';
import { promptAction } from '@kit.ArkUI';
import { medLine } from '../emergency/CardContent';
import { buildPayload, cardLink } from '../emergency/CardLink';
import { ShareRecord, ShareService } from '../share/ShareService';
import { dial } from '../common/Dialer';
import { Routes } from '../common/Routes';
import { NavRow, PageTitle, QuietButton, SecondaryButton, SectionHeader } from '../components/Common';
import { toast } from '../common/Toast';
import { copyText } from '../common/Clipboard';
import { Logger } from '../common/Logger';
import { common } from '@kit.AbilityKit';

const log: Logger = new Logger('EmergencyPage');

@ComponentV2
export struct EmergencyPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local profile: Profile | undefined = undefined;
  @Local meds: Medication[] = [];
  @Local lang: string = 'en';          // card language (Profile.cardLanguage), 13 in common/CardStrings.ets
  @Local canSpeak: boolean = false;
  @Local speaking: boolean = false;
  private unsubSpeaking: () => void = () => {
  };
  @Local showQr: boolean = false;
  @Local shareUrl: string = '';        // short encrypted link (Supabase share); '' → the long in-link fallback
  @Local sharing: boolean = false;
  private shareDirty: boolean = false;
  private unsubscribe: () => void = () => {
  };

  aboutToAppear(): void {
    this.unsubSpeaking = VoiceOutput.get().onSpeaking((on: boolean) => {
      this.speaking = on;
    });
    this.reload();
    this.unsubscribe = LocalStore.get().onChange((t: StoreTopic) => {
      if (t === 'profile' || t === 'meds') {
        this.reload();
      }
    });
  }

  aboutToDisappear(): void {
    this.unsubscribe();
    this.unsubSpeaking();
    if (this.speaking) {
      VoiceOutput.get().stop();
    }
  }

  private async refreshVoice(): Promise<void> {
    this.canSpeak = await VoiceOutput.get().canSay(this.lang);
  }

  private async pickLanguage(code: string): Promise<void> {
    if (code === this.lang) {
      return;
    }
    this.lang = code;
    if (this.speaking) {
      await VoiceOutput.get().stop();
    }
    this.refreshVoice();
    if (this.profile !== undefined) {
      const p: Profile = this.profile;
      p.cardLanguage = code;
      await LocalStore.get().saveProfile(p);
    }
  }

  private async readAloud(): Promise<void> {
    if (this.speaking) {
      await VoiceOutput.get().stop();
      return;
    }
    const ok: boolean = await VoiceOutput.get().say(cardSpeech(cardText(this.lang), this.cardProfile(), this.meds),
      this.lang);
    if (!ok) {
      toast(this.getUIContext(), $r('app.string.em_read_unavailable'));
    }
  }

  private openNearby(kind: NearbyKind): void {
    const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    ctx.openLink(nearbySearchUrl(kind)).catch((e: Error) => {
      log.warn(`nearby open failed: ${JSON.stringify(e)}`);
      toast(this.getUIContext(), $r('app.string.error_generic'));
    });
  }

  private confirmRemove(): void {
    if (this.sharing) {
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      title: this.str($r('app.string.share_remove_title')),
      message: this.str($r('app.string.share_remove_body')),
      buttons: [
        { text: this.str($r('app.string.agent_cancel')), color: $r('app.color.ink_2') },
        { text: this.str($r('app.string.share_remove_confirm')), color: $r('app.color.danger') }
      ]
    }).then((r: promptAction.ShowDialogSuccessResponse) => {
      if (r.index === 1) {
        this.removeShare();
      }
    }).catch((e: Error) => log.warn(`remove dialog: ${e.message}`));
  }

  private currentCardLink(): string {
    if (this.shareUrl !== '') {
      return this.shareUrl;
    }
    return this.profile === undefined ? '' : cardLink(this.profile, this.meds, this.info().code);
  }

  // Encrypts the current card and uploads it once per change; the QR becomes a short link that scans instantly.
  // Without a backend (or offline) the QR keeps the whole card inside the link.
  private async refreshShare(): Promise<void> {
    if (this.profile === undefined || !ShareService.available()) {
      return;
    }
    if (this.sharing) {
      this.shareDirty = true;   // the card changed mid-upload: upload once more when this one finishes
      return;
    }
    this.sharing = true;
    try {
      do {
        this.shareDirty = false;
        const json: string = JSON.stringify(buildPayload(this.cardProfile(), this.meds, this.info().code));
        const r: ShareRecord | undefined = await ShareService.share('card', json);
        this.shareUrl = r !== undefined ? ShareService.url(r) : '';
      } while (this.shareDirty);
    } finally {
      this.sharing = false;
    }
  }

  private async removeShare(): Promise<void> {
    const ok: boolean = await ShareService.revoke('card');
    this.shareUrl = '';
    this.showQr = false;
    toast(this.getUIContext(), ok ? $r('app.string.share_removed') : $r('app.string.error_generic'));
  }

  private openCard(): void {
    const link: string = this.currentCardLink();
    if (link.length === 0) {
      return;
    }
    const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    ctx.openLink(link).catch((e: Error) => {
      log.warn(`card open failed: ${JSON.stringify(e)}`);
      toast(this.getUIContext(), $r('app.string.error_generic'));
    });
  }

  private async copyCard(): Promise<void> {
    const link: string = this.currentCardLink();
    if (link.length > 0 && await copyText(link)) {
      toast(this.getUIContext(), $r('app.string.emergency_card_copied'));
    }
  }

  private async reload(): Promise<void> {
    this.profile = await LocalStore.get().getProfile();
    this.meds = await LocalStore.get().listMeds();
    this.lang = cardText(this.profile?.cardLanguage).code;
    this.refreshVoice();
    if (this.showQr) {
      this.refreshShare();   // the card changed: upload it again (the old link is revoked)
    }
  }

  private str(r: Resource): string {
    try {
      const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      return ctx.resourceManager.getStringSync(r.id);
    } catch (e) {
      return '';
    }
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

  // Card language chips (DESIGN.md §10.2 Emergency): each language in its own name.
  @Builder
  languageRow() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(CARD_TEXTS, (t: CardText) => {
          Text(t.language)
            .fontSize($r('app.float.font_small'))
            .fontWeight(FontWeight.Medium)
            .fontColor(this.lang === t.code ? $r('app.color.on_accent') : $r('app.color.ink'))
            .height($r('app.float.chip_height'))
            .padding({ left: 16, right: 16 })
            .backgroundColor(this.lang === t.code ? $r('app.color.chat_user_bg') : $r('app.color.surface'))
            .border({ width: this.lang === t.code ? 0 : 1, color: $r('app.color.border') })
            .borderRadius(22)
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
            .accessibilityText(`Card language ${t.language}${this.lang === t.code ? ', selected' : ''}`)
            .onClick(() => {
              this.pickLanguage(t.code);
            })
        }, (t: CardText) => t.code)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  @Builder
  nearbyButton(kind: NearbyKind, label: Resource) {
    Text(label)
      .fontSize($r('app.float.font_small'))
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.ink'))
      .textAlign(TextAlign.Center)
      .maxLines(2)
      .layoutWeight(1)
      .constraintSize({ minHeight: $r('app.float.chip_height') })
      .padding({ left: 8, right: 8, top: 6, bottom: 6 })
      .backgroundColor($r('app.color.surface_alt'))
      .borderRadius($r('app.float.radius_btn'))
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
      .accessibilityDescription('Opens a map search near you')
      .onClick(() => {
        this.openNearby(kind);
      })
  }

  @Builder
  nearbyRow() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Image($r('app.media.ic_location')).width(18).height(18).fillColor($r('app.color.ink_2'))
        Text($r('app.string.em_nearby'))
          .fontSize($r('app.float.font_body'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ink'))
      }
      Row({ space: 8 }) {
        this.nearbyButton('HOSPITAL', $r('app.string.em_nearby_hospital'))
        this.nearbyButton('PHARMACY', $r('app.string.em_nearby_pharmacy'))
        this.nearbyButton('AED', $r('app.string.em_nearby_aed'))
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_m'))
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
        if ((this.cardProfile().name ?? '').length > 0 && shownOnCard(this.cardProfile(), CardField.NAME)) {
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
        // Emergency details (B4) in their fixed order; empty and switched-off fields are left out.
        ForEach(detailRows(this.cardProfile(), cardLabels(this.lang), Date.now()), (r: CardRow) => {
          this.cardLine(r.label, r.value)
        }, (r: CardRow, i: number) => `${i}-${r.id}-${r.label}-${r.value}`)
        this.cardLine(cardText(this.lang).meds, this.meds.length === 0 ? cardText(this.lang).noMeds :
          this.meds.map((m: Medication) => medLine(m)).join('\n'))
        if (this.cardProfile().contacts.length > 0 && shownOnCard(this.cardProfile(), CardField.CONTACTS)) {
          this.cardLine(cardText(this.lang).contacts,
            this.cardProfile().contacts.map((c: Contact) => `${c.name} (${c.relation}) ${c.phone}`).join('\n'))
        }
        if (this.cardProfile().notes.length > 0 && shownOnCard(this.cardProfile(), CardField.NOTES)) {
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

        // First-responder view (B5): the top of the tab, for whoever arrives to help.
        NavRow({
          icon: $r('app.media.ic_doctor'),
          title: $r('app.string.em_resp_title'),
          subtitle: $r('app.string.em_resp_open_sub'),
          onTap: () => {
            this.navStack.pushPathByName(Routes.RESPONDER, null);
          }
        })

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

        this.nearbyRow()

        if (this.profile === undefined) {
          Text($r('app.string.emergency_no_profile'))
            .fontSize($r('app.float.font_small'))
            .fontColor($r('app.color.ink_3'))
            .padding(20)
        } else {
          SectionHeader({ title: $r('app.string.em_full_card') })
          this.languageRow()
          if (this.canSpeak) {
            SecondaryButton({
              label: this.speaking ? $r('app.string.em_read_stop') : $r('app.string.em_read_aloud'),
              icon: $r('app.media.ic_wave'),
              onTap: () => {
                this.readAloud();
              }
            })
          }
          // Keyed on the language: cardLine() gets its labels by value, so the card is rebuilt when it changes.
          ForEach([this.lang], (l: string) => {
            this.card()
          }, (l: string) => `card-${l}`)

          // QR → card viewer link; the card travels in the #fragment and is rendered on the scanner's phone
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
            .accessibilityGroup(true)
            .accessibilityDescription(this.showQr ? 'Expanded' : 'Collapsed')
            .onClick(() => {
              this.showQr = !this.showQr;
              if (this.showQr) {
                this.refreshShare();
              }
            })
            if (this.showQr) {
              QRCode(this.currentCardLink())
                .width(240)
                .height(240)
                .color($r('app.color.card_fixed_ink'))
                .backgroundColor($r('app.color.card_fixed_bg'))
              // Encrypted short link vs. legacy link with the card inside: the hint must say which is true.
              Text(this.shareUrl !== '' ? $r('app.string.emergency_qr_hint_encrypted') : $r('app.string.emergency_qr_hint'))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.ink_3'))
                .textAlign(TextAlign.Center)
              // Same link as text, for when the QR can't be scanned (or to send it in a chat)
              Text(this.sharing ? this.str($r('app.string.share_preparing')) : this.currentCardLink())
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.brand_accent'))
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .wordBreak(WordBreak.BREAK_ALL)
                .onClick(() => {
                  this.openCard();
                })
              SecondaryButton({
                label: $r('app.string.emergency_card_open'),
                icon: $r('app.media.ic_share'),
                onTap: () => {
                  this.openCard();
                }
              })
              QuietButton({
                label: $r('app.string.emergency_card_copy'),
                onTap: () => {
                  this.copyCard();
                }
              })
              if (this.shareUrl !== '') {
                Text($r('app.string.share_card_caption'))
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.ink_3'))
                  .textAlign(TextAlign.Center)
                Text($r('app.string.share_remove'))
                  .fontSize($r('app.float.font_small'))
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.brand_text'))
                  .height($r('app.float.touch_min'))
                  .onClick(() => {
                    this.confirmRemove();
                  })
              }
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
