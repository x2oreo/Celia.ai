import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { Logger } from '../common/Logger';
import { LocalStore } from '../data/LocalStore';
import { AppLock } from '../common/AppLock';
import { DemoVoice } from '../voice/DemoVoice';
import { GtinCatalog } from '../drugs/GtinCatalog';
import { AgentCore } from '../agent/AgentCore';
import { WidgetSync } from '../widget/WidgetSync';
import { RouteRequest } from '../common/RouteRequest';
import { TabRequest } from '../common/TabRequest';
import { Routes, TabIndex } from '../common/Routes';
import { Profile } from '../model/Profile';
import { emergencyFor, systemCountry } from '../common/EmergencyNumbers';
import { dial } from '../common/Dialer';

const log: Logger = new Logger('EntryAbility');

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // Follow the system light/dark setting.
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (e) {
      log.warn(`setColorMode failed: ${JSON.stringify(e)}`);
    }
    LocalStore.get().init(this.context).then(() => {
      AppLock.init();
      WidgetSync.start(this.context);
    });
    GtinCatalog.get().init(this.context);
    DemoVoice.init(this.context);
    // Agent listens for vitals alerts from app start (proactive check-ins).
    AgentCore.get().start();
    this.handleCardTap(want);
    log.info('onCreate');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.handleCardTap(want);
  }

  // A tap on a home-screen card (widget/pages/*): params.target says where to go.
  private handleCardTap(want: Want): void {
    const raw: Object | undefined = want.parameters?.params;
    if (raw === undefined) {
      return;
    }
    let target: string = '';
    try {
      target = (JSON.parse(raw as string) as Record<string, string>).target ?? '';
    } catch (e) {
      return;
    }
    if (target === 'scan') {
      RouteRequest.open(Routes.SCAN);
    } else if (target === 'bystander') {
      RouteRequest.open(Routes.BYSTANDER);
    } else if (target === 'responder') {
      RouteRequest.open(Routes.RESPONDER);
    } else if (target === 'emergency' || target === 'call' || target === 'ice') {
      TabRequest.open(TabIndex.EMERGENCY);
      if (target !== 'emergency') {
        this.dialFromCard(target === 'ice');
      }
    }
  }

  // Opens the dialer with the number filled in; the user still confirms the call.
  private async dialFromCard(ice: boolean): Promise<void> {
    try {
      const profile: Profile | undefined = await LocalStore.get().getProfile();
      if (ice && profile !== undefined && profile.contacts.length > 0) {
        await dial(profile.contacts[0].phone);
      } else {
        await dial(emergencyFor(profile?.country ?? systemCountry()).ambulance);
      }
    } catch (e) {
      log.warn(`dial from card failed: ${JSON.stringify(e)}`);
    }
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
