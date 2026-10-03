// Onboarding step 7 "Permissions": notifications, microphone, location. Each row says why in one sentence and asks
// only when its Allow button is tapped (B3). This is now the only place the app asks for notifications.

import { common } from '@kit.AbilityKit';
import { PermKind, PermState, permissionState, requestPermission } from '../../onboarding/Permissions';
import { OnbHeading } from './OnbParts';

@ComponentV2
export struct StepPermissions {
  @Local notif: PermState = 'ASK';
  @Local mic: PermState = 'ASK';
  @Local loc: PermState = 'ASK';
  @Local busy: boolean = false;

  aboutToAppear(): void {
    this.refresh();
  }

  private async refresh(): Promise<void> {
    this.notif = await permissionState('NOTIFICATIONS');
    this.mic = await permissionState('MICROPHONE');
    this.loc = await permissionState('LOCATION');
  }

  private stateOf(kind: PermKind): PermState {
    if (kind === 'NOTIFICATIONS') {
      return this.notif;
    }
    return kind === 'MICROPHONE' ? this.mic : this.loc;
  }

  private async ask(kind: PermKind): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const state: PermState = await requestPermission(ctx, kind);
    if (kind === 'NOTIFICATIONS') {
      this.notif = state;
    } else if (kind === 'MICROPHONE') {
      this.mic = state;
    } else {
      this.loc = state;
    }
    this.busy = false;
  }

  @Builder
  row(kind: PermKind, icon: Resource, title: Resource, why: Resource) {
    Column({ space: 8 }) {
      Row({ space: 12 }) {
        Stack() {
          Image(icon).width(22).height(22).fillColor($r('app.color.brand_text'))
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor($r('app.color.brand_accent_soft'))
        Column({ space: 2 }) {
          Text(title)
            .fontSize($r('app.float.font_headline'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          Text(why)
            .fontSize($r('app.float.font_small'))
            .fontColor($r('app.color.ink_2'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        if (this.stateOf(kind) === 'GRANTED') {
          Row({ space: 4 }) {
            Image($r('app.media.ic_check')).width(18).height(18).fillColor($r('app.color.ink_2'))
            Text($r('app.string.onb_perm_allowed'))
              .fontSize($r('app.float.font_small'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.ink_2'))
          }
          .accessibilityGroup(true)
        } else {
          Button($r('app.string.onb_perm_allow'))
            .type(ButtonType.Normal)
            .height($r('app.float.touch_min'))
            .padding({ left: $r('app.float.space_m'), right: $r('app.float.space_m') })
            .borderRadius($r('app.float.radius_btn'))
            .fontSize($r('app.float.font_button'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.on_accent'))
            .backgroundColor($r('app.color.ink'))
            .enabled(!this.busy)
            .onClick(() => this.ask(kind))
        }
      }
      .width('100%')
      if (this.stateOf(kind) === 'DENIED') {
        Text($r('app.string.onb_perm_denied'))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.ink_3'))
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding($r('app.float.space_m'))
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_m'))
  }

  build() {
    Column({ space: 12 }) {
      OnbHeading({ heading: $r('app.string.onb_perm_title'), subtitle: $r('app.string.onb_perm_subtitle') })
      this.row('NOTIFICATIONS', $r('app.media.ic_bell'), $r('app.string.onb_perm_notif'),
        $r('app.string.onb_perm_notif_why'))
      this.row('MICROPHONE', $r('app.media.ic_mic'), $r('app.string.onb_perm_mic'), $r('app.string.onb_perm_mic_why'))
      this.row('LOCATION', $r('app.media.ic_location'), $r('app.string.onb_perm_loc'),
        $r('app.string.onb_perm_loc_why'))
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
