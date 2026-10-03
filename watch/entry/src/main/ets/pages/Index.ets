import { common } from '@kit.AbilityKit';
import { WatchController } from '../controller/WatchController';
import { AlertOverlay } from '../components/AlertOverlay';
import { HeartPage } from '../components/HeartPage';
import { LogPage } from '../components/LogPage';
import { SettingsPage } from '../components/SettingsPage';
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

  build() {
    Stack() {
      Swiper() {
        HeartPage({ ctrl: this.ctrl })
        LogPage({ ctrl: this.ctrl })
        SettingsPage({ ctrl: this.ctrl })
      }
      .loop(false)
      .indicator(new DotIndicator()
        .itemWidth(6)
        .itemHeight(6)
        .selectedItemWidth(6)
        .selectedItemHeight(6)
        .color(Theme.MUTED)
        .selectedColor(Theme.TEXT)
        .bottom(18))
      .width('100%')
      .height('100%')

      if (this.ctrl.alertText.length > 0) {
        AlertOverlay({ ctrl: this.ctrl })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
