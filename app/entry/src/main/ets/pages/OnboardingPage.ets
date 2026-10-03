// OWNER: Georgi — Onboarding NavDestination. Shown first when no profile exists.
// Real flow: condition, genotype, ICD, meds, ICE contacts, notes → LocalStore.saveProfile.

import { LocalStore } from '../data/LocalStore';
import { Profile } from '../model/Profile';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('Onboarding');

@ComponentV2
export struct OnboardingPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();

  private async finish(): Promise<void> {
    const profile: Profile = {
      condition: 'LQTS',
      genotype: 'UNKNOWN',
      hasIcd: false,
      notes: '',
      contacts: []
    };
    await LocalStore.get().saveProfile(profile);
    log.info('placeholder profile saved');
    this.navStack.pop();
  }

  build() {
    NavDestination() {
      Column({ space: 16 }) {
        Blank()
        Image($r('app.media.ic_tab_heart'))
          .width(72)
          .height(72)
          .fillColor($r('app.color.brand_accent'))
        Text($r('app.string.onboarding_title'))
          .fontSize($r('app.float.font_title'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Text($r('app.string.onboarding_subtitle'))
          .fontSize($r('app.float.font_body'))
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
        Blank()
        Button($r('app.string.onboarding_continue'))
          .width('100%')
          .height(48)
          .backgroundColor($r('app.color.brand_accent'))
          .fontColor($r('app.color.on_accent'))
          .onClick(() => {
            this.finish();
          })
        Text($r('app.string.disclaimer'))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('sys.color.font_tertiary'))
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .height('100%')
      .padding($r('app.float.space_l'))
    }
    .hideTitleBar(true)
    .onBackPressed(() => true) // onboarding must be completed, not dismissed
  }
}
