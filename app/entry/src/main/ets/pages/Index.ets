// App root: Navigation + NavPathStack hosting the bottom tabs. Full-screen flows (onboarding, check result,
// history, SOS, …) are pushed as NavDestinations by route name — see common/Routes.ets.

import { common } from '@kit.AbilityKit';
import { MainTabs } from '../components/MainTabs';
import { OnboardingPage } from './OnboardingPage';
import { CheckResultPage } from './CheckResultPage';
import { HistoryPage } from './HistoryPage';
import { SettingsPage } from './SettingsPage';
import { SosPage } from './SosPage';
import { BystanderPage } from './BystanderPage';
import { DoctorPrepPage } from './DoctorPrepPage';
import { PharmacyCardPage } from './PharmacyCardPage';
import { PrivacyPage } from './PrivacyPage';
import { SymptomLogPage } from './SymptomLogPage';
import { RemindersPage } from './RemindersPage';
import { AgentPage } from './AgentPage';
import { ScanPage } from './ScanPage';
import { LockScreen } from '../components/LockScreen';
import { Routes, SosParam } from '../common/Routes';
import { LocalStore } from '../data/LocalStore';
import { Profile } from '../model/Profile';
import { VitalsAlert, VitalsSample } from '../model/Vitals';
import { VitalsService } from '../vitals/VitalsService';
import { WearNotifier } from '../vitals/WearNotifier';
import { SosController } from '../emergency/SosController';
import { askNotificationPermission } from '../common/Notify';
import { AppLock } from '../common/AppLock';
import { ReminderService } from '../reminders/ReminderService';
import { AgentCore, QUICK_REPLY_OK, QUICK_REPLY_UNWELL } from '../agent/AgentCore';
import { CheckInSheet } from '../components/CheckInSheet';
import { clock } from '../common/Format';
import { AgentPrompt } from '../agent/AgentPrompt';
import { RouteRequest } from '../common/RouteRequest';
import { AgentReply, EmergencyPayload, UiAction } from '../model/AgentTypes';

@Entry
@ComponentV2
struct Index {
  @Provider('navStack') navStack: NavPathStack = new NavPathStack();
  @Local locked: boolean = false;
  // Heart-rate check-in sheet (design B3)
  @Local checkIn: boolean = false;
  @Local checkInText: string = '';
  @Local checkInBpm: number = 0;
  @Local checkInTime: string = '';
  @Local checkInSim: boolean = true;

  aboutToAppear(): void {
    this.showOnboardingIfNeeded();
    VitalsService.get().start('SIMULATED');
    WearNotifier.start();
    VitalsService.get().onAlert((a: VitalsAlert) => this.onAlert(a));
    AgentCore.get().onProactive((r: AgentReply) => this.onAgentProactive(r));
    AgentPrompt.onOpenChat(() => this.openChat());
    RouteRequest.onOpen((route: string) => this.openRoute(route));
    this.openRoute(RouteRequest.take());
    askNotificationPermission(this.getUIContext().getHostContext() as common.UIAbilityContext);
    AppLock.onLockChange((locked: boolean) => {
      this.locked = locked;
    });
    this.locked = AppLock.isLocked();
    ReminderService.handleLaunch();
    setInterval(() => {
      ReminderService.checkDue(Date.now());
    }, 30000);
  }

  private async showOnboardingIfNeeded(): Promise<void> {
    const profile: Profile | undefined = await LocalStore.get().getProfile();
    if (profile === undefined) {
      this.navStack.pushPathByName(Routes.ONBOARDING, null, false);
    }
  }

  // A home-screen card asked for a page (e.g. Scan). Opened once, on top of the tabs.
  private openRoute(route: string): void {
    if (route === '') {
      return;
    }
    const names: string[] = this.navStack.getAllPathName();
    if (names.length > 0 && names[names.length - 1] === route) {
      return;
    }
    this.navStack.pushPathByName(route, null);
  }

  // "Ask the agent" from anywhere: bring the chat page to the front (once).
  private openChat(): void {
    const names: string[] = this.navStack.getAllPathName();
    if (names.length > 0 && names[names.length - 1] === Routes.AGENT_CHAT) {
      return;
    }
    this.navStack.pushPathByName(Routes.AGENT_CHAT, null);
  }

  // CRITICAL heart alert → wrist/phone alert + SOS countdown (unless one is running or in cooldown).
  private onAlert(a: VitalsAlert): void {
    WearNotifier.vitalsAlert(a);
    if (a.severity !== 'CRITICAL' || !SosController.get().canAutoStart(Date.now())) {
      return;
    }
    const reason: string = a.hr > 0 ? `heart rate ${Math.round(a.hr)} — ${a.kind.toLowerCase().replace(/_/g, ' ')}` :
      a.kind.toLowerCase().replace(/_/g, ' ');
    this.checkIn = false;
    this.navStack.pushPathByName(Routes.SOS, new SosParam(false, reason, true));
  }

  // Unanswered heart-rate check-in → the agent starts an emergency; hand it to the SOS screen.
  private onAgentProactive(r: AgentReply): void {
    const a: UiAction | undefined = r.actions.find((x: UiAction) => x.type === 'START_EMERGENCY');
    if (a === undefined) {
      if (r.actions.some((x: UiAction) => x.type === 'QUICK_REPLIES')) {
        this.showCheckIn(r.text);
      }
      return;
    }
    this.checkIn = false;
    if (!SosController.get().canAutoStart(Date.now())) {
      return;
    }
    const p: EmergencyPayload = JSON.parse(a.payload) as EmergencyPayload;
    this.navStack.pushPathByName(Routes.SOS, new SosParam(false, p.reason, true));
  }

  // The agent asks "are you OK?" as a sheet, unless the chat is already in front (it shows the same question).
  private showCheckIn(text: string): void {
    const names: string[] = this.navStack.getAllPathName();
    if (names.length > 0 && names[names.length - 1] === Routes.AGENT_CHAT) {
      return;
    }
    // Never ask "are you OK?" on top of a running or just-sent SOS.
    if (names.includes(Routes.SOS) || SosController.get().state !== 'IDLE') {
      return;
    }
    const sample: VitalsSample | undefined = VitalsService.get().latest();
    this.checkInText = text;
    this.checkInBpm = sample === undefined ? 0 : Math.round(sample.hr);
    this.checkInSim = sample?.source !== 'WATCH';
    this.checkInTime = clock(Date.now());
    this.checkIn = true;
  }

  @Builder
  checkInSheet() {
    CheckInSheet({
      message: this.checkInText,
      bpm: this.checkInBpm,
      time: this.checkInTime,
      simulated: this.checkInSim,
      onFine: () => {
        this.checkIn = false;
        AgentCore.get().send(QUICK_REPLY_OK);
      },
      onUnwell: () => {
        // Continue in the chat: it sends the answer and handles whatever the agent decides next.
        this.checkIn = false;
        AgentPrompt.ask(QUICK_REPLY_UNWELL);
      },
      onHelp: () => {
        this.checkIn = false;
        this.navStack.pushPathByName(Routes.SOS, new SosParam(false, `heart rate ${this.checkInBpm}`, false));
      }
    })
  }

  @Builder
  routeMap(name: string, param: Object) {
    if (name === Routes.ONBOARDING) {
      OnboardingPage()
    } else if (name === Routes.CHECK_RESULT) {
      CheckResultPage()
    } else if (name === Routes.HISTORY) {
      HistoryPage()
    } else if (name === Routes.SETTINGS) {
      SettingsPage()
    } else if (name === Routes.SOS) {
      SosPage()
    } else if (name === Routes.BYSTANDER) {
      BystanderPage()
    } else if (name === Routes.DOCTOR_PREP) {
      DoctorPrepPage()
    } else if (name === Routes.PHARMACY_CARD) {
      PharmacyCardPage()
    } else if (name === Routes.PRIVACY) {
      PrivacyPage()
    } else if (name === Routes.SYMPTOM_LOG) {
      SymptomLogPage()
    } else if (name === Routes.REMINDERS) {
      RemindersPage()
    } else if (name === Routes.AGENT_CHAT) {
      AgentPage()
    } else if (name === Routes.SCAN) {
      ScanPage()
    }
  }

  build() {
    Stack() {
      Navigation(this.navStack) {
        MainTabs()
      }
      .hideTitleBar(true)
      .mode(NavigationMode.Stack)
      .backgroundColor($r('app.color.bg'))
      .navDestination(this.routeMap)

      // App lock (F-45): covers private data; the emergency card and bystander help stay reachable from it.
      if (this.locked) {
        LockScreen({
          onEmergency: () => {
            AppLock.allowEmergency();
            this.navStack.pushPathByName(Routes.BYSTANDER, null);
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .bindSheet(this.checkIn, this.checkInSheet(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      showClose: false,
      backgroundColor: $r('app.color.bg'),
      radius: { topLeft: 28, topRight: 28 },
      maskColor: $r('app.color.scrim'),
      onDisappear: () => {
        this.checkIn = false;
      }
    })
  }
}
