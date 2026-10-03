// Editor for the emergency details (Workstream B4): date of birth, sex, blood type, allergies, ICD model,
// cardiologist, hospital, extra fields and the per-field "show on card" switches.
// Contract: used by pages/EmergencyProfilePage.ets and by onboarding. It never saves; the host saves onChange.
// Every change emits a new Profile (a deep copy), so hosts can store it as is.

import { LengthMetrics } from '@kit.ArkUI';
import { BLOOD_TYPES, CardField, ExtraField, Profile, Sex } from '../model/Profile';
import { MAX_EXTRA, cloneProfile, parseList, shownOnCard, validBirthDate, withShown } from '../emergency/EmergencyDetails';

const SEXES: Sex[] = ['FEMALE', 'MALE', 'OTHER'];

@ComponentV2
export struct EmergencyDetailsForm {
  @Param profile: Profile | undefined = undefined;
  @Event onChange: (profile: Profile) => void = (profile: Profile) => {
  };
  // Text being typed. Kept locally so the host's echo of our own change never rewrites what is being typed.
  @Local dob: string = '';
  @Local dobBad: boolean = false;
  @Local allergies: string = '';
  @Local icdModel: string = '';
  @Local cardioName: string = '';
  @Local cardioPhone: string = '';
  @Local hospital: string = '';
  @Local extraLabel: string = '';
  @Local extraValue: string = '';
  private lastEmitted: Profile | undefined = undefined;

  aboutToAppear(): void {
    this.syncFromProfile();
  }

  @Monitor('profile')
  onProfile(): void {
    if (this.profile !== this.lastEmitted) {
      this.syncFromProfile();   // loaded or replaced by the host, not our own edit
    }
  }

  private syncFromProfile(): void {
    const p: Profile | undefined = this.profile;
    this.dob = p?.dateOfBirth ?? '';
    this.dobBad = false;
    this.allergies = (p?.allergies ?? []).join(', ');
    this.icdModel = p?.icdModel ?? '';
    this.cardioName = p?.cardiologistName ?? '';
    this.cardioPhone = p?.cardiologistPhone ?? '';
    this.hospital = p?.hospital ?? '';
  }

  private edit(mutate: (p: Profile) => void): void {
    if (this.profile === undefined) {
      return;
    }
    const p: Profile = cloneProfile(this.profile);
    mutate(p);
    this.lastEmitted = p;
    this.onChange(p);
  }

  private optional(v: string): string | undefined {
    const t: string = v.trim();
    return t.length > 0 ? t : undefined;
  }

  private shown(field: string): boolean {
    return this.profile === undefined ? true : shownOnCard(this.profile, field);
  }

  private sexLabel(s: Sex): Resource {
    return s === 'FEMALE' ? $r('app.string.em_sex_female') : s === 'MALE' ? $r('app.string.em_sex_male') :
      $r('app.string.em_sex_other');
  }

  @Styles
  groupBox() {
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 16 })
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_m'))
  }

  // Caps label + "Show on card" switch, the header of every field group.
  @Builder
  fieldHeader(label: Resource, field: string) {
    Row({ space: 8 }) {
      Text(label)
        .fontSize($r('app.float.font_caption'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink_3'))
        .layoutWeight(1)
      Text($r('app.string.em_show_on_card'))
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.ink_3'))
      Toggle({ type: ToggleType.Switch, isOn: this.shown(field) })
        .selectedColor($r('app.color.brand_accent'))
        .accessibilityText($r('app.string.em_show_on_card'))
        .onChange((on: boolean) => {
          this.edit((p: Profile) => {
            p.hiddenOnCard = withShown(p.hiddenOnCard, field, on);
          });
        })
    }
    .width('100%')
    .height($r('app.float.touch_min'))
  }

  build() {
    Column({ space: 12 }) {
      // Date of birth
      Column({ space: 8 }) {
        this.fieldHeader($r('app.string.em_dob'), CardField.DATE_OF_BIRTH)
        FieldInput({ text: this.dob, hint: $r('app.string.em_dob_hint'), inputType: InputType.Normal, onInput: (v: string) => {
          this.dob = v;
          this.dobBad = !validBirthDate(v, Date.now());
          if (!this.dobBad) {
            this.edit((p: Profile) => {
              p.dateOfBirth = this.optional(v);
            });
          }
        } })
        if (this.dobBad && this.dob.trim().length >= 10) {
          Text($r('app.string.em_dob_invalid'))
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.risk_possible_text'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .groupBox()

      // Sex
      Column({ space: 8 }) {
        this.fieldHeader($r('app.string.em_sex'), CardField.SEX)
        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
          ForEach(SEXES, (s: Sex) => {
            ChoiceChip({ label: this.sexLabel(s), selected: this.profile?.sex === s, onTap: () => {
              this.edit((p: Profile) => {
                p.sex = p.sex === s ? undefined : s;
              });
            } })
          }, (s: Sex) => s)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .groupBox()

      // Blood type
      Column({ space: 8 }) {
        this.fieldHeader($r('app.string.em_blood'), CardField.BLOOD_TYPE)
        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
          ForEach(BLOOD_TYPES, (b: string) => {
            ChoiceChip({ label: b, selected: this.profile?.bloodType === b, onTap: () => {
              this.edit((p: Profile) => {
                p.bloodType = p.bloodType === b ? undefined : b;
              });
            } })
          }, (b: string) => b)
          ChoiceChip({ label: $r('app.string.em_blood_unknown'), selected: (this.profile?.bloodType ?? '') === '', onTap: () => {
            this.edit((p: Profile) => {
              p.bloodType = undefined;
            });
          } })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .groupBox()

      // Allergies
      Column({ space: 8 }) {
        this.fieldHeader($r('app.string.em_allergies'), CardField.ALLERGIES)
        FieldInput({ text: this.allergies, hint: $r('app.string.em_allergies_hint'), inputType: InputType.Normal, onInput: (v: string) => {
          this.allergies = v;
          this.edit((p: Profile) => {
            p.allergies = parseList(v);
          });
        } })
        Text($r('app.string.em_allergies_help'))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.ink_3'))
      }
      .alignItems(HorizontalAlign.Start)
      .groupBox()

      // ICD model (only with an ICD; the ICD yes/no itself is part of the profile step)
      if (this.profile?.hasIcd === true) {
        Column({ space: 8 }) {
          this.fieldHeader($r('app.string.em_icd_model'), CardField.ICD_MODEL)
          FieldInput({ text: this.icdModel, hint: $r('app.string.em_icd_model_hint'), inputType: InputType.Normal, onInput: (v: string) => {
            this.icdModel = v;
            this.edit((p: Profile) => {
              p.icdModel = this.optional(v);
            });
          } })
        }
        .alignItems(HorizontalAlign.Start)
        .groupBox()
      }

      // Cardiologist
      Column({ space: 8 }) {
        this.fieldHeader($r('app.string.em_cardiologist'), CardField.CARDIOLOGIST)
        FieldInput({ text: this.cardioName, hint: $r('app.string.em_name_hint'), inputType: InputType.Normal, onInput: (v: string) => {
          this.cardioName = v;
          this.edit((p: Profile) => {
            p.cardiologistName = this.optional(v);
          });
        } })
        FieldInput({ text: this.cardioPhone, hint: $r('app.string.em_phone_hint'), inputType: InputType.PhoneNumber, onInput: (v: string) => {
          this.cardioPhone = v;
          this.edit((p: Profile) => {
            p.cardiologistPhone = this.optional(v);
          });
        } })
      }
      .alignItems(HorizontalAlign.Start)
      .groupBox()

      // Hospital
      Column({ space: 8 }) {
        this.fieldHeader($r('app.string.em_hospital'), CardField.HOSPITAL)
        FieldInput({ text: this.hospital, hint: $r('app.string.em_hospital_hint'), inputType: InputType.Normal, onInput: (v: string) => {
          this.hospital = v;
          this.edit((p: Profile) => {
            p.hospital = this.optional(v);
          });
        } })
      }
      .alignItems(HorizontalAlign.Start)
      .groupBox()

      // Anything else: label + value rows
      Column({ space: 8 }) {
        this.fieldHeader($r('app.string.em_extra'), CardField.EXTRA)
        ForEach(this.profile?.extra ?? [], (e: ExtraField, i: number) => {
          Row({ space: 8 }) {
            Column({ space: 2 }) {
              Text(e.label)
                .fontSize($r('app.float.font_caption'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.ink_3'))
              Text(e.value)
                .fontSize($r('app.float.font_body'))
                .fontColor($r('app.color.ink'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Image($r('app.media.ic_delete'))
              .width($r('app.float.touch_min'))
              .height($r('app.float.touch_min'))
              .padding(14)
              .fillColor($r('app.color.ink_4'))
              .accessibilityText($r('app.string.a11y_delete'))
              .onClick(() => {
                this.edit((p: Profile) => {
                  (p.extra ?? []).splice(i, 1);
                });
              })
          }
          .width('100%')
        }, (e: ExtraField, i: number) => `${i}-${e.label}-${e.value}`)
        if ((this.profile?.extra ?? []).length < MAX_EXTRA) {
          FieldInput({ text: this.extraLabel, hint: $r('app.string.em_extra_label_hint'), inputType: InputType.Normal, onInput: (v: string) => {
            this.extraLabel = v;
          } })
          FieldInput({ text: this.extraValue, hint: $r('app.string.em_extra_value_hint'), inputType: InputType.Normal, onInput: (v: string) => {
            this.extraValue = v;
          } })
          Text($r('app.string.em_extra_add'))
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Medium)
            .fontColor(this.extraLabel.trim().length > 0 && this.extraValue.trim().length > 0 ?
              $r('app.color.brand_text') : $r('app.color.ink_4'))
            .height($r('app.float.touch_min'))
            .onClick(() => {
              const label: string = this.extraLabel.trim();
              const value: string = this.extraValue.trim();
              if (label.length === 0 || value.length === 0) {
                return;
              }
              this.edit((p: Profile) => {
                const x: ExtraField = { label: label, value: value };
                p.extra = (p.extra ?? []).concat([x]);
              });
              this.extraLabel = '';
              this.extraValue = '';
            })
        }
        Text($r('app.string.em_extra_help'))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.ink_3'))
      }
      .alignItems(HorizontalAlign.Start)
      .groupBox()

      Text($r('app.string.em_card_privacy'))
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.ink_3'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

// Single-choice chip; selected = ink fill (DESIGN.md 6.3). A component, not a @Builder, so `selected` refreshes.
@ComponentV2
struct ChoiceChip {
  @Param label: ResourceStr = '';
  @Param selected: boolean = false;
  @Event onTap: () => void = () => {
  };

  build() {
    Text(this.label)
      .fontSize($r('app.float.font_small'))
      .fontWeight(FontWeight.Medium)
      .fontColor(this.selected ? $r('app.color.chat_user_text') : $r('app.color.ink'))
      .backgroundColor(this.selected ? $r('app.color.chat_user_bg') : $r('app.color.surface'))
      .border({ width: this.selected ? 0 : 1.5, color: $r('app.color.border_strong') })
      .borderRadius(22)
      .height($r('app.float.chip_height'))
      .padding({ left: 16, right: 16 })
      .accessibilityDescription(this.selected ? 'Selected' : '')
      .onClick(() => this.onTap())
  }
}

// Text field. A component, not a @Builder, so clearing or reloading `text` from the parent shows up.
@ComponentV2
struct FieldInput {
  @Param text: string = '';
  @Param hint: Resource | undefined = undefined;
  @Param inputType: InputType = InputType.Normal;
  @Event onInput: (v: string) => void = (v: string) => {
  };

  build() {
    TextInput({ text: this.text, placeholder: this.hint })
      .type(this.inputType)
      .height($r('app.float.button_height'))
      .fontSize($r('app.float.font_body'))
      .backgroundColor($r('app.color.surface_alt'))
      .borderRadius($r('app.float.radius_s'))
      .onChange((v: string) => this.onInput(v))
  }
}
