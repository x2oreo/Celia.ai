import { common } from '@kit.AbilityKit';
import { WatchController } from '../controller/WatchController';
import { AlertOverlay } from '../components/AlertOverlay';
import { EmergencyOverlay } from '../components/EmergencyOverlay';
import { FallOverlay } from '../components/FallOverlay';
import { HeartPage } from '../components/HeartPage';
import { LogPage } from '../components/LogPage';
import { SettingsPage } from '../components/SettingsPage';
import { SimulatePage } from '../components/SimulatePage';
import { VitalsPage } from '../components/VitalsPage';
import { Theme } from '../components/Theme';

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
        LogPage({ ctrl: this.ctrl })
        SettingsPage({ ctrl: this.ctrl })
        SimulatePage({ ctrl: this.ctrl })
      }
      .loop(false)
      .indicator(new DotIndicator()
        .itemWidth(6)
        .itemHeight(6)
        .selectedItemWidth(6)
        .selectedItemHeight(6)
        .color(Theme.MUTED)
        .selectedColor(Theme.TEXT)
        .bottom(8))
      .width('100%')
      .height('100%')

      if (this.ctrl.emergencyText.length > 0) {
        EmergencyOverlay({ ctrl: this.ctrl })
      } else if (this.ctrl.fallCountdown > 0) {
        FallOverlay({ ctrl: this.ctrl })
      } else if (this.ctrl.alertText.length > 0) {
        AlertOverlay({ ctrl: this.ctrl })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
