// Welcome (Workstream B1): first launch, signed out, nothing on this phone yet. What the app is, the disclaimer,
// then create an account, log in, or set up without one (the app must work with no network from the first launch,
// and signing up needs one).

import { AuthParam, Routes } from '../common/Routes';
import { AgentAvatar } from '../components/AgentAvatar';
import { PrimaryButton, QuietButton, SecondaryButton } from '../components/Common';

@ComponentV2
export struct WelcomePage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();

  @Builder
  point(icon: Resource, text: Resource) {
    Row({ space: 12 }) {
      Row() {
        Image(icon).width(20).height(20).fillColor($r('app.color.ink_2'))
      }
      .width(36)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.surface_alt'))
      .borderRadius($r('app.float.radius_s'))
      Text(text)
        .fontSize($r('app.float.font_small'))
        .fontColor($r('app.color.ink_2'))
        .layoutWeight(1)
    }
    .width('100%')
  }

  build() {
    NavDestination() {
      Column() {
        Scroll() {
          Column({ space: 16 }) {
            AgentAvatar({ dim: 96 })
              .margin({ top: 48, bottom: 8 })
            Text($r('app.string.acc_welcome_title'))
              .fontSize($r('app.float.font_title_1'))
              .fontWeight(800)
              .fontColor($r('app.color.ink'))
            Text($r('app.string.acc_welcome_tagline'))
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.ink_2'))
              .textAlign(TextAlign.Center)
            Column({ space: 12 }) {
              this.point($r('app.media.ic_pill'), $r('app.string.acc_welcome_point_check'))
              this.point($r('app.media.ic_tab_heart'), $r('app.string.acc_welcome_point_watch'))
              this.point($r('app.media.ic_tab_emergency'), $r('app.string.acc_welcome_point_card'))
            }
            .width('100%')
            .padding(16)
            .margin({ top: 8 })
            .backgroundColor($r('app.color.surface'))
            .border({ width: 1, color: $r('app.color.border') })
            .borderRadius($r('app.float.radius_l'))
          }
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)

        Column({ space: 10 }) {
          PrimaryButton({
            label: $r('app.string.acc_welcome_create'),
            onTap: () => {
              this.navStack.pushPathByName(Routes.AUTH, new AuthParam('SIGN_UP'));
            }
          })
          SecondaryButton({
            label: $r('app.string.acc_welcome_login'),
            onTap: () => {
              this.navStack.pushPathByName(Routes.AUTH, new AuthParam('LOG_IN'));
            }
          })
          QuietButton({
            label: $r('app.string.acc_welcome_skip'),
            onTap: () => {
              this.navStack.replacePathByName(Routes.ONBOARDING, null, false);
            }
          })
          Text($r('app.string.acc_welcome_skip_hint'))
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.ink_3'))
            .textAlign(TextAlign.Center)
          Text($r('app.string.disclaimer'))
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.ink_4'))
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding({ top: 12, bottom: 16 })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 20, right: 20 })
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg'))
    .onBackPressed(() => true)   // first launch: pick one of the three ways in, nothing behind this page to show
  }
}
