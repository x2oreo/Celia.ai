import { common } from '@kit.AbilityKit';
import { WatchController } from '../controller/WatchController';
import { AlertScreen } from '../components/AlertScreen';
import { CheckIn } from '../components/CheckIn';
import { DoseNudgeGlance } from '../components/DoseNudgeGlance';
import { PairingScreen } from '../components/PairingScreen';
import { HeartPage } from '../components/HeartPage';
import { SettingsPage } from '../components/SettingsPage';
import { TrendPage } from '../components/TrendPage';
import { SimulatePage } from '../components/SimulatePage';
import { SosScreen } from '../components/SosScreen';
import { Theme } from '../components/Theme';
import { VerdictGlance } from '../components/VerdictGlance';
import { VitalsPage } from '../components/VitalsPage';

/** Swiper index of the Settings page (Home, Heart, Vitals, Log, Settings, Simulator). */
const SETTINGS_PAGE: number = 4;

@Entry
@ComponentV2
struct Index {
  @Local ctrl: WatchController = new WatchController();

  aboutToAppear(): void {
    this.ctrl.init(this.getUIContext().getHostContext() as common.UIAbilityContext);
  }

  aboutToDisappear(): void {
    this.ctrl.dispose();
  }

  onPageShow(): void {
    this.ctrl.resume();
  }

  onPageHide(): void {
    this.ctrl.pause();
  }

  build() {
    Stack() {
      Swiper() {
        HeartPage({ ctrl: this.ctrl })
        TrendPage({ ctrl: this.ctrl })
        VitalsPage({ ctrl: this.ctrl })
        CheckIn({ ctrl: this.ctrl, asPage: true })
        SettingsPage({ ctrl: this.ctrl })
        // The simulator panel (every demo control) exists only in a DEMO_MODE build, always as the last page.
        if (this.ctrl.demoMode) {
          SimulatePage({ ctrl: this.ctrl })
        }
      }
      .loop(false)
      .onChange((index: number) => {
        // Settings page: show the current pairing state when it opens.
        if (index === SETTINGS_PAGE) {
          this.ctrl.refreshPairState();
        }
      })
      .indicator(new DotIndicator()
        .itemWidth(5)
        .itemHeight(5)
        .selectedItemWidth(5)
        .selectedItemHeight(5)
        .color(Theme.BORDER)
        .selectedColor(Theme.TEXT)
        .bottom(6))
      .width('100%')
      .height('100%')

      // Most urgent screen wins: SOS > fall/alert > check-in > dose nudge > drug verdict > pairing.
      if (this.ctrl.sosCountdown > 0 || this.ctrl.sosSent) {
        SosScreen({ ctrl: this.ctrl })
      } else if (this.ctrl.fallCountdown > 0 || this.ctrl.alertKind !== 'NONE') {
        AlertScreen({ ctrl: this.ctrl })
      } else if (this.ctrl.checkInOpen) {
        CheckIn({ ctrl: this.ctrl })
      } else if (this.ctrl.doseNudgeOpen) {
        DoseNudgeGlance({ ctrl: this.ctrl })
      } else if (this.ctrl.verdictDrug.length > 0) {
        VerdictGlance({ ctrl: this.ctrl })
      } else if (this.ctrl.pairingOpen) {
        PairingScreen({ ctrl: this.ctrl })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
