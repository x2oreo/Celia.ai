// First-responder view (Workstream B5, route `responder`): the full emergency card (DESIGN.md §11, v3), read in
// layers: glance (who, call, do not give) · critical (contacts, medicines, details) · for clinicians (protocol,
// torsades, do not use, genotype notes, use instead) · about long QT (folded). Always light (card_fixed_*), large
// type. Everything comes from data on this phone (emergency/Responder.ets, emergency/LqtsFacts.ets,
// emergency/EmergencyDetails.ets): no LLM text, and opening it makes no network request. Fields the user switched
// off for the card are left out here too, because this page is reachable without unlocking the app.

import { LocalStore } from '../data/LocalStore';
import { CardField, Contact, Profile } from '../model/Profile';
import { Medication } from '../model/Medication';
import { CardText, cardLabels, cardText } from '../common/CardStrings';
import { emergencyFor, systemCountry } from '../common/EmergencyNumbers';
import { CardRow, detailRows, shownOnCard } from '../emergency/EmergencyDetails';
import {
  AvoidGroup, InsteadGroup, MedRow, ageYears, doNotGive, medRows, nameInitial, recentRiskyIntake, takesQtRiskMed,
  useInstead
} from '../emergency/Responder';
import { DO_NOT_USE, TORSADES_INTRO, TORSADES_STEPS, genotypeFacts, protocolSteps } from '../emergency/LqtsFacts';
import { AboutLqts, AvoidPanel, CardCaps, CardIdentity, ClinicianBlock } from '../components/EmergencyCardParts';
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
  cardiologist: boolean;

  constructor(label: string, phone: string, cardiologist: boolean) {
    this.label = label;
    this.phone = phone;
    this.cardiologist = cardiologist;
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
    chips.push(this.icdLine());
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
    const rows: CardRow[] = detailRows(this.p(), cardLabels(this.p().cardLanguage), Date.now())
      .filter((r: CardRow) => r.id !== CardField.DATE_OF_BIRTH && r.id !== CardField.ICD_MODEL);
    const notes: string = this.p().notes.trim();
    if (notes.length > 0 && shownOnCard(this.p(), CardField.NOTES)) {
      const r: CardRow = { id: CardField.NOTES, label: this.t().notes, value: notes };
      rows.push(r);
    }
    return rows;
  }

  // Cardiologist first: the person who knows this heart best.
  private callTargets(): CallTarget[] {
    const out: CallTarget[] = [];
    const cardioPhone: string = (this.p().cardiologistPhone ?? '').trim();
    if (cardioPhone.length > 0 && shownOnCard(this.p(), CardField.CARDIOLOGIST)) {
      const name: string = (this.p().cardiologistName ?? '').trim();
      out.push(new CallTarget(`${cardLabels(this.p().cardLanguage).cardiologist}${name === '' ? '' : ` ${name}`}`,
        cardioPhone, true));
    }
    if (shownOnCard(this.p(), CardField.CONTACTS)) {
      this.p().contacts.forEach((c: Contact) => {
        out.push(new CallTarget(c.relation === '' ? c.name : `${c.name} (${c.relation})`, c.phone, false));
      });
    }
    return out;
  }

  private shownName(): string {
    return shownOnCard(this.p(), CardField.NAME) ? (this.p().name ?? '').trim() : '';
  }

  private async call(number: string): Promise<void> {
    if (!(await dial(number))) {
      toast(this.getUIContext(), $r('app.string.emergency_dial_failed'));
    }
  }

  @Builder
  sectionTitle(title: Resource) {
    CardCaps({ text: title })
  }

  @Builder
  header() {
    Column({ space: 12 }) {
      Row({ space: 4 }) {
        Image($r('app.media.ic_chevron_left'))
          .width($r('app.float.touch_min'))
          .height($r('app.float.touch_min'))
          .padding(12)
          .margin({ left: -12 })
          .fillColor($r('app.color.card_fixed_ink'))
          .accessibilityText('Back')
          .onClick(() => {
            this.navStack.pop();
          })
        CardCaps({ text: this.t().title, alert: true })
      }
      .width('100%')
      CardIdentity({
        initial: nameInitial(this.shownName()),
        name: this.shownName(),
        condition: this.t().condition,
        chips: this.whoChips(),
        photo: shownOnCard(this.p(), CardField.PHOTO)
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  callButton() {
    Row({ space: 10 }) {
      Image($r('app.media.ic_phone')).width(24).height(24).fillColor($r('app.color.on_accent'))
      Text($r('app.string.em_resp_call_number', this.ambulance()))
        .fontSize($r('app.float.font_title_3'))
        .fontWeight(800)
        .fontColor($r('app.color.on_accent'))
    }
    .width('100%')
    .height(56)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.danger'))
    .borderRadius($r('app.float.radius_btn'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
    .accessibilityGroup(true)
    .onClick(() => {
      this.call(this.ambulance());
    })
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
  medsSection() {
    Column({ space: 10 }) {
      this.sectionTitle($r('app.string.em_resp_meds'))
      if (takesQtRiskMed(medRows(this.meds))) {
        Row({ space: 8 }) {
          Image($r('app.media.ic_risk_known')).width(18).height(18).fillColor($r('app.color.card_fixed_alert'))
          Text($r('app.string.em_resp_qt_banner'))
            .fontSize($r('app.float.font_small'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.card_fixed_ink'))
            .layoutWeight(1)
        }
        .alignItems(VerticalAlign.Top)
        .width('100%')
        .padding(12)
        .backgroundColor($r('app.color.card_fixed_alert_tint'))
        .border({ width: 1, color: $r('app.color.card_fixed_alert_border') })
        .borderRadius(16)
      }
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
        .border({ width: 1, color: $r('app.color.card_fixed_border') })
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
          Column({ space: 20 }) {
            // 1 · Glance
            this.header()
            this.callButton()
            AvoidPanel({ title: $r('app.string.em_resp_avoid'), sub: $r('app.string.em_resp_avoid_sub'), groups: this.avoid, firstGroups: 4 })
            // 2 · Critical
            if (this.callTargets().length > 0) {
              this.contactsSection()
            }
            this.medsSection()
            if (this.details().length > 0) {
              this.detailsSection()
            }
            // 3 · For clinicians
            ClinicianBlock({
              steps: protocolSteps(this.ambulance(), this.p().hasIcd),
              torsadesIntro: TORSADES_INTRO,
              torsades: TORSADES_STEPS,
              doNotUse: DO_NOT_USE,
              typeTitle: $r('app.string.em_clin_type_notes', this.p().genotype === 'UNKNOWN' ? 'unknown type' : this.p().genotype),
              typeNotes: genotypeFacts(this.p().genotype).emergencyNotes
            })
            this.insteadSection()
            // 4 · About long QT (folded)
            AboutLqts({ facts: genotypeFacts(this.p().genotype) })
            Text($r('app.string.em_resp_source'))
              .fontSize($r('app.float.font_micro'))
              .fontColor($r('app.color.card_fixed_ink_3'))
            Text($r('app.string.em_resp_offline'))
              .fontSize($r('app.float.font_micro'))
              .fontColor($r('app.color.card_fixed_ink_3'))
          }
          .padding({ left: $r('app.float.space_screen'), right: $r('app.float.space_screen'), top: 8, bottom: 32 })
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
