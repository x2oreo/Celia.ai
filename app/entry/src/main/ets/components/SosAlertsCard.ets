// B10 consent card: "Let my watch alert my contacts" (off by default) with what is on the server and how the last
// SOS went. Lives on Settings → Emergency contacts, next to the people it alerts. Signed out: a line and Log in.

import { AuthParam, Routes } from '../common/Routes';
import { dateTime } from '../common/Format';
import { Session } from '../account/Session';
import { DispatchStatus, SosContacts, SosStatus, SosSyncResult } from '../account/SosContacts';
import { WatchPairing } from '../data/WatchPairing';
import { SecondaryButton, StatusStrip } from './Common';

@ComponentV2
export struct SosAlertsCard {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  // Bumped by the host page when it is shown again or the contacts changed, so the card reloads.
  @Param refreshKey: number = 0;
  @Local signedIn: boolean = false;
  @Local sosOn: boolean = false;
  @Local sosBusy: boolean = false;
  @Local sosPaired: boolean = false;
  @Local sosResult: SosSyncResult | undefined = undefined;
  @Local sosSkipped: number = 0;
  @Local sosContacts: number = -1;   // -1 = unknown (offline / not loaded)
  @Local sosLast: DispatchStatus | undefined = undefined;
  @Local sosLastAt: number = 0;
  private unsubscribe: () => void = () => {
  };

  aboutToAppear(): void {
    this.load();
    this.unsubscribe = Session.onChange(() => this.load());
  }

  aboutToDisappear(): void {
    this.unsubscribe();
  }

  @Monitor('refreshKey')
  onRefresh(): void {
    this.load();
  }

  private async load(): Promise<void> {
    this.signedIn = Session.isSignedIn();
    this.sosOn = await SosContacts.consent();
    this.sosPaired = WatchPairing.isPaired();
    this.sosResult = SosContacts.lastResult;
    this.sosSkipped = SosContacts.lastSkipped;
    const st: SosStatus | undefined = this.signedIn ? await SosContacts.status() : undefined;
    this.sosContacts = st !== undefined ? st.contacts : -1;
    this.sosLast = st !== undefined ? st.lastStatus : undefined;
    this.sosLastAt = st !== undefined ? st.lastAt : 0;
  }

  private async toggle(on: boolean): Promise<void> {
    this.sosOn = on;
    this.sosBusy = true;
    this.sosResult = await SosContacts.setConsent(on);
    this.sosSkipped = SosContacts.lastSkipped;
    this.sosBusy = false;
    await this.load();
  }

  private lastLine(): Resource | undefined {
    const at: string = dateTime(this.sosLastAt, Date.now());
    if (this.sosLast === 'dry_run') {
      return $r('app.string.acc_sos_last_dry_run', at);
    }
    if (this.sosLast === 'sent') {
      return $r('app.string.acc_sos_last_sent', at);
    }
    if (this.sosLast === 'partial') {
      return $r('app.string.acc_sos_last_partial', at);
    }
    if (this.sosLast === 'failed' || this.sosLast === 'skipped_global_limit' || this.sosLast === 'unknown') {
      return $r('app.string.acc_sos_last_failed', at);
    }
    if (this.sosLast === 'no_contacts') {
      return $r('app.string.acc_sos_last_no_contacts', at);
    }
    if (this.sosLast === 'skipped_cooldown') {
      return $r('app.string.acc_sos_last_skipped', at);
    }
    return undefined;
  }

  @Builder
  signedInBody() {
    Row({ space: 12 }) {
      Text($r('app.string.acc_sos_switch'))
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.ink'))
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.sosOn })
        .enabled(this.sosPaired && !this.sosBusy)
        .selectedColor($r('app.color.ink'))
        .accessibilityText($r('app.string.acc_sos_switch'))
        .onChange((on: boolean) => {
          if (on !== this.sosOn) {
            this.toggle(on);
          }
        })
    }
    .width('100%')
    .constraintSize({ minHeight: $r('app.float.touch_min') })
    Text($r('app.string.acc_sos_explain'))
      .fontSize($r('app.float.font_small'))
      .fontColor($r('app.color.ink_3'))
      .width('100%')
    if (!this.sosPaired) {
      StatusStrip({ kind: 'OFFLINE', label: $r('app.string.acc_sos_needs_watch') })
    } else if (this.sosBusy) {
      LoadingProgress().width(28).height(28).color($r('app.color.brand_accent'))
    } else if (this.sosOn) {
      if (this.sosResult === 'OFFLINE') {
        StatusStrip({ kind: 'OFFLINE', label: $r('app.string.acc_sos_offline') })
      } else if (this.sosResult === 'ERROR') {
        StatusStrip({ kind: 'ERROR', label: $r('app.string.acc_sos_error') })
      }
      if (this.sosContacts > 0) {
        Text($r('app.string.acc_sos_ready', this.sosContacts))
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink_2'))
          .width('100%')
      } else if (this.sosContacts === 0) {
        Text($r('app.string.acc_sos_none'))
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink_2'))
          .width('100%')
      }
      if (this.sosSkipped > 0) {
        StatusStrip({ kind: 'ERROR', label: $r('app.string.acc_sos_skipped', this.sosSkipped) })
      }
    }
    if (this.sosPaired && this.lastLine() !== undefined) {
      Text(this.lastLine())
        .fontSize($r('app.float.font_small'))
        .fontColor($r('app.color.ink_2'))
        .width('100%')
    }
  }

  build() {
    Column({ space: 12 }) {
      if (this.signedIn) {
        this.signedInBody()
      } else {
        Text($r('app.string.contacts_sos_signed_out'))
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink_2'))
          .width('100%')
        SecondaryButton({
          label: $r('app.string.acc_action_login'),
          onTap: () => {
            this.navStack.pushPathByName(Routes.AUTH, new AuthParam('LOG_IN'));
          }
        })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_l'))
  }
}
