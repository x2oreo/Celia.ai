// Onboarding (F-01): shown first when no profile exists. 4 short steps → LocalStore.saveProfile.
//   1. you: name, genotype, ICD   2. medicines   3. emergency contacts   4. country + notes

import { LocalStore } from '../data/LocalStore';
import { Contact, Genotype, Profile } from '../model/Profile';
import { Medication } from '../model/Medication';
import { EMERGENCY_NUMBERS, EmergencyInfo, emergencyFor, systemCountry } from '../common/EmergencyNumbers';
import { AddMedForm } from '../components/AddMedForm';
import { PrimaryButton, RiskBadge } from '../components/Common';
import { medRisk } from './MedicinesPage';
import { Logger } from '../common/Logger';
import { common } from '@kit.AbilityKit';
import { SosService } from '../emergency/SosService';
import { toast } from '../common/Toast';

const log: Logger = new Logger('Onboarding');
const STEPS: number = 4;
const GENOTYPES: Genotype[] = ['LQT1', 'LQT2', 'LQT3', 'UNKNOWN'];

export function validPhone(phone: string): boolean {
  return phone.replace(/[^0-9]/g, '').length >= 6;
}

@ComponentV2
export struct OnboardingPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local step: number = 0;
  @Local name: string = '';
  @Local genotype: Genotype = 'UNKNOWN';
  @Local hasIcd: boolean = false;
  @Local meds: Medication[] = [];
  @Local contacts: Contact[] = [];
  @Local cName: string = '';
  @Local cPhone: string = '';
  @Local cRelation: string = '';
  @Local country: string = '';
  @Local notes: string = '';

  aboutToAppear(): void {
    const sys: string = systemCountry();
    this.country = emergencyFor(sys).code === '' ? 'PL' : sys;
    this.reloadMeds();
  }

  private async reloadMeds(): Promise<void> {
    this.meds = await LocalStore.get().listMeds();
  }

  private addContact(): void {
    if (this.cName.trim().length === 0 || !validPhone(this.cPhone)) {
      toast(this.getUIContext(), $r('app.string.onb_contact_invalid'));
      return;
    }
    const c: Contact = { name: this.cName.trim(), phone: this.cPhone.trim(), relation: this.cRelation.trim() };
    this.contacts = this.contacts.concat([c]);
    this.cName = '';
    this.cPhone = '';
    this.cRelation = '';
  }

  private async finish(): Promise<void> {
    const profile: Profile = {
      condition: 'LQTS',
      genotype: this.genotype,
      hasIcd: this.hasIcd,
      notes: this.notes.trim(),
      contacts: this.contacts,
      name: this.name.trim(),
      country: this.country,
      cardLanguage: 'en'
    };
    await LocalStore.get().saveProfile(profile);
    log.info(`profile saved: ${profile.genotype}, ${this.meds.length} meds, ${profile.contacts.length} contacts`);
    this.navStack.pop();
    // Ask for location now, calmly, so it is never a pop-up during an SOS countdown.
    SosService.askLocationPermission(this.getUIContext().getHostContext() as common.UIAbilityContext);
  }

  private next(): void {
    if (this.step < STEPS - 1) {
      this.step++;
    } else {
      this.finish();
    }
  }

  @Builder
  heading(title: Resource, subtitle: Resource) {
    Column({ space: 6 }) {
      Text(title)
        .fontSize($r('app.float.font_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Text(subtitle)
        .fontSize($r('app.float.font_small'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  field(value: string, hint: Resource, type: InputType, onChange: (v: string) => void) {
    TextInput({ text: value, placeholder: hint })
      .type(type)
      .height(48)
      .backgroundColor($r('app.color.field_bg'))
      .onChange(onChange)
  }

  @Builder
  stepYou() {
    Column({ space: 16 }) {
      Image($r('app.media.ic_tab_heart')).width(56).height(56).fillColor($r('app.color.brand_accent'))
      this.heading($r('app.string.onboarding_title'), $r('app.string.onboarding_subtitle'))
      this.field(this.name, $r('app.string.onb_name_hint'), InputType.Normal, (v: string) => {
        this.name = v;
      })
      Text($r('app.string.onb_genotype'))
        .fontSize($r('app.float.font_small'))
        .fontColor($r('sys.color.font_secondary'))
      Row({ space: 8 }) {
        ForEach(GENOTYPES, (g: Genotype) => {
          Text(g === 'UNKNOWN' ? 'Not sure' : g)
            .fontSize($r('app.float.font_body'))
            .fontColor(this.genotype === g ? $r('app.color.on_accent') : $r('sys.color.font_primary'))
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(44)
            .backgroundColor(this.genotype === g ? $r('app.color.brand_accent') : $r('app.color.card_bg'))
            .borderRadius($r('app.float.radius_s'))
            .onClick(() => {
              this.genotype = g;
            })
        }, (g: Genotype) => g)
      }
      .width('100%')
      Row() {
        Column({ space: 2 }) {
          Text($r('app.string.onb_icd'))
            .fontSize($r('app.float.font_body'))
            .fontColor($r('sys.color.font_primary'))
          Text($r('app.string.onb_icd_hint'))
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.hasIcd })
          .selectedColor($r('app.color.brand_accent'))
          .onChange((on: boolean) => {
            this.hasIcd = on;
          })
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius($r('app.float.radius_m'))
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  stepMeds() {
    Column({ space: 16 }) {
      this.heading($r('app.string.onb_meds_title'), $r('app.string.onb_meds_subtitle'))
      AddMedForm({
        onAdded: () => {
          this.reloadMeds();
        }
      })
      ForEach(this.meds, (m: Medication) => {
        Row({ space: 8 }) {
          Text(m.dose === '' ? m.name : `${m.name} · ${m.dose}`)
            .fontSize($r('app.float.font_body'))
            .fontColor($r('sys.color.font_primary'))
            .layoutWeight(1)
          RiskBadge({ risk: medRisk(m), compact: true })
        }
        .width('100%')
        .padding(12)
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius($r('app.float.radius_s'))
      }, (m: Medication) => `${m.id}`)
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  stepContacts() {
    Column({ space: 12 }) {
      this.heading($r('app.string.onb_contacts_title'), $r('app.string.onb_contacts_subtitle'))
      this.field(this.cName, $r('app.string.onb_contact_name'), InputType.Normal, (v: string) => {
        this.cName = v;
      })
      this.field(this.cPhone, $r('app.string.onb_contact_phone'), InputType.PhoneNumber, (v: string) => {
        this.cPhone = v;
      })
      this.field(this.cRelation, $r('app.string.onb_contact_relation'), InputType.Normal, (v: string) => {
        this.cRelation = v;
      })
      PrimaryButton({
        label: $r('app.string.onb_contact_add'),
        icon: $r('app.media.ic_plus'),
        active: this.cName.trim().length > 0 && validPhone(this.cPhone),
        onTap: () => this.addContact()
      })
      ForEach(this.contacts, (c: Contact) => {
        Row({ space: 8 }) {
          Image($r('app.media.ic_phone')).width(18).height(18).fillColor($r('app.color.brand_accent'))
          Text(`${c.name}${c.relation === '' ? '' : ` (${c.relation})`} · ${c.phone}`)
            .fontSize($r('app.float.font_body'))
            .fontColor($r('sys.color.font_primary'))
            .layoutWeight(1)
          Image($r('app.media.ic_close'))
            .width(18)
            .height(18)
            .fillColor($r('sys.color.icon_secondary'))
            .accessibilityText($r('app.string.a11y_remove'))
            .onClick(() => {
              this.contacts = this.contacts.filter((x: Contact) => x !== c);
            })
        }
        .width('100%')
        .padding(12)
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius($r('app.float.radius_s'))
      }, (c: Contact) => `${c.name}-${c.phone}`)
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  stepFinish() {
    Column({ space: 16 }) {
      this.heading($r('app.string.onb_finish_title'), $r('app.string.onb_finish_subtitle'))
      Text($r('app.string.onb_country'))
        .fontSize($r('app.float.font_small'))
        .fontColor($r('sys.color.font_secondary'))
      Select(EMERGENCY_NUMBERS.map((e: EmergencyInfo) => {
        const opt: SelectOption = { value: `${e.name} (${e.ambulance})` };
        return opt;
      }))
        .selected(Math.max(0, EMERGENCY_NUMBERS.findIndex((e: EmergencyInfo) => e.code === this.country)))
        .value(`${emergencyFor(this.country).name} (${emergencyFor(this.country).ambulance})`)
        .width('100%')
        .onSelect((index: number) => {
          this.country = EMERGENCY_NUMBERS[index].code;
        })
      TextArea({ text: this.notes, placeholder: $r('app.string.onb_notes_hint') })
        .height(120)
        .backgroundColor($r('app.color.field_bg'))
        .onChange((v: string) => {
          this.notes = v;
        })
      Text($r('app.string.onb_privacy'))
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination() {
      Column() {
        // Progress
        Row({ space: 6 }) {
          ForEach([0, 1, 2, 3], (i: number) => {
            Column()
              .height(4)
              .layoutWeight(1)
              .borderRadius(2)
              .backgroundColor(i <= this.step ? $r('app.color.brand_accent') : $r('app.color.divider'))
          }, (i: number) => `${i}`)
        }
        .width('100%')
        .padding({ top: 16, bottom: 16 })

        Scroll() {
          Column() {
            if (this.step === 0) {
              this.stepYou()
            } else if (this.step === 1) {
              this.stepMeds()
            } else if (this.step === 2) {
              this.stepContacts()
            } else {
              this.stepFinish()
            }
          }
          .width('100%')
          .padding({ bottom: 16 })
        }
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Off)

        Column({ space: 8 }) {
          PrimaryButton({
            label: this.step === STEPS - 1 ? $r('app.string.onb_done') : $r('app.string.onboarding_continue'),
            onTap: () => this.next()
          })
          Row() {
            if (this.step > 0) {
              Text($r('app.string.onb_back'))
                .fontSize($r('app.float.font_body'))
                .fontColor($r('sys.color.font_secondary'))
                .padding(8)
                .onClick(() => {
                  this.step--;
                })
            }
            Blank()
            if (this.step === 1 || this.step === 2) {
              Text($r('app.string.onb_skip'))
                .fontSize($r('app.float.font_body'))
                .fontColor($r('sys.color.font_secondary'))
                .padding(8)
                .onClick(() => this.next())
            }
          }
          .width('100%')
          Text($r('app.string.disclaimer'))
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('sys.color.font_tertiary'))
            .textAlign(TextAlign.Center)
        }
        .padding({ bottom: 8 })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 20, right: 20 })
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.page_bg'))
    .onBackPressed(() => {
      if (this.step > 0) {
        this.step--;
      }
      return true; // onboarding must be completed, not dismissed
    })
  }
}
