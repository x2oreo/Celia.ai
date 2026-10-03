// Email + password sign-up / log-in form (Workstream B1). Contract: used by pages/AuthPage.ets and by onboarding.
// On success the session is stored (Session.start) and the profile is synced with the account (restored on a new
// phone) before onDone(true). Errors are shown as the amber strip with plain words, never red.

import { AuthMode } from '../common/Routes';
import { AuthClient, AuthOutcome, AuthResult, MIN_PASSWORD_LENGTH, looksLikeEmail } from '../account/AuthClient';
import { Session } from '../account/Session';
import { ProfileSync } from '../account/ProfileSync';
import { PrimaryButton, SecondaryButton, StatusStrip } from './Common';

function outcomeMessage(o: AuthOutcome): Resource {
  if (o === 'INVALID_CREDENTIALS') {
    return $r('app.string.acc_err_invalid');
  }
  if (o === 'EMAIL_TAKEN') {
    return $r('app.string.acc_err_taken');
  }
  if (o === 'WEAK_PASSWORD') {
    return $r('app.string.acc_err_weak');
  }
  if (o === 'INVALID_EMAIL') {
    return $r('app.string.acc_err_invalid_email');
  }
  if (o === 'EMAIL_NOT_CONFIRMED') {
    return $r('app.string.acc_err_not_confirmed');
  }
  if (o === 'SIGNUP_DISABLED') {
    return $r('app.string.acc_err_signup_disabled');
  }
  if (o === 'RATE_LIMITED') {
    return $r('app.string.acc_err_rate');
  }
  if (o === 'OFFLINE') {
    return $r('app.string.acc_err_offline');
  }
  return $r('app.string.acc_err_server');
}

@ComponentV2
export struct AuthForm {
  @Param mode: AuthMode = 'SIGN_UP';
  // Inside a page that has its own primary action and mode switch (onboarding): the submit is a secondary button
  // and the "Already have an account?" link is left out.
  @Param embedded: boolean = false;
  // true once a session is stored (Session.isSignedIn()), false when the user backs out.
  @Event onDone: (signedIn: boolean) => void = (signedIn: boolean) => {
  };
  // Optional: the user switched between sign-up and log-in inside the form (so a page title can follow).
  @Event onModeChange: (mode: AuthMode) => void = (mode: AuthMode) => {
  };
  @Local current: AuthMode = 'SIGN_UP';
  @Local email: string = '';
  @Local password: string = '';
  @Local busy: boolean = false;
  @Local error: Resource | undefined = undefined;
  @Local confirmSent: boolean = false;

  aboutToAppear(): void {
    this.current = this.mode;
  }

  @Monitor('mode')
  onModeParam(): void {
    this.current = this.mode;
    this.error = undefined;
    this.confirmSent = false;
  }

  private switchMode(): void {
    this.current = this.current === 'SIGN_UP' ? 'LOG_IN' : 'SIGN_UP';
    this.error = undefined;
    this.confirmSent = false;
    this.onModeChange(this.current);
  }

  private async submit(): Promise<void> {
    if (this.busy) {
      return;
    }
    if (!looksLikeEmail(this.email)) {
      this.error = $r('app.string.acc_err_email');
      return;
    }
    if (this.current === 'SIGN_UP' && this.password.length < MIN_PASSWORD_LENGTH) {
      this.error = $r('app.string.acc_err_password_short');
      return;
    }
    this.error = undefined;
    this.confirmSent = false;
    this.busy = true;
    const r: AuthResult = this.current === 'SIGN_UP' ? await AuthClient.signUp(this.email, this.password) :
      await AuthClient.logIn(this.email, this.password);
    if (r.outcome === 'OK' && r.tokens !== undefined) {
      await Session.start(r.tokens);
      await ProfileSync.syncNow();   // restores the profile on a new phone; offline it returns at once
      this.busy = false;
      this.password = '';
      this.onDone(true);
      return;
    }
    this.busy = false;
    if (r.outcome === 'CONFIRM_EMAIL') {
      this.confirmSent = true;
      this.current = 'LOG_IN';
      this.onModeChange(this.current);
      return;
    }
    this.error = outcomeMessage(r.outcome);
  }

  @Builder
  label(text: Resource) {
    Text(text)
      .fontSize($r('app.float.font_small'))
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.ink_2'))
  }

  build() {
    Column({ space: 16 }) {
      // Inputs read this.email / this.password directly: a by-value @Builder param would reset them on re-render.
      Column({ space: 6 }) {
        this.label($r('app.string.acc_email'))
        TextInput({ text: this.email })
          .type(InputType.Email)
          .height($r('app.float.touch_min'))
          .fontSize($r('app.float.font_body'))
          .backgroundColor($r('app.color.surface_alt'))
          .borderRadius($r('app.float.radius_m'))
          .enabled(!this.busy)
          .onChange((v: string) => {
            this.email = v;
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      Column({ space: 6 }) {
        this.label($r('app.string.acc_password'))
        TextInput({
          text: this.password,
          placeholder: this.current === 'SIGN_UP' ? $r('app.string.acc_password_hint_new') : ''
        })
          .type(InputType.Password)
          .height($r('app.float.touch_min'))
          .fontSize($r('app.float.font_body'))
          .backgroundColor($r('app.color.surface_alt'))
          .borderRadius($r('app.float.radius_m'))
          .enabled(!this.busy)
          .onChange((v: string) => {
            this.password = v;
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      if (this.confirmSent) {
        StatusStrip({ kind: 'OFFLINE', label: $r('app.string.acc_confirm_email') })
      }
      if (this.error !== undefined) {
        StatusStrip({ kind: 'ERROR', label: this.error })
      }
      if (this.busy) {
        Row({ space: 10 }) {
          LoadingProgress().width(28).height(28).color($r('app.color.brand_accent'))
          Text($r('app.string.acc_working'))
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.ink_3'))
        }
        .height($r('app.float.button_height'))
        .justifyContent(FlexAlign.Center)
        .width('100%')
      } else if (this.embedded) {
        SecondaryButton({
          label: this.current === 'SIGN_UP' ? $r('app.string.acc_signup_button') : $r('app.string.acc_login_button'),
          active: this.email.length > 0 && this.password.length > 0,
          onTap: () => {
            this.submit();
          }
        })
      } else {
        PrimaryButton({
          label: this.current === 'SIGN_UP' ? $r('app.string.acc_signup_button') : $r('app.string.acc_login_button'),
          active: this.email.length > 0 && this.password.length > 0,
          onTap: () => {
            this.submit();
          }
        })
      }
      if (!this.embedded) {
        Text(this.current === 'SIGN_UP' ? $r('app.string.acc_to_login') : $r('app.string.acc_to_signup'))
          .fontSize($r('app.float.font_small'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.brand_text'))
          .constraintSize({ minHeight: $r('app.float.touch_min') })
          .textAlign(TextAlign.Center)
          .width('100%')
          .onClick(() => this.switchMode())
      }
    }
    .width('100%')
  }
}
