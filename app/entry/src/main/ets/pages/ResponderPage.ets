// First-responder view (Workstream B5, route `responder`): a full-screen page for the person who arrives to help.
// Order: who and what · do not give · use instead · immediate care · current medicines · details and contacts.
// Always light (card_fixed_*), large type. Everything comes from data on this phone (emergency/Responder.ets,
// emergency/EmergencyDetails.ets): no LLM text, and opening it makes no network request. Fields the user switched
// off for the card are left out here too, because this page is reachable without unlocking the app.

import { LocalStore } from '../data/LocalStore';
import { CardField, Contact, Profile } from '../model/Profile';
import { Medication } from '../model/Medication';
import { CardText, cardLabels, cardText } from '../common/CardStrings';
import { emergencyFor, systemCountry } from '../common/EmergencyNumbers';
import { CardRow, detailRows, shownOnCard } from '../emergency/EmergencyDetails';
import {
  AvoidGroup, InsteadGroup, MedRow, ageYears, careNotes, doNotGive, medRows, recentRiskyIntake, useInstead
} from '../emergency/Responder';
import { IntakeRecord } from '../drugs/DrugIntake';
import { RiskBadge } from '../components/Common';
import { dateTime } from '../common/Format';
import { dial } from '../common/Dialer';
import { toast } from '../common/Toast';
import { AppLock } from '../common/AppLock';

// Same setting DrugIntake writes the last risky intake to (drugs/DrugIntake.ets KEY_LAST).
const RISKY_INTAKE_KEY: string = 'riskyIntakeLast';

class CallTarget {
  label: string;
  phone: string;

  constructor(label: string, phone: string) {
    this.label = label;
    this.phone = phone;
  }
}

@ComponentV2
export struct ResponderPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local profile: Profile | undefined = undefined;
  @Local meds: Medication[] = [];
  @Local intake: IntakeRecord | undefined = undefined;
  private readonly avoid: AvoidGroup[] = doNotGive();
  private readonly instead: InsteadGroup[] = useInstead();

  aboutToAppear(): void {
    this.load();
  }

  // Opened from the lock screen: lock again when the responder view closes (same as the bystander guide).
  aboutToDisappear(): void {
    AppLock.endEmergency();
  }

  private async load(): Promise<void> {
    this.profile = await LocalStore.get().getProfile();
    this.meds = await LocalStore.get().listMeds();
    this.intake = recentRiskyIntake(await LocalStore.get().getSetting(RISKY_INTAKE_KEY, ''), Date.now());
  }

  private p(): Profile {
    const empty: Profile = { condition: 'LQTS', genotype: 'UNKNOWN', hasIcd: false, notes: '', contacts: [] };
    return this.profile ?? empty;
  }

  private t(): CardText {
    return cardText(this.p().cardLanguage);
  }

  private ambulance(): string {
    return emergencyFor(this.p().country ?? systemCountry()).ambulance;
  }

  private whoChips(): string[] {
    const chips: string[] = [];
    const age: number | undefined = shownOnCard(this.p(), CardField.DATE_OF_BIRTH) ?
      ageYears(this.p().dateOfBirth, Date.now()) : undefined;
    if (age !== undefined) {
      chips.push(`${cardLabels(this.p().cardLanguage).age} ${age}`);
    }
    chips.push(`${this.t().genotype}: ${this.p().genotype === 'UNKNOWN' ? '?' : this.p().genotype}`);
    return chips;
  }

  private icdLine(): string {
    if (!this.p().hasIcd) {
      return this.t().icdNo;
    }
    const model: string = shownOnCard(this.p(), CardField.ICD_MODEL) ? (this.p().icdModel ?? '').trim() : '';
    return model.length > 0 ? `${this.t().icdYes}: ${model}` : this.t().icdYes;
  }

  // Detail rows except the ones already in the header (date of birth → age, ICD model → ICD line).
  private details(): CardRow[] {
    return detailRows(this.p(), cardLabels(this.p().cardLanguage), Date.now())
      .filter((r: CardRow) => r.id !== CardField.DATE_OF_BIRTH && r.id !== CardField.ICD_MODEL);
  }

  private callTargets(): CallTarget[] {
    const out: CallTarget[] = [];
    if (shownOnCard(this.p(), CardField.CONTACTS)) {
      this.p().contacts.forEach((c: Contact) => {
        out.push(new CallTarget(c.relation === '' ? c.name : `${c.name} (${c.relation})`, c.phone));
      });
    }
    const cardioPhone: string = (this.p().cardiologistPhone ?? '').trim();
    if (cardioPhone.length > 0 && shownOnCard(this.p(), CardField.CARDIOLOGIST)) {
      const name: string = (this.p().cardiologistName ?? '').trim();
      out.push(new CallTarget(`${cardLabels(this.p().cardLanguage).cardiologist}${name === '' ? '' : ` ${name}`}`,
        cardioPhone));
    }
    return out;
  }

  private async call(number: string): Promise<void> {
    if (!(await dial(number))) {
      toast(this.getUIContext(), $r('app.string.emergency_dial_failed'));
    }
  }

  @Builder
  sectionTitle(title: Resource) {
    Text(title)
      .fontSize($r('app.float.font_title_3'))
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.card_fixed_ink'))
      .margin({ top: 8 })
  }

  @Builder
  header() {
    Column({ space: 10 }) {
      Row({ space: 4 }) {
        Image($r('app.media.ic_chevron_left'))
          .width($r('app.float.touch_min'))
          .height($r('app.float.touch_min'))
          .padding(12)
          .fillColor($r('app.color.on_accent'))
          .accessibilityText('Back')
          .onClick(() => {
            this.navStack.pop();
          })
        Text(this.t().title)
          .fontSize($r('app.float.font_badge'))
          .fontWeight(800)
          .letterSpacing(0.8)
          .fontColor($r('app.color.on_accent'))
          .layoutWeight(1)
      }
      .width('100%')
      Column({ space: 10 }) {
        if ((this.p().name ?? '').length > 0 && shownOnCard(this.p(), CardField.NAME)) {
          Text(this.p().name ?? '')
            .fontSize($r('app.float.font_title_1'))
            .fontWeight(800)
            .fontColor($r('app.color.on_accent'))
        }
        Text(this.t().condition)
          .fontSize($r('app.float.font_title_3'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.on_accent'))
        Row({ space: 8 }) {
          ForEach(this.whoChips(), (c: string) => {
            Text(c)
              .fontSize($r('app.float.font_small'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.card_fixed_alert'))
              .backgroundColor($r('app.color.card_fixed_bg'))
              .borderRadius(14)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          }, (c: string) => c)
        }
        Text(this.icdLine())
          .fontSize($r('app.float.font_subtitle'))
          .fontWeight(this.p().hasIcd ? FontWeight.Bold : FontWeight.Normal)
          .fontColor($r('app.color.on_accent'))
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 12 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 8, right: 20, top: 8, bottom: 20 })
    .backgroundColor($r('app.color.card_fixed_alert'))
  }

  @Builder
  avoidSection() {
    Column({ space: 12 }) {
      Text($r('app.string.em_resp_avoid'))
        .fontSize($r('app.float.font_title'))
        .fontWeight(800)
        .fontColor($r('app.color.card_fixed_alert'))
      Text($r('app.string.em_resp_avoid_sub'))
        .fontSize($r('app.float.font_small'))
        .fontColor($r('app.color.card_fixed_ink_2'))
      ForEach(this.avoid, (g: AvoidGroup) => {
        Column({ space: 2 }) {
          Text(g.title)
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.card_fixed_ink'))
          Text(g.drugs.join(', '))
            .fontSize($r('app.float.font_subtitle'))
            .fontColor($r('app.color.card_fixed_ink'))
          if (g.note.length > 0) {
            Text(g.note)
              .fontSize($r('app.float.font_small'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.card_fixed_alert'))
          }
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      }, (g: AvoidGroup) => g.title)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor($r('app.color.card_fixed_alert_tint'))
    .border({ width: { left: 6 }, color: $r('app.color.card_fixed_alert') })
    .borderRadius(12)
  }

  @Builder
  insteadSection() {
    Column({ space: 12 }) {
      this.sectionTitle($r('app.string.em_resp_instead'))
      ForEach(this.instead, (g: InsteadGroup) => {
        Column({ space: 4 }) {
          Text($r('app.string.em_resp_instead_of', g.classes.join(', ').toLowerCase()))
            .fontSize($r('app.float.font_small'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.card_fixed_ink_2'))
          Text(g.options.join(', '))
            .fontSize($r('app.float.font_subtitle'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.card_fixed_ink'))
          Text(g.replaces.join(', '))
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.card_fixed_ink_3'))
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      }, (g: InsteadGroup) => g.options.join(','))
      Text($r('app.string.em_resp_instead_sub'))
        .fontSize($r('app.float.font_small'))
        .fontColor($r('app.color.card_fixed_ink_2'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  careSection() {
    Column({ space: 10 }) {
      this.sectionTitle($r('app.string.em_resp_care'))
      ForEach(careNotes(this.p(), this.meds, this.ambulance()), (n: string, i: number) => {
        Row({ space: 10 }) {
          Text(`${i + 1}`)
            .fontSize($r('app.float.font_body'))
            .fontWeight(800)
            .fontColor($r('app.color.card_fixed_bg'))
            .textAlign(TextAlign.Center)
            .width(28)
            .height(28)
            .borderRadius(14)
            .backgroundColor($r('app.color.card_fixed_ink'))
          Text(n)
            .fontSize($r('app.float.font_subtitle'))
            .fontColor($r('app.color.card_fixed_ink'))
            .layoutWeight(1)
        }
        .alignItems(VerticalAlign.Top)
        .width('100%')
      }, (n: string, i: number) => `${i}-${n}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  medsSection() {
    Column({ space: 10 }) {
      this.sectionTitle($r('app.string.em_resp_meds'))
      if (this.intake !== undefined) {
        Column({ space: 2 }) {
          Text($r('app.string.em_resp_last_risky_label'))
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.card_fixed_alert'))
          Text($r('app.string.em_resp_last_risky', this.intake.name, dateTime(this.intake.ts, Date.now())))
            .fontSize($r('app.float.font_subtitle'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.card_fixed_ink'))
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(12)
        .backgroundColor($r('app.color.card_fixed_alert_tint'))
        .borderRadius(12)
      }
      if (this.meds.length === 0) {
        Text(this.t().noMeds)
          .fontSize($r('app.float.font_subtitle'))
          .fontColor($r('app.color.card_fixed_ink'))
      }
      ForEach(medRows(this.meds), (m: MedRow, i: number) => {
        Row({ space: 10 }) {
          Text(m.line)
            .fontSize($r('app.float.font_subtitle'))
            .fontColor($r('app.color.card_fixed_ink'))
            .layoutWeight(1)
          RiskBadge({ risk: m.risk, compact: true })
        }
        .width('100%')
        .padding({ top: 6, bottom: 6 })
      }, (m: MedRow, i: number) => `${i}-${m.line}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  detailsSection() {
    Column({ space: 12 }) {
      this.sectionTitle($r('app.string.em_resp_details'))
      ForEach(this.details(), (r: CardRow, i: number) => {
        Column({ space: 2 }) {
          Text(r.label.toUpperCase())
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.card_fixed_ink_3'))
          Text(r.value)
            .fontSize($r('app.float.font_subtitle'))
            .fontColor($r('app.color.card_fixed_ink'))
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      }, (r: CardRow, i: number) => `${i}-${r.id}-${r.label}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  contactsSection() {
    Column({ space: 10 }) {
      this.sectionTitle($r('app.string.em_resp_contacts'))
      ForEach(this.callTargets(), (c: CallTarget) => {
        Row({ space: 10 }) {
          Image($r('app.media.ic_phone')).width(22).height(22).fillColor($r('app.color.card_fixed_ink'))
          Column({ space: 2 }) {
            Text(c.label)
              .fontSize($r('app.float.font_body'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.card_fixed_ink'))
            Text(c.phone)
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.card_fixed_ink_2'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .constraintSize({ minHeight: $r('app.float.button_height_sheet') })
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .border({ width: 1.5, color: $r('app.color.card_fixed_border') })
        .borderRadius($r('app.float.radius_btn'))
        .accessibilityGroup(true)
        .accessibilityText(`Call ${c.label}, ${c.phone}`)
        .onClick(() => {
          this.call(c.phone);
        })
      }, (c: CallTarget) => `${c.label}-${c.phone}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 20 }) {
          this.header()
          Column({ space: 20 }) {
            this.avoidSection()
            this.insteadSection()
            this.careSection()
            this.medsSection()
            if (this.details().length > 0) {
              this.detailsSection()
            }
            if (this.callTargets().length > 0) {
              this.contactsSection()
            }
            Text($r('app.string.em_resp_source'))
              .fontSize($r('app.float.font_micro'))
              .fontColor($r('app.color.card_fixed_ink_3'))
            Text($r('app.string.em_resp_offline'))
              .fontSize($r('app.float.font_micro'))
              .fontColor($r('app.color.card_fixed_ink_3'))
          }
          .padding({ left: $r('app.float.space_screen'), right: $r('app.float.space_screen'), bottom: 32 })
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.card_fixed_bg'))
  }
}
