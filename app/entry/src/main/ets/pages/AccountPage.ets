// Settings → Account (Workstream B1/B2): who is signed in, backup state, sign out (optionally wiping this phone),
// and deleting the account copy of the profile. Signed out: sign in or create an account.
// The watch-SOS consent switch lives on Settings → Emergency contacts (components/SosAlertsCard.ets).

import { AuthParam, Routes } from '../common/Routes';
import { dateTime } from '../common/Format';
import { toast } from '../common/Toast';
import { LocalStore } from '../data/LocalStore';
import { Session } from '../account/Session';
import { PushToken } from '../account/PushToken';
import { ProfileSync, SyncResult } from '../account/ProfileSync';
import { SosContacts } from '../account/SosContacts';
import { PrimaryButton, SecondaryButton, SectionHeader, StatusStrip } from '../components/Common';

@ComponentV2
export struct AccountPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local signedIn: boolean = false;
  @Local email: string = '';
  @Local syncResult: SyncResult = 'UP_TO_DATE';
  @Local syncAt: number = 0;
  @Local busy: boolean = false;
  private unsubscribe: () => void = () => {
  };

  aboutToAppear(): void {
    this.refresh();
    this.unsubscribe = Session.onChange(() => this.refresh());
  }

  aboutToDisappear(): void {
    this.unsubscribe();
  }

  private refresh(): void {
    this.signedIn = Session.isSignedIn();
    this.email = Session.email();
    this.syncResult = ProfileSync.lastResult;
    this.syncAt = ProfileSync.lastSyncAt;
  }

  private async syncNow(): Promise<void> {
    this.busy = true;
    await ProfileSync.syncNow();
    this.busy = false;
    this.refresh();
  }

  private confirmSignOut(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.acc_sign_out'),
      message: $r('app.string.acc_sign_out_confirm'),
      primaryButton: {
        value: $r('app.string.acc_sign_out_keep'),
        action: () => {
          this.signOut(false);
        }
      },
      secondaryButton: {
        value: $r('app.string.acc_sign_out_wipe'),
        fontColor: $r('app.color.risk_known'),
        action: () => {
          this.signOut(true);
        }
      },
      cancel: () => {
      }
    });
  }

  private async signOut(wipe: boolean): Promise<void> {
    await PushToken.forget();   // the push_tokens row can only be deleted with the user's token
    await Session.signOut();
    if (wipe) {
      await LocalStore.get().clearAll();
      this.navStack.clear(false);
      this.navStack.pushPathByName(Routes.WELCOME, null, false);
      return;
    }
    this.refresh();
  }

  private confirmDeleteCloud(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.acc_delete_cloud'),
      message: $r('app.string.acc_delete_cloud_confirm'),
      primaryButton: {
        value: $r('app.string.acc_cancel'),
        action: () => {
        }
      },
      secondaryButton: {
        value: $r('app.string.acc_delete_cloud_yes'),
        fontColor: $r('app.color.risk_known'),
        action: () => {
          this.deleteCloud();
        }
      }
    });
  }

  // Deleting signs out too, so the next local edit does not upload the profile again.
  private async deleteCloud(): Promise<void> {
    this.busy = true;
    await SosContacts.clearOnServer();   // contacts and first name go too
    const ok: boolean = await ProfileSync.deleteCloudData();
    this.busy = false;
    if (!ok) {
      toast(this.getUIContext(), $r('app.string.acc_delete_failed'));
      return;
    }
    await PushToken.forget();
    await Session.signOut();
    toast(this.getUIContext(), $r('app.string.acc_deleted_cloud'));
    this.refresh();
  }

  @Builder
  syncLine() {
    if (this.syncResult === 'OFFLINE') {
      StatusStrip({ kind: 'OFFLINE', label: $r('app.string.acc_sync_offline') })
    } else if (this.syncResult === 'ERROR') {
      StatusStrip({ kind: 'ERROR', label: $r('app.string.acc_sync_error') })
    } else if (this.syncAt > 0) {
      Text($r('app.string.acc_sync_ok', dateTime(this.syncAt, Date.now())))
        .fontSize($r('app.float.font_small'))
        .fontColor($r('app.color.ink_2'))
        .width('100%')
    } else {
      Text($r('app.string.acc_sync_never'))
        .fontSize($r('app.float.font_small'))
        .fontColor($r('app.color.ink_3'))
        .width('100%')
    }
  }

  @Builder
  signedInCard() {
    Column({ space: 12 }) {
      Text($r('app.string.acc_signed_in_as'))
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.ink_3'))
        .width('100%')
      Text(this.email)
        .fontSize($r('app.float.font_headline'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      this.syncLine()
      if (this.busy) {
        LoadingProgress().width(28).height(28).color($r('app.color.brand_accent'))
      } else {
        SecondaryButton({
          label: $r('app.string.acc_sync_now'),
          onTap: () => {
            this.syncNow();
          }
        })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_m'))
  }

  @Builder
  whereCard() {
    Text($r('app.string.acc_where_body'))
      .fontSize($r('app.float.font_small'))
      .fontColor($r('app.color.ink_2'))
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.border') })
      .borderRadius($r('app.float.radius_m'))
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          if (this.signedIn) {
            this.signedInCard()
            SecondaryButton({
              label: $r('app.string.acc_sign_out'),
              onTap: () => this.confirmSignOut()
            })
            SectionHeader({ title: $r('app.string.acc_where_label') })
            this.whereCard()
            Text($r('app.string.acc_delete_cloud'))
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.risk_known'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .constraintSize({ minHeight: $r('app.float.touch_min') })
              .padding(12)
              .onClick(() => this.confirmDeleteCloud())
          } else {
            Text($r('app.string.acc_signed_out_body'))
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.ink_2'))
              .width('100%')
              .margin({ top: 8, bottom: 8 })
            PrimaryButton({
              label: $r('app.string.acc_action_login'),
              onTap: () => {
                this.navStack.pushPathByName(Routes.AUTH, new AuthParam('LOG_IN'));
              }
            })
            SecondaryButton({
              label: $r('app.string.acc_welcome_create'),
              onTap: () => {
                this.navStack.pushPathByName(Routes.AUTH, new AuthParam('SIGN_UP'));
              }
            })
            SectionHeader({ title: $r('app.string.acc_where_label') })
            this.whereCard()
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
    .title($r('app.string.acc_title'))
    .backgroundColor($r('app.color.bg'))
    .onShown(() => this.refresh())
  }
}
