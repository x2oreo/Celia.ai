// App root: Navigation + NavPathStack hosting the bottom tabs. Full-screen flows (onboarding, check result,
// history, SOS, …) are pushed as NavDestinations by route name — see common/Routes.ets.

import { TravelService } from '../emergency/TravelService';
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
import { CardViewPage } from './CardViewPage';
import { ChatsPage } from './ChatsPage';
import { AgentPage } from './AgentPage';
import { ScanPage } from './ScanPage';
import { LockScreen } from '../components/LockScreen';
import { Routes, SosParam } from '../common/Routes';
import { LocalStore } from '../data/LocalStore';
import { Profile } from '../model/Profile';
import { VitalsAlert, VitalsSample, WatchSos } from '../model/Vitals';
import { LiveStatus } from '../emergency/LiveStatus';
import { HeartOkRequest } from '../common/HeartOkRequest';
import { pulse } from '../common/Haptics';
import { VitalsService } from '../vitals/VitalsService';
import { WearNotifier } from '../vitals/WearNotifier';
import { SosController } from '../emergency/SosController';
import { askNotificationPermission } from '../common/Notify';
import { AppLock } from '../common/AppLock';
import { ReminderService } from '../reminders/ReminderService';
import { BetaBlockerWatch } from '../vitals/BetaBlockerWatch';
import { WatchPairing } from '../data/WatchPairing';
import { TrendsPage } from './TrendsPage';
import { PairWatchPage } from './PairWatchPage';
import { WelcomePage } from './WelcomePage';
import { AuthPage } from './AuthPage';
import { AccountPage } from './AccountPage';
import { EmergencyProfilePage } from './EmergencyProfilePage';
import { ResponderPage } from './ResponderPage';
import { VisitsPage } from './VisitsPage';
import { FeelingPage } from './FeelingPage';
import { Session, launchRoute } from '../account/Session';
import { ProfileSync } from '../account/ProfileSync';
import { SosContacts } from '../account/SosContacts';
import { AgentCore, QUICK_REPLY_OK, QUICK_REPLY_UNWELL } from '../agent/AgentCore';
import { CheckInSheet } from '../components/CheckInSheet';
import { clock } from '../common/Format';
import { toast } from '../common/Toast';
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
    // The Celia watch via Supabase when a backend is configured; otherwise the labelled simulated source.
    // The paired watch's id (if any) is loaded first, so nothing ever polls the wrong watch.
    WatchPairing.load().then(() => {
      VitalsService.get().start('WATCH');
      BetaBlockerWatch.start();
      WatchPairing.startGenotypeSync();
    });
    WearNotifier.start();
    VitalsService.get().onAlert((a: VitalsAlert) => this.onAlert(a));
    VitalsService.get().onWatchAnswer((kind: string) => this.onWatchAnswer(kind));
    HeartOkRequest.onSend(() => this.onNotifyOk());
    AgentCore.get().onProactive((r: AgentReply) => this.onAgentProactive(r));
    AgentPrompt.onOpenChat(() => this.openChat());
    RouteRequest.onOpen((route: string) => this.openRoute(route));
    this.openRoute(RouteRequest.take());
    askNotificationPermission(this.getUIContext().getHostContext() as common.UIAbilityContext);
    TravelService.detect();   // only with location already allowed; never asks
    AppLock.onLockChange((locked: boolean) => {
      this.locked = locked;
    });
    this.locked = AppLock.isLocked();
    ReminderService.handleLaunch();
    setInterval(() => {
      ReminderService.checkDue(Date.now());
    }, 30000);
  }

  // Launch routing (B1): a stored session goes straight in, offline too; a fresh install sees Welcome. Signed in with
  // no profile on the phone (new phone, or onboarding not finished): try to restore it first, else onboarding.
  private async showOnboardingIfNeeded(): Promise<void> {
    await Session.load();
    ProfileSync.start();
    await WatchPairing.load();
    WatchPairing.startAccountBinding();   // B9: a paired watch is readable only by its signed-in owner
    SosContacts.start();                  // B10: contacts to the server, only with consent
    let profile: Profile | undefined = await LocalStore.get().getProfile();
    if (launchRoute(Session.isSignedIn(), profile !== undefined) === 'WELCOME') {
      this.navStack.pushPathByName(Routes.WELCOME, null, false);
      return;
    }
    if (profile === undefined) {
      await ProfileSync.syncNow();
      profile = await LocalStore.get().getProfile();
      if (profile === undefined) {
        this.navStack.pushPathByName(Routes.ONBOARDING, null, false);
      }
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
    if (a.watchSos !== undefined) {
      this.onWatchSos(a.watchSos);
      return;
    }
    WearNotifier.vitalsAlert(a);
    if (a.severity !== 'CRITICAL' || !SosController.get().canAutoStart(Date.now())) {
      return;
    }
    const reason: string = a.hr > 0 ? `heart rate ${Math.round(a.hr)} — ${a.kind.toLowerCase().replace(/_/g, ' ')}` :
      a.kind.toLowerCase().replace(/_/g, ' ');
    this.checkIn = false;
    this.navStack.pushPathByName(Routes.SOS, new SosParam(false, reason, true));
  }

  // The watch counted down and sent its SOS already: show what was sent and what still needs a tap, never a second
  // countdown (B8). An SOS page that is already open picks the new state up on its next tick.
  private onWatchSos(w: WatchSos): void {
    SosController.get().watchSent(Date.now(), w.withLocation);
    LiveStatus.watchSos();
    pulse(600);
    this.checkIn = false;
    if (this.navStack.getAllPathName().includes(Routes.SOS)) {
      return;
    }
    const reason: string = w.reason === 'fall' ? 'a fall with no answer on your watch' : 'you asked for help on your watch';
    this.navStack.pushPathByName(Routes.SOS, new SosParam(false, reason, true, 'WATCH'));
  }

  // "I'm OK" on a heart-alert notification answers an open check-in like the sheet's "I'm fine".
  private onNotifyOk(): void {
    if (!this.checkIn && !AgentCore.get().isCheckInPending()) {
      return;
    }
    this.checkIn = false;
    AgentCore.get().send(QUICK_REPLY_OK);
  }

  // An answer on the watch's "How do you feel?" counts as the same answer on the phone: it closes the check-in and
  // does exactly what the matching phone button does, so one heart-rate event never needs two answers.
  private onWatchAnswer(kind: string): void {
    if (!this.checkIn && !AgentCore.get().isCheckInPending()) {
      return;
    }
    this.checkIn = false;
    if (kind === 'fine') {
      AgentCore.get().send(QUICK_REPLY_OK);
      toast(this.getUIContext(), $r('app.string.checkin_answered_watch_ok'));
    } else {
      AgentPrompt.ask(QUICK_REPLY_UNWELL);
    }
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
    } else if (name === Routes.CARD_VIEW) {
      CardViewPage()
    } else if (name === Routes.CHATS) {
      ChatsPage()
    } else if (name === Routes.AGENT_CHAT) {
      AgentPage()
    } else if (name === Routes.SCAN) {
      ScanPage()
    } else if (name === Routes.PAIR_WATCH) {
      PairWatchPage()
    } else if (name === Routes.TRENDS) {
      TrendsPage()
    } else if (name === Routes.WELCOME) {
      WelcomePage()
    } else if (name === Routes.AUTH) {
      AuthPage()
    } else if (name === Routes.ACCOUNT) {
      AccountPage()
    } else if (name === Routes.EMERGENCY_PROFILE) {
      EmergencyProfilePage()
    } else if (name === Routes.RESPONDER) {
      ResponderPage()
    } else if (name === Routes.VISITS) {
      VisitsPage()
    } else if (name === Routes.FEELING) {
      FeelingPage()
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
