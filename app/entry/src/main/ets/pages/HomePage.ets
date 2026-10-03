// Agent tab = the agent itself (DESIGN.md §10.1a): status strip, notes strip, then the one conversation with the
// quick-action row above its dock. Everything the old Home dashboard offered is in the two strips.

import { LocalStore, StoreTopic } from '../data/LocalStore';
import { Profile } from '../model/Profile';
import { Medication } from '../model/Medication';
import { ComboVerdict, RiskLevel } from '../model/DrugVerdict';
import { VitalsSample } from '../model/Vitals';
import { VitalsService } from '../vitals/VitalsService';
import { medsInteractions, riskCounts, RiskCounts } from '../drugs/MedsReview';
import { Routes, TabIndex } from '../common/Routes';
import { TabRequest } from '../common/TabRequest';
import { CoachTip, tipOfTheDay } from '../coach/Coach';
import { TravelService, travelCountry } from '../emergency/TravelService';
import { emergencyFor, systemCountry } from '../common/EmergencyNumbers';
import { cardText, languageForCountry } from '../common/CardStrings';
import { dayGreeting } from '../components/agent/AgentLogic';
import { HomeStatus } from '../components/agent/HomeStatus';
import { HomeNotes } from '../components/agent/HomeNotes';
import { QuickActions } from '../components/agent/QuickActions';
import { AgentConversation } from './AgentPage';

@ComponentV2
export struct HomePage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Consumer('tabIndex') activeTab: number = TabIndex.HOME;
  @Local profile: Profile | undefined = undefined;
  @Local meds: Medication[] = [];
  @Local counts: RiskCounts = new RiskCounts();
  @Local interactions: ComboVerdict[] = [];
  @Local hr: VitalsSample | undefined = undefined;
  @Local here: string = TravelService.current();
  @Local covered: boolean = TabRequest.isCovered();   // a pushed page is over the tabs
  private offs: (() => void)[] = [];

  aboutToAppear(): void {
    this.offs.push(TravelService.onChange((c: string) => {
      this.here = c;
    }));
    this.reload();
    this.offs.push(LocalStore.get().onChange((t: StoreTopic) => {
      if (t === 'profile' || t === 'meds') {
        this.reload();
      }
    }));
    this.hr = VitalsService.get().latest();
    this.offs.push(VitalsService.get().onSample((s: VitalsSample) => {
      this.hr = s;
    }));
    this.offs.push(TabRequest.onCovered((covered: boolean) => {
      this.covered = covered;
    }));
  }

  aboutToDisappear(): void {
    for (const off of this.offs) {
      off();
    }
    this.offs = [];
  }

  // Several store changes can arrive at once; only the latest reload may write state.
  private reloadSeq: number = 0;

  private async reload(): Promise<void> {
    const seq: number = ++this.reloadSeq;
    const profile: Profile | undefined = await LocalStore.get().getProfile();
    const meds: Medication[] = await LocalStore.get().listMeds();
    if (seq !== this.reloadSeq) {
      return;
    }
    this.profile = profile;
    this.meds = meds;
    this.counts = riskCounts(meds);
    this.interactions = medsInteractions(meds);
  }

  private firstName(): string {
    const name: string = this.profile?.name ?? '';
    return name.length > 0 ? name.split(' ')[0] : '';
  }

  // Medicines that need a conversation with the doctor (anything but Not listed).
  private toReview(): number {
    return this.counts.known + this.counts.possible + this.counts.conditional + this.counts.unknown;
  }

  private medsRisk(): RiskLevel {
    if (this.counts.known > 0) {
      return 'KNOWN_RISK';
    }
    if (this.counts.possible > 0) {
      return 'POSSIBLE_RISK';
    }
    if (this.counts.conditional > 0) {
      return 'CONDITIONAL_RISK';
    }
    return this.counts.unknown > 0 ? 'UNKNOWN_DRUG' : 'NOT_LISTED';
  }

  private medsChip(): ResourceStr {
    if (this.meds.length === 0) {
      return $r('app.string.home_meds_none');
    }
    const n: number = this.toReview();
    return n === 0 ? $r('app.string.home_meds_ok') : $r('app.string.home_meds_review', n);
  }

  // The agent's opening line. Built from deterministic data only; supportive, never blaming.
  private agentLine(): string {
    const hello: string = dayGreeting(new Date().getHours(), this.firstName());
    if (this.interactions.length > 0) {
      return `${hello} Two of your medicines may interact. Let's check that with your doctor.`;
    }
    if (this.counts.known > 0) {
      return `${hello} One of your medicines is on the QT list. Let's go through it with your doctor.`;
    }
    return `${hello} Everything looks calm. Got a new prescription? I can check it in seconds.`;
  }

  private abroad(): string {
    return travelCountry(this.here, this.profile?.country ?? systemCountry());
  }

  private travelTitle(): string {
    return this.abroad() === '' ? '' : `You're in ${emergencyFor(this.abroad()).name}`;
  }

  private travelDetail(): string {
    return this.abroad() === '' ? '' : `Emergency ${emergencyFor(this.abroad()).general} · Pharmacy card in ` +
      `${cardText(languageForCountry(this.abroad())).language}`;
  }

  private coachTip(): CoachTip {
    return tipOfTheDay(this.profile?.genotype ?? 'UNKNOWN', Date.now());
  }

  private coachLabel(): string {
    const g: string = this.profile?.genotype ?? 'UNKNOWN';
    return g === 'UNKNOWN' ? 'TIP OF THE DAY' : `TIP FOR ${g}`;
  }

  @Builder
  quickActions() {
    QuickActions({
      onOpen: (route: string) => {
        this.navStack.pushPathByName(route, null);
      }
    })
  }

  build() {
    Column() {
      HomeStatus({
        bpm: this.hr?.hr ?? 0,
        simulated: this.hr?.source !== 'WATCH',
        medsLabel: this.medsChip(),
        medsRisk: this.meds.length === 0 ? undefined : this.medsRisk(),
        onHeart: () => {
          this.activeTab = TabIndex.HEART;
        },
        onMeds: () => {
          this.activeTab = TabIndex.MEDICINES;
        },
        onChats: () => {
          this.navStack.pushPathByName(Routes.CHATS, null);
        },
        onSettings: () => {
          this.navStack.pushPathByName(Routes.SETTINGS, null);
        }
      })
      HomeNotes({
        line: this.agentLine(),
        interactions: this.interactions,
        tipLabel: this.coachLabel(),
        tipTitle: this.coachTip().title,
        tipBody: this.coachTip().body,
        travelTitle: this.travelTitle(),
        travelDetail: this.travelDetail(),
        onAlarm: () => {
          this.activeTab = TabIndex.HEART;
        },
        onTravel: () => {
          this.navStack.pushPathByName(Routes.PHARMACY_CARD, null);
        }
      })
      AgentConversation({
        active: this.activeTab === TabIndex.HOME && !this.covered,
        aboveDock: (): void => {
          this.quickActions();
        }
      })
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg'))
  }
}
