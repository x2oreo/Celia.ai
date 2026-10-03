// Sign up / log in (Workstream B1), pushed from Welcome and from Settings → Account with an AuthParam.
// After sign-in: a profile on the phone (restored from the account or set up before) → straight into the app;
// none → onboarding.

import { AuthMode, AuthParam, Routes } from '../common/Routes';
import { LocalStore } from '../data/LocalStore';
import { Profile } from '../model/Profile';
import { AuthForm } from '../components/AuthForm';

@ComponentV2
export struct AuthPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local mode: AuthMode = 'SIGN_UP';
  @Local ready: boolean = false;

  private async done(signedIn: boolean): Promise<void> {
    if (!signedIn) {
      this.navStack.pop();
      return;
    }
    const names: string[] = this.navStack.getAllPathName();
    const fromSettings: boolean = names.includes(Routes.ACCOUNT);
    const profile: Profile | undefined = await LocalStore.get().getProfile();
    if (fromSettings) {
      this.navStack.pop();
    } else if (profile !== undefined) {
      this.navStack.clear();
    } else {
      this.navStack.clear(false);
      this.navStack.pushPathByName(Routes.ONBOARDING, null, false);
    }
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 8 }) {
          Text(this.mode === 'SIGN_UP' ? $r('app.string.acc_signup_title') : $r('app.string.acc_login_title'))
            .fontSize($r('app.float.font_title_1'))
            .fontWeight(800)
            .fontColor($r('app.color.ink'))
            .width('100%')
          Text(this.mode === 'SIGN_UP' ? $r('app.string.acc_signup_subtitle') : $r('app.string.acc_login_subtitle'))
            .fontSize($r('app.float.font_small'))
            .fontColor($r('app.color.ink_3'))
            .width('100%')
            .margin({ bottom: 16 })
          if (this.ready) {
            AuthForm({
              mode: this.mode,
              onDone: (signedIn: boolean) => {
                this.done(signedIn);
              },
              onModeChange: (m: AuthMode) => {
                this.mode = m;
              }
            })
          }
          Text($r('app.string.disclaimer'))
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.ink_4'))
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: 16 })
        }
        .padding({ left: 20, right: 20, top: 8, bottom: 32 })
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .backgroundColor($r('app.color.bg'))
    .onReady((ctx: NavDestinationContext) => {
      const p: AuthParam | undefined = ctx.pathInfo.param as AuthParam | undefined;
      this.mode = p !== undefined && p !== null ? p.mode : 'SIGN_UP';
      this.ready = true;   // the form reads its mode once, so build it after the param is known
    })
  }
}
