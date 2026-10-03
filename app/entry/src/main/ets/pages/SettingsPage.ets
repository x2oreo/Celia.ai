// Settings (F-34): profile, country, contacts (with optional email), test SOS, privacy, clear data.
// Every change is saved immediately.

import { LocalStore } from '../data/LocalStore';
import { Contact, Genotype, Profile } from '../model/Profile';
import { EMERGENCY_NUMBERS, EmergencyInfo, emergencyFor } from '../common/EmergencyNumbers';
import { Routes, SosParam } from '../common/Routes';
import { NavRow, PrimaryButton, SectionHeader } from '../components/Common';
import { validPhone } from './OnboardingPage';
import { toast } from '../common/Toast';
import { WatchPairing, shortId } from '../data/WatchPairing';
import { Config } from '../common/Config';

const GENOTYPES: Genotype[] = ['LQT1', 'LQT2', 'LQT3', 'UNKNOWN'];

@ComponentV2
export struct SettingsPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local profile: Profile | undefined = undefined;
  @Local name: string = '';
  @Local notes: string = '';
  @Local cName: string = '';
  @Local cPhone: string = '';
  @Local cRelation: string = '';
  @Local cEmail: string = '';
  @Local showAddContact: boolean = false;
  @Local watchPaired: boolean = false;
  @Local watchShort: string = '';

  aboutToAppear(): void {
    this.load();
  }

  // Back from the Pair watch page: show the new pairing state.
  refreshWatchRow(): void {
    this.watchPaired = WatchPairing.isPaired();
    this.watchShort = shortId(Config.WATCH_DEVICE_ID);
  }

  private async load(): Promise<void> {
    this.profile = await LocalStore.get().getProfile();
    this.name = this.profile?.name ?? '';
    this.notes = this.profile?.notes ?? '';
    this.refreshWatchRow();
  }

  // Saves a copy so @Local observers see a new object.
  private async save(mutate: (p: Profile) => void): Promise<void> {
    if (this.profile === undefined) {
      return;
    }
    const p: Profile = {
      condition: this.profile.condition,
      genotype: this.profile.genotype,
      hasIcd: this.profile.hasIcd,
      notes: this.profile.notes,
      contacts: this.profile.contacts.slice(),
      name: this.profile.name,
      country: this.profile.country,
      cardLanguage: this.profile.cardLanguage
    };
    mutate(p);
    this.profile = p;
    await LocalStore.get().saveProfile(p);
  }

  private addContact(): void {
    if (this.cName.trim().length === 0 || !validPhone(this.cPhone)) {
      toast(this.getUIContext(), $r('app.string.onb_contact_invalid'));
      return;
    }
    const c: Contact = {
      name: this.cName.trim(), phone: this.cPhone.trim(), relation: this.cRelation.trim(), email: this.cEmail.trim()
    };
    this.save((p: Profile) => {
      p.contacts.push(c);
    });
    this.cName = '';
    this.cPhone = '';
    this.cRelation = '';
    this.cEmail = '';
    this.showAddContact = false;
  }

  private confirmClear(): void {
    try {
      this.getUIContext().showAlertDialog({
        title: $r('app.string.settings_clear'),
        message: $r('app.string.settings_clear_confirm'),
        primaryButton: {
          value: $r('app.string.settings_cancel'),
          action: () => {
          }
        },
        secondaryButton: {
          value: $r('app.string.settings_clear_yes'),
          fontColor: $r('app.color.risk_known'),
          action: () => {
            this.clear();
          }
        }
      });
    } catch (e) {
      console.error(`dialog failed: ${JSON.stringify(e)}`);
    }
  }

  private async clear(): Promise<void> {
    await LocalStore.get().clearAll();
    this.navStack.clear();
    this.navStack.pushPathByName(Routes.ONBOARDING, null, false);
  }

  @Builder
  input(value: string, hint: Resource, type: InputType, onChange: (v: string) => void) {
    TextInput({ text: value, placeholder: hint })
      .type(type)
      .height(46)
      .backgroundColor($r('app.color.surface_alt'))
      .onChange(onChange)
  }

  @Builder
  profileGroup() {
    Column({ space: 12 }) {
      this.input(this.name, $r('app.string.onb_name_hint'), InputType.Normal, (v: string) => {
        this.name = v;
      })
      Row({ space: 8 }) {
        ForEach(GENOTYPES, (g: Genotype) => {
          Text(g === 'UNKNOWN' ? 'Not sure' : g)
            .fontSize($r('app.float.font_small'))
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(40)
            .fontColor((this.profile?.genotype ?? 'UNKNOWN') === g ? $r('app.color.chat_user_text') : $r('app.color.ink'))
            .backgroundColor((this.profile?.genotype ?? 'UNKNOWN') === g ? $r('app.color.chat_user_bg') : $r('app.color.surface'))
            .border({ width: (this.profile?.genotype ?? 'UNKNOWN') === g ? 0 : 1.5, color: $r('app.color.border_strong') })
            .borderRadius($r('app.float.radius_s'))
            .onClick(() => {
              this.save((x: Profile) => {
                x.genotype = g;
              });
            })
        }, (g: Genotype) => g)
      }
      .width('100%')
      Row() {
        Text($r('app.string.onb_icd'))
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.ink'))
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.profile?.hasIcd ?? false })
          .selectedColor($r('app.color.brand_accent'))
          .onChange((on: boolean) => {
            this.save((x: Profile) => {
              x.hasIcd = on;
            });
          })
      }
      .width('100%')
      TextArea({ text: this.notes, placeholder: $r('app.string.onb_notes_hint') })
        .height(96)
        .backgroundColor($r('app.color.surface_alt'))
        .onChange((v: string) => {
          this.notes = v;
        })
      PrimaryButton({
        label: $r('app.string.settings_save'),
        onTap: () => {
          this.save((x: Profile) => {
            x.name = this.name.trim();
            x.notes = this.notes.trim();
          });
          toast(this.getUIContext(), $r('app.string.settings_saved'));
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_m'))
  }

  @Builder
  contactsGroup() {
    Column({ space: 10 }) {
      ForEach(this.profile?.contacts ?? [], (c: Contact, i: number) => {
        Row({ space: 8 }) {
          Column({ space: 2 }) {
            Text(`${c.name}${c.relation === '' ? '' : ` (${c.relation})`}`)
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.ink'))
            Text(c.email !== undefined && c.email.length > 0 ? `${c.phone} · ${c.email}` : c.phone)
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.ink_3'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Image($r('app.media.ic_delete'))
            .width(20)
            .height(20)
            .fillColor($r('app.color.ink_4'))
            .accessibilityText($r('app.string.a11y_delete'))
            .onClick(() => {
              this.save((x: Profile) => {
                x.contacts.splice(i, 1);
              });
            })
        }
        .width('100%')
      }, (c: Contact, i: number) => `${i}-${c.phone}`)
      if (this.showAddContact) {
        this.input(this.cName, $r('app.string.onb_contact_name'), InputType.Normal, (v: string) => {
          this.cName = v;
        })
        this.input(this.cPhone, $r('app.string.onb_contact_phone'), InputType.PhoneNumber, (v: string) => {
          this.cPhone = v;
        })
        this.input(this.cRelation, $r('app.string.onb_contact_relation'), InputType.Normal, (v: string) => {
          this.cRelation = v;
        })
        this.input(this.cEmail, $r('app.string.settings_email_hint'), InputType.Email, (v: string) => {
          this.cEmail = v;
        })
        PrimaryButton({ label: $r('app.string.onb_contact_add'), onTap: () => this.addContact() })
      } else {
        Text($r('app.string.onb_contact_add'))
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.brand_text'))
          .onClick(() => {
            this.showAddContact = true;
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_m'))
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          if (this.profile !== undefined) {
            SectionHeader({ title: $r('app.string.settings_profile') })
            this.profileGroup()

            SectionHeader({ title: $r('app.string.settings_contacts') })
            this.contactsGroup()

            SectionHeader({ title: $r('app.string.settings_region') })
            Column({ space: 12 }) {
              Select(EMERGENCY_NUMBERS.map((e: EmergencyInfo) => {
                const opt: SelectOption = { value: `${e.name} (${e.ambulance})` };
                return opt;
              }))
                .value(`${emergencyFor(this.profile.country).name} (${emergencyFor(this.profile.country).ambulance})`)
                .width('100%')
                .onSelect((index: number) => {
                  this.save((x: Profile) => {
                    x.country = EMERGENCY_NUMBERS[index].code;
                  });
                })
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.surface'))
            .border({ width: 1, color: $r('app.color.border') })
            .borderRadius($r('app.float.radius_m'))

            SectionHeader({ title: $r('app.string.pair_nav') })
            NavRow({
              icon: $r('app.media.ic_tab_heart'),
              title: $r('app.string.pair_row_title'),
              subtitle: this.watchPaired ? $r('app.string.pair_row_paired', this.watchShort) :
                $r('app.string.pair_row_unpaired'),
              onTap: () => {
                this.navStack.pushPathByName(Routes.PAIR_WATCH, null);
              }
            })

            SectionHeader({ title: $r('app.string.settings_safety') })
            NavRow({
              icon: $r('app.media.ic_bell'),
              title: $r('app.string.settings_test_sos'),
              subtitle: $r('app.string.settings_test_sos_hint'),
              onTap: () => {
                this.navStack.pushPathByName(Routes.SOS, new SosParam(true, 'Test from Settings'));
              }
            })
            NavRow({
              icon: $r('app.media.ic_lock'),
              title: $r('app.string.privacy_title'),
              subtitle: $r('app.string.privacy_subtitle'),
              onTap: () => {
                this.navStack.pushPathByName(Routes.PRIVACY, null);
              }
            })
            Text($r('app.string.settings_clear'))
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.risk_known'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(16)
              .backgroundColor($r('app.color.surface'))
              .border({ width: 1, color: $r('app.color.border') })
              .borderRadius($r('app.float.radius_m'))
              .onClick(() => this.confirmClear())
          }
        }
        .padding({ left: 16, right: 16, bottom: 32 })
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .title($r('app.string.settings_title'))
    .onShown(() => this.refreshWatchRow())
    .backgroundColor($r('app.color.bg'))
  }
}
