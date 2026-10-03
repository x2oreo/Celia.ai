// Email + password sign-up / log-in form (Workstream B1). Contract: used by pages/AuthPage.ets and by onboarding.
// Stub until the accounts stream lands: renders a placeholder and reports "not signed in".

import { AuthMode } from '../common/Routes';

@ComponentV2
export struct AuthForm {
  @Param mode: AuthMode = 'SIGN_UP';
  // true once a session is stored (Session.isSignedIn()), false when the user backs out.
  @Event onDone: (signedIn: boolean) => void = (signedIn: boolean) => {
  };

  build() {
    Text(this.mode === 'SIGN_UP' ? 'Sign up (coming)' : 'Log in (coming)')
      .fontSize($r('app.float.font_body'))
      .fontColor($r('app.color.ink_3'))
  }
}
