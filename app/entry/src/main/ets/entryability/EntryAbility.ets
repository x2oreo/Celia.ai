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
import { cancelNotify, initNotify, NOTIFY_ALERT, NOTIFY_SOS } from '../common/Notify';
import { NotifyTap, NotifyTarget, parseNotifyTap, parsePushTap, PushSosTap, targetFor } from '../common/NotifyAction';
import { PushToken } from '../account/PushToken';
import { SosController } from '../emergency/SosController';
import { ReminderService } from '../reminders/ReminderService';
import { HeartOkRequest } from '../common/HeartOkRequest';

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
      PushToken.start();
    });
    initNotify(this.context);
    GtinCatalog.get().init(this.context);
    DemoVoice.init(this.context);
    // Agent listens for vitals alerts from app start (proactive check-ins).
    AgentCore.get().start();
    this.handleCardTap(want);
    this.handleNotifyTap(want);
    this.handlePushTap(want);
    log.info('onCreate');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.handleCardTap(want);
    this.handleNotifyTap(want);
    this.handlePushTap(want);
  }

  // A tap on the server push "SOS from your watch" (B12). The watch already counted down and sent it, so the SOS page
  // opens in its sent state (B8), also on a cold start when polling has not seen the row yet.
  private handlePushTap(want: Want): void {
    const tap: PushSosTap | undefined = parsePushTap(want.parameters, Date.now());
    if (tap === undefined) {
      return;
    }
    log.info('push tap: watch SOS');
    SosController.get().watchSent(tap.at, tap.withLocation);
    RouteRequest.open(Routes.SOS);
  }

  // A tap on one of our notifications or its buttons (common/NotifyAction.ets). The app is already opening; act on
  // the button, then show the page it belongs to. Cold start: RouteRequest / TabRequest keep the page until the
  // root exists, and LocalStore calls wait for the store to open.
  private async handleNotifyTap(want: Want): Promise<void> {
    const tap: NotifyTap | undefined = parseNotifyTap(want.parameters);
    if (tap === undefined) {
      return;
    }
    log.info(`notification ${tap.notifyId}: ${tap.action}`);
    try {
      if (tap.action === 'SOS_OK') {
        // The SOS page sees ACKED on its next tick and closes the same way its own "I'm OK" does.
        if (SosController.get().state === 'COUNTDOWN') {
          SosController.get().ack();
          AgentCore.get().emergencyCancelled();
        }
        await cancelNotify(NOTIFY_SOS);
      } else if (tap.action === 'ALERT_OK') {
        await cancelNotify(NOTIFY_ALERT);
        HeartOkRequest.send(Date.now());
      } else if (tap.action === 'DOSE_TAKEN') {
        await ReminderService.takeFromNotification(tap.reminderId, Date.now());
      }
    } catch (e) {
      log.warn(`notification action failed: ${JSON.stringify(e)}`);
    }
    const target: NotifyTarget = targetFor(tap);
    if (target === 'heart' && tap.action === 'OPEN') {
      TabRequest.open(TabIndex.HEART);
    } else if (target === 'reminders') {
      RouteRequest.open(Routes.REMINDERS);
    } else if (target === 'history') {
      RouteRequest.open(Routes.HISTORY);
    }
    // 'sos': the SOS page is already on top while an SOS runs; nothing to push.
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
    } else if (target === 'feeling') {
      RouteRequest.open(Routes.FEELING);
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
