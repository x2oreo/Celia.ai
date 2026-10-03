import { common } from '@kit.AbilityKit';
import { WatchController } from '../controller/WatchController';
import { AlertScreen } from '../components/AlertScreen';
import { CheckIn } from '../components/CheckIn';
import { HeartPage } from '../components/HeartPage';
import { SettingsPage } from '../components/SettingsPage';
import { SimulatePage } from '../components/SimulatePage';
import { SosScreen } from '../components/SosScreen';
import { Theme } from '../components/Theme';
import { VerdictGlance } from '../components/VerdictGlance';
import { VitalsPage } from '../components/VitalsPage';

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
        VitalsPage({ ctrl: this.ctrl })
        CheckIn({ ctrl: this.ctrl, asPage: true })
        SettingsPage({ ctrl: this.ctrl })
        SimulatePage({ ctrl: this.ctrl })
      }
      .loop(false)
      .indicator(new DotIndicator()
        .itemWidth(5)
        .itemHeight(5)
        .selectedItemWidth(5)
        .selectedItemHeight(5)
        .color(Theme.DASH)
        .selectedColor(Theme.TEXT)
        .bottom(6))
      .width('100%')
      .height('100%')

      // Most urgent screen wins: SOS > fall/alert > check-in > drug verdict.
      if (this.ctrl.sosCountdown > 0 || this.ctrl.sosSent) {
        SosScreen({ ctrl: this.ctrl })
      } else if (this.ctrl.fallCountdown > 0 || this.ctrl.alertKind !== 'NONE') {
        AlertScreen({ ctrl: this.ctrl })
      } else if (this.ctrl.checkInOpen) {
        CheckIn({ ctrl: this.ctrl })
      } else if (this.ctrl.verdictDrug.length > 0) {
        VerdictGlance({ ctrl: this.ctrl })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
