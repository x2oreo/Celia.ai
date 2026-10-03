// Editor for the emergency details (Workstream B4): date of birth, sex, blood type, allergies, ICD model,
// cardiologist, hospital, extra fields and the per-field "show on card" switches.
// Contract: used by pages/EmergencyProfilePage.ets and by onboarding. It never saves; the host saves onChange.
// Stub until the emergency stream lands.

import { Profile } from '../model/Profile';

@ComponentV2
export struct EmergencyDetailsForm {
  @Param profile: Profile | undefined = undefined;
  @Event onChange: (profile: Profile) => void = (profile: Profile) => {
  };

  build() {
    Text('Emergency details (coming)')
      .fontSize($r('app.float.font_body'))
      .fontColor($r('app.color.ink_3'))
  }
}
