// App root: Navigation + NavPathStack hosting the bottom tabs. Full-screen flows (onboarding, verdict detail,
// emergency mode) are pushed as NavDestinations by route name — see common/Routes.ets.

import { MainTabs } from '../components/MainTabs';
import { OnboardingPage } from './OnboardingPage';
import { Routes } from '../common/Routes';
import { LocalStore } from '../data/LocalStore';
import { Profile } from '../model/Profile';

@Entry
@ComponentV2
struct Index {
  @Provider('navStack') navStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    this.showOnboardingIfNeeded();
  }

  private async showOnboardingIfNeeded(): Promise<void> {
    const profile: Profile | undefined = await LocalStore.get().getProfile();
    if (profile === undefined) {
      this.navStack.pushPathByName(Routes.ONBOARDING, null, false);
    }
  }

  @Builder
  routeMap(name: string, param: Object) {
    if (name === Routes.ONBOARDING) {
      OnboardingPage()
    }
  }

  build() {
    Navigation(this.navStack) {
      MainTabs()
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.routeMap)
  }
}
