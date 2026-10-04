// Settings (F-34, DESIGN.md 6.11 + 10.2): an index, never a form. A profile card on top, then grouped rows that say
// the current state in words and open the page (or sheet) where it changes. Each of those saves on change.

import { LocalStore } from '../data/LocalStore';
import { Profile } from '../model/Profile';
import { EMERGENCY_NUMBERS, EmergencyInfo, emergencyFor, systemCountry } from '../common/EmergencyNumbers';
import { Routes, SosParam } from '../common/Routes';
import { ScreenHeader, fmtText } from '../components/Common';
import { ProfileAvatar } from '../components/ProfileAvatar';
import { SettingsDivider, SettingsGroup, SettingsRow } from '../components/SettingsList';
import { WatchPairing, shortId } from '../data/WatchPairing';
import { Config } from '../common/Config';
import { Session } from '../account/Session';
import { SosContacts } from '../account/SosContacts';
import { AppLock } from '../common/AppLock';
import { cloneProfile } from '../emergency/EmergencyDetails';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('SettingsPage');

@ComponentV2
export struct SettingsPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local profile: Profile | undefined = undefined;
  @Local watchPaired: boolean = false;
  @Local watchShort: string = '';
  @Local accountEmail: string = '';   // '' = signed out
  @Local sosAlertsOn: boolean = false;
  @Local lockOn: boolean = false;
  @Local showNumbers: boolean = false;
  @Local numberQuery: string = '';
  private stopAccount: () => void = () => {
  };

  aboutToAppear(): void {
    this.stopAccount = Session.onChange(() => {
      this.accountEmail = Session.email();
    });
  }

  aboutToDisappear(): void {
    this.stopAccount();
  }

  // Runs on every show, so coming back from a sub-page shows what changed there.
  private async refresh(): Promise<void> {
    this.profile = await LocalStore.get().getProfile();
    this.accountEmail = Session.email();
    this.watchPaired = WatchPairing.isPaired();
    this.watchShort = shortId(Config.WATCH_DEVICE_ID);
    this.lockOn = AppLock.isEnabled();
    this.sosAlertsOn = await SosContacts.consent();
  }

  private country(): EmergencyInfo {
    return emergencyFor(this.profile?.country ?? systemCountry());
  }

  private async setCountry(code: string): Promise<void> {
    const stored: Profile | undefined = await LocalStore.get().getProfile();
    if (stored === undefined) {
      return;
    }
    const p: Profile = cloneProfile(stored);
    p.country = code;
    await LocalStore.get().saveProfile(p);
    this.profile = p;
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
      log.error(`dialog failed: ${JSON.stringify(e)}`);
    }
  }

  private async clear(): Promise<void> {
    await LocalStore.get().clearAll();
    this.navStack.clear();
    this.navStack.pushPathByName(Routes.ONBOARDING, null, false);
  }

  private contactsValue(): ResourceStr {
    const n: number = this.profile?.contacts.length ?? 0;
    if (n === 0) {
      return $r('app.string.settings_contacts_none');
    }
    const ui: UIContext = this.getUIContext();
    const people: string = n === 1 ? fmtText(ui, $r('app.string.settings_contacts_one')) :
      fmtText(ui, $r('app.string.settings_contacts_many'), n);
    return this.sosAlertsOn ? fmtText(ui, $r('app.string.settings_contacts_alerts'), people) : people;
  }

  private filteredNumbers(): EmergencyInfo[] {
    const q: string = this.numberQuery.trim().toLowerCase();
    const byName: EmergencyInfo[] = EMERGENCY_NUMBERS.slice().sort((a: EmergencyInfo, b: EmergencyInfo) =>
      a.name.localeCompare(b.name));
    if (q.length === 0) {
      return byName;
    }
    return byName.filter((e: EmergencyInfo) => e.name.toLowerCase().includes(q) ||
      e.code.toLowerCase() === q || e.ambulance.includes(q));
  }

  @Builder
  chip(label: ResourceStr) {
    Text(label)
      .fontSize($r('app.float.font_caption'))
      .fontWeight(600)
      .fontColor($r('app.color.ink_2'))
      .height(24)
      .padding({ left: 10, right: 10 })
      .backgroundColor($r('app.color.surface_alt'))
      .borderRadius(12)
  }

  @Builder
  profileCard() {
    Row({ space: 14 }) {
      ProfileAvatar({ side: 56, name: this.profile?.name ?? '' })
      Column({ space: 6 }) {
        if ((this.profile?.name ?? '').trim().length > 0) {
          Text((this.profile?.name ?? '').trim())
            .fontSize($r('app.float.font_headline'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else {
          Text($r('app.string.settings_add_name'))
            .fontSize($r('app.float.font_headline'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink_3'))
        }
        Row({ space: 6 }) {
          if ((this.profile?.genotype ?? 'UNKNOWN') === 'UNKNOWN') {
            this.chip($r('app.string.settings_genotype_unset'))
          } else {
            this.chip(this.profile?.genotype ?? '')
          }
          if (this.profile?.hasIcd ?? false) {
            this.chip($r('app.string.settings_icd_chip'))
          }
        }
        Text(this.accountEmail !== '' ? $r('app.string.settings_in_account') : $r('app.string.settings_on_phone'))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.ink_3'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Image($r('app.media.ic_chevron_right')).width(18).height(18).fillColor($r('app.color.ink_4'))
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_l'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
    .accessibilityGroup(true)
    .accessibilityDescription($r('app.string.settings_open_profile'))
    .onClick(() => {
      this.navStack.pushPathByName(Routes.HEART_PROFILE, null);
    })
  }

  @Builder
  safetyRows() {
    SettingsRow({
      icon: $r('app.media.ic_phone'),
      title: $r('app.string.contacts_title'),
      value: this.contactsValue(),
      onTap: () => {
        this.navStack.pushPathByName(Routes.CONTACTS, null);
      }
    })
    SettingsDivider()
    SettingsRow({
      icon: $r('app.media.ic_id_card'),
      title: $r('app.string.em_row_title'),
      value: $r('app.string.settings_details_value'),
      onTap: () => {
        this.navStack.pushPathByName(Routes.EMERGENCY_PROFILE, null);
      }
    })
    SettingsDivider()
    SettingsRow({
      icon: $r('app.media.ic_location'),
      title: $r('app.string.settings_number_title'),
      value: `${this.country().name} · ${this.country().ambulance}`,
      onTap: () => {
        this.numberQuery = '';
        this.showNumbers = true;
      }
    })
    SettingsDivider()
    SettingsRow({
      icon: $r('app.media.ic_bell'),
      title: $r('app.string.settings_test_sos'),
      value: $r('app.string.settings_test_sos_hint'),
      onTap: () => {
        this.navStack.pushPathByName(Routes.SOS, new SosParam(true, 'Test from Settings'));
      }
    })
  }

  @Builder
  accountRows() {
    SettingsRow({
      icon: $r('app.media.ic_user'),
      title: $r('app.string.acc_nav'),
      value: this.accountEmail !== '' ? this.accountEmail : $r('app.string.settings_account_out'),
      onTap: () => {
        this.navStack.pushPathByName(Routes.ACCOUNT, null);
      }
    })
    SettingsDivider()
    SettingsRow({
      icon: $r('app.media.ic_lock'),
      title: $r('app.string.settings_privacy_title'),
      value: this.lockOn ? $r('app.string.settings_lock_on') : $r('app.string.settings_lock_off'),
      onTap: () => {
        this.navStack.pushPathByName(Routes.PRIVACY, null);
      }
    })
  }

  @Builder
  numberRow(e: EmergencyInfo) {
    Row({ space: 12 }) {
      Text(e.name)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.ink'))
        .layoutWeight(1)
      Text(e.ambulance)
        .fontSize($r('app.float.font_body'))
        .fontWeight(600)
        .fontColor($r('app.color.ink_2'))
      if (e.code === this.country().code) {
        Image($r('app.media.ic_check')).width(20).height(20).fillColor($r('app.color.brand_text'))
      } else {
        Blank().width(20)
      }
    }
    .width('100%')
    .height(60)
    .padding({ left: 16, right: 16 })
    .accessibilityGroup(true)
    .accessibilitySelected(e.code === this.country().code)
    .onClick(() => {
      this.setCountry(e.code).catch((err: Error) => log.error(`country save failed: ${err.message}`));
      this.showNumbers = false;
    })
  }

  @Builder
  numbersSheet() {
    Column({ space: 12 }) {
      Text($r('app.string.settings_number_title'))
        .fontSize($r('app.float.font_title_3'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .padding({ left: 20, right: 20 })
      Search({ value: this.numberQuery, placeholder: $r('app.string.settings_number_search') })
        .height($r('app.float.touch_min'))
        .backgroundColor($r('app.color.surface_alt'))
        .margin({ left: 16, right: 16 })
        .onChange((v: string) => {
          this.numberQuery = v;
        })
      List() {
        ForEach(this.filteredNumbers(), (e: EmergencyInfo) => {
          ListItem() {
            this.numberRow(e)
          }
        }, (e: EmergencyInfo) => e.code)
      }
      .divider({ strokeWidth: 1, color: $r('app.color.divider'), startMargin: 16, endMargin: 16 })
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .padding({ top: 20 })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination() {
      Column() {
        ScreenHeader({ title: $r('app.string.settings_title'), settings: false })
        Scroll() {
          Column({ space: 24 }) {
            if (this.profile !== undefined) {
              this.profileCard()
              SettingsGroup({ label: $r('app.string.settings_group_safety') }) {
                this.safetyRows()
              }
              SettingsGroup({ label: $r('app.string.settings_group_devices') }) {
                SettingsRow({
                  icon: $r('app.media.ic_watch'),
                  title: $r('app.string.settings_watch_title'),
                  value: this.watchPaired ? $r('app.string.pair_row_paired', this.watchShort) :
                    $r('app.string.settings_watch_unpaired'),
                  onTap: () => {
                    this.navStack.pushPathByName(Routes.PAIR_WATCH, null);
                  }
                })
              }
              SettingsGroup({ label: $r('app.string.settings_group_account') }) {
                this.accountRows()
              }
              SettingsGroup() {
                SettingsRow({
                  icon: $r('app.media.ic_delete'),
                  title: $r('app.string.settings_clear_row'),
                  danger: true,
                  onTap: () => this.confirmClear()
                })
              }
              Text($r('app.string.settings_footer'))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.ink_4'))
                .textAlign(TextAlign.Center)
                .width('100%')
            }
          }
          .padding({ left: $r('app.float.space_m'), right: $r('app.float.space_m'), top: 4, bottom: 32 })
          .width('100%')
        }
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg'))
    .onShown(() => {
      this.refresh().catch((e: Error) => log.error(`refresh failed: ${e.message}`));
    })
    .bindSheet(this.showNumbers, this.numbersSheet(), {
      detents: [SheetSize.LARGE],
      showClose: true,
      backgroundColor: $r('app.color.bg'),
      onDisappear: () => {
        this.showNumbers = false;
      }
    })
  }
}
