// Settings → Emergency contacts: the people an SOS reaches (also listed on the emergency card), removing one asks
// first, adding goes through a sheet. Below the list, the watch-SOS consent card (SosAlertsCard) that sends them to
// the server. Every change is saved straight away.

import { LocalStore } from '../data/LocalStore';
import { Contact, Profile } from '../model/Profile';
import { cloneProfile } from '../emergency/EmergencyDetails';
import { validContact } from '../onboarding/OnboardingFlow';
import { CapsLabel, EmptyCard, PrimaryButton, ScreenHeader, fmtText } from '../components/Common';
import { OnbInput } from '../components/onboarding/OnbParts';
import { SettingsDivider, SettingsGroup } from '../components/SettingsList';
import { SosAlertsCard } from '../components/SosAlertsCard';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('ContactsPage');

@ComponentV2
export struct ContactsPage {
  @Local contacts: Contact[] = [];
  @Local loaded: boolean = false;
  @Local showAdd: boolean = false;
  @Local cName: string = '';
  @Local cPhone: string = '';
  @Local cRelation: string = '';
  @Local cEmail: string = '';
  @Local refreshKey: number = 0;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    const p: Profile | undefined = await LocalStore.get().getProfile();
    this.contacts = p !== undefined ? p.contacts : [];
    this.loaded = true;
  }

  // Applies the change to the latest stored profile, so fields edited on other pages are kept.
  private async save(mutate: (p: Profile) => void): Promise<void> {
    const stored: Profile | undefined = await LocalStore.get().getProfile();
    if (stored === undefined) {
      return;
    }
    const p: Profile = cloneProfile(stored);
    mutate(p);
    await LocalStore.get().saveProfile(p);
    this.contacts = p.contacts;
    this.refreshKey++;
  }

  private add(): void {
    if (!validContact(this.cName, this.cPhone)) {
      return;
    }
    const c: Contact = {
      name: this.cName.trim(), phone: this.cPhone.trim(), relation: this.cRelation.trim(), email: this.cEmail.trim()
    };
    this.save((p: Profile) => {
      p.contacts.push(c);
    }).catch((e: Error) => log.error(`add failed: ${e.message}`));
    this.cName = '';
    this.cPhone = '';
    this.cRelation = '';
    this.cEmail = '';
    this.showAdd = false;
  }

  private confirmRemove(c: Contact, index: number): void {
    try {
      this.getUIContext().showAlertDialog({
        title: fmtText(this.getUIContext(), $r('app.string.contacts_remove_title'), c.name),
        message: $r('app.string.contacts_remove_body'),
        primaryButton: {
          value: $r('app.string.settings_cancel'),
          action: () => {
          }
        },
        secondaryButton: {
          value: $r('app.string.contacts_remove_yes'),
          fontColor: $r('app.color.risk_known'),
          action: () => {
            this.save((p: Profile) => {
              p.contacts.splice(index, 1);
            }).catch((e: Error) => log.error(`remove failed: ${e.message}`));
          }
        }
      });
    } catch (e) {
      log.error(`dialog failed: ${JSON.stringify(e)}`);
    }
  }

  @Builder
  contactRow(c: Contact, index: number) {
    Row({ space: 12 }) {
      Text(c.name.length > 0 ? c.name.charAt(0).toUpperCase() : '?')
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink_2'))
        .backgroundColor($r('app.color.surface_alt'))
        .borderRadius(18)
      Column({ space: 2 }) {
        Text(`${c.name}${c.relation === '' ? '' : ` (${c.relation})`}`)
          .fontSize($r('app.float.font_body'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ink'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(c.email !== undefined && c.email.length > 0 ? `${c.phone} · ${c.email}` : c.phone)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.ink_3'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Row() {
        Image($r('app.media.ic_delete')).width(20).height(20).fillColor($r('app.color.ink_4'))
      }
      .width($r('app.float.touch_min'))
      .height($r('app.float.touch_min'))
      .justifyContent(FlexAlign.Center)
      .accessibilityGroup(true)
      .accessibilityText($r('app.string.a11y_delete'))
      .onClick(() => this.confirmRemove(c, index))
    }
    .width('100%')
    .constraintSize({ minHeight: 60 })
    .padding({ top: 6, bottom: 6, left: 16, right: 4 })
  }

  @Builder
  contactList() {
    ForEach(this.contacts, (c: Contact, i: number) => {
      if (i > 0) {
        SettingsDivider()
      }
      this.contactRow(c, i)
    }, (c: Contact, i: number) => `${i}-${c.name}-${c.phone}`)
  }

  @Builder
  addSheet() {
    Column({ space: 12 }) {
      Text($r('app.string.contacts_new'))
        .fontSize($r('app.float.font_title_3'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
      OnbInput({
        value: this.cName,
        hint: $r('app.string.onb_contact_name'),
        onInput: (v: string) => {
          this.cName = v;
        }
      })
      OnbInput({
        value: this.cPhone,
        hint: $r('app.string.onb_contact_phone'),
        inputType: InputType.PhoneNumber,
        onInput: (v: string) => {
          this.cPhone = v;
        }
      })
      OnbInput({
        value: this.cRelation,
        hint: $r('app.string.onb_contact_relation'),
        onInput: (v: string) => {
          this.cRelation = v;
        }
      })
      OnbInput({
        value: this.cEmail,
        hint: $r('app.string.settings_email_hint'),
        inputType: InputType.Email,
        onInput: (v: string) => {
          this.cEmail = v;
        }
      })
      PrimaryButton({
        label: $r('app.string.contacts_add_yes'),
        active: validContact(this.cName, this.cPhone),
        onTap: () => this.add()
      })
    }
    .padding(20)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination() {
      Column() {
        ScreenHeader({ title: $r('app.string.contacts_title'), settings: false })
        Scroll() {
          Column({ space: 24 }) {
            Text($r('app.string.contacts_intro'))
              .fontSize($r('app.float.font_small'))
              .fontColor($r('app.color.ink_2'))
              .width('100%')
            if (this.loaded && this.contacts.length === 0) {
              EmptyCard({ message: $r('app.string.contacts_empty') })
            } else if (this.contacts.length > 0) {
              SettingsGroup({ label: $r('app.string.contacts_list_label') }) {
                this.contactList()
              }
            }
            Column({ space: 8 }) {
              CapsLabel({ text: $r('app.string.acc_sos_label') })
                .padding({ left: 4 })
              SosAlertsCard({ refreshKey: this.refreshKey })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          .padding({ left: $r('app.float.space_m'), right: $r('app.float.space_m'), top: 4, bottom: 24 })
          .width('100%')
        }
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
        Column() {
          PrimaryButton({
            label: $r('app.string.contacts_add'),
            icon: $r('app.media.ic_plus'),
            onTap: () => {
              this.showAdd = true;
            }
          })
        }
        .width('100%')
        .padding($r('app.float.space_m'))
        .backgroundColor($r('app.color.bg'))
        .border({ width: { top: 1 }, color: $r('app.color.border') })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg'))
    .onShown(() => {
      this.refreshKey++;
    })
    .bindSheet(this.showAdd, this.addSheet(), {
      detents: [SheetSize.LARGE],
      showClose: true,
      backgroundColor: $r('app.color.bg'),
      onDisappear: () => {
        this.showAdd = false;
      }
    })
  }
}
