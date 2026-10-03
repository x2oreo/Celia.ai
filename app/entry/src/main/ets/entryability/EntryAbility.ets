import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { Logger } from '../common/Logger';
import { LocalStore } from '../data/LocalStore';
import { AppLock } from '../common/AppLock';
import { GtinCatalog } from '../drugs/GtinCatalog';
import { AgentCore } from '../agent/AgentCore';

const log: Logger = new Logger('EntryAbility');

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // Follow the system light/dark setting.
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (e) {
      log.warn(`setColorMode failed: ${JSON.stringify(e)}`);
    }
    LocalStore.get().init(this.context).then(() => AppLock.init());
    GtinCatalog.get().init(this.context);
    // Agent listens for vitals alerts from app start (proactive check-ins).
    AgentCore.get().start();
    log.info('onCreate');
  }

  onDestroy(): void {
    log.info('onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        log.error(`Failed to load the content: ${JSON.stringify(err)}`);
        return;
      }
      log.info('Content loaded');
    });
  }

  onWindowStageDestroy(): void {
    log.info('onWindowStageDestroy');
  }

  onForeground(): void {
    AppLock.onForeground(Date.now());
    log.info('onForeground');
  }

  onBackground(): void {
    AppLock.onBackground(Date.now());
    log.info('onBackground');
  }
}
