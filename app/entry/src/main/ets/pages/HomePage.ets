// Agent tab = home (design B1): date and greeting, heart-rate ring, status chips and the agent card with the two
// main actions. Everything else lives on the Medicines, Heart and Emergency tabs.

import { LocalStore, StoreTopic } from '../data/LocalStore';
import { Profile } from '../model/Profile';
import { Medication } from '../model/Medication';
import { ComboVerdict, RiskLevel } from '../model/DrugVerdict';
import { VitalsSample } from '../model/Vitals';
import { VitalsService } from '../vitals/VitalsService';
import { medsInteractions, riskCounts, RiskCounts } from '../drugs/MedsReview';
import { Routes, TabIndex } from '../common/Routes';
import { PrimaryButton, QuietButton, RiskShape, StatusChip } from '../components/Common';
import { AgentAvatar } from '../components/AgentAvatar';
import { HrRing, HrZone } from '../components/HrRing';

const MONTHS: string[] = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September',
  'October', 'November', 'December'];
const DAYS: string[] = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

@ComponentV2
export struct HomePage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Consumer('tabIndex') activeTab: number = TabIndex.HOME;
  @Local profile: Profile | undefined = undefined;
  @Local meds: Medication[] = [];
  @Local counts: RiskCounts = new RiskCounts();
  @Local interactions: ComboVerdict[] = [];
  @Local hr: VitalsSample | undefined = undefined;
  private offStore: () => void = () => {
  };
  private offHr: () => void = () => {
  };

  aboutToAppear(): void {
    this.reload();
    this.offStore = LocalStore.get().onChange((t: StoreTopic) => {
      if (t === 'profile' || t === 'meds') {
        this.reload();
      }
    });
    this.hr = VitalsService.get().latest();
    this.offHr = VitalsService.get().onSample((s: VitalsSample) => {
      this.hr = s;
    });
  }

  aboutToDisappear(): void {
    this.offStore();
    this.offHr();
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

  private today(): string {
    const d: Date = new Date();
    return `${DAYS[d.getDay()]}, ${d.getDate()} ${MONTHS[d.getMonth()]}`;
  }

  private clock(): string {
    const d: Date = new Date();
    const m: number = d.getMinutes();
    return `${d.getHours()}:${m < 10 ? '0' : ''}${m}`;
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
    return n === 0 ? $r('app.string.home_meds_ok') : `${n} to review`;
  }

  private zone(): HrZone {
    const bpm: number = this.hr?.hr ?? 0;
    if (bpm <= 0 || this.hr?.asleep === true) {
      return 'CALM';
    }
    const resting: boolean = (this.hr?.steps ?? 0) <= 60;
    return (resting && bpm >= 120) || bpm < 45 ? 'ELEVATED' : 'CALM';
  }

  private caption(): Resource {
    if (this.hr === undefined) {
      return $r('app.string.home_bpm_waiting');
    }
    if (this.hr.asleep === true) {
      return $r('app.string.home_bpm_asleep');
    }
    return (this.hr.steps ?? 0) > 60 ? $r('app.string.home_bpm_active') : $r('app.string.home_bpm_resting');
  }

  // The agent's opening line. Built from deterministic data only; supportive, never blaming.
  private agentLine(): string {
    const h: number = new Date().getHours();
    const part: string = h < 12 ? 'Morning' : (h < 18 ? 'Afternoon' : 'Evening');
    const name: string = this.firstName();
    const hello: string = name.length > 0 ? `${part}, ${name}.` : `Good ${part.toLowerCase()}.`;
    if (this.interactions.length > 0) {
      return `${hello} Two of your medicines may interact. Let's check that with your doctor.`;
    }
    if (this.counts.known > 0) {
      return `${hello} One of your medicines is on the QT list. Let's go through it with your doctor.`;
    }
    return `${hello} Everything looks calm. Got a new prescription? I can check it in seconds.`;
  }

  @Builder
  agentCard() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        AgentAvatar({ dim: 28 })
        Text($r('app.string.agent_name'))
          .fontSize($r('app.float.font_body'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .layoutWeight(1)
        Text(this.clock())
          .fontSize($r('app.float.font_badge'))
          .fontColor($r('app.color.ink_3'))
      }
      .width('100%')
      Text(this.agentLine())
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Medium)
        .lineHeight(23)
        .fontColor($r('app.color.ink'))
        .width('100%')
      ForEach(this.interactions, (c: ComboVerdict) => {
        Row({ space: 8 }) {
          RiskShape({ risk: 'POSSIBLE_RISK', dim: 18 })
          Text(`${c.drugs.join(' + ')}: ${c.kind === 'CYP_INTERACTION' ? `interaction (${c.enzyme})` :
            'both affect QT'}`)
            .fontSize($r('app.float.font_small'))
            .fontColor($r('app.color.risk_possible_text'))
            .layoutWeight(1)
        }
        .width('100%')
        .padding(10)
        .backgroundColor($r('app.color.risk_possible_tint'))
        .borderRadius($r('app.float.radius_s'))
      }, (c: ComboVerdict) => c.drugs.join('+'))
      Row({ space: 10 }) {
        PrimaryButton({
          label: $r('app.string.home_scan_box'),
          icon: $r('app.media.ic_box'),
          onTap: () => {
            this.navStack.pushPathByName(Routes.SCAN, null);
          }
        })
          .layoutWeight(1)
        QuietButton({
          label: $r('app.string.home_ask'),
          onTap: () => {
            this.navStack.pushPathByName(Routes.AGENT_CHAT, null);
          }
        })
          .layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_l'))
  }

  build() {
    Scroll() {
      Column() {
        // Date, greeting, genotype
        Row({ space: 8 }) {
          Column({ space: 2 }) {
            Text(this.today())
              .fontSize($r('app.float.font_small'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.ink_3'))
            Text(this.firstName().length > 0 ? `Hi ${this.firstName()}` : 'Hi')
              .fontSize($r('app.float.font_title_1'))
              .fontWeight(800)
              .fontColor($r('app.color.ink'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          if (this.profile !== undefined && this.profile.genotype !== 'UNKNOWN') {
            Text(this.profile.genotype)
              .fontSize($r('app.float.font_badge'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
              .height(32)
              .padding({ left: 12, right: 12 })
              .backgroundColor($r('app.color.surface'))
              .border({ width: 1, color: $r('app.color.border') })
              .borderRadius(16)
          }
          Row() {
            Image($r('app.media.ic_settings')).width(22).height(22).fillColor($r('app.color.ink_3'))
          }
          .width($r('app.float.touch_min'))
          .height($r('app.float.touch_min'))
          .justifyContent(FlexAlign.Center)
          .accessibilityText($r('app.string.a11y_settings'))
          .onClick(() => {
            this.navStack.pushPathByName(Routes.SETTINGS, null);
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)
        .padding({ top: 16 })

        HrRing({
          bpm: this.hr?.hr ?? 0,
          caption: this.caption(),
          zone: this.zone(),
          live: this.hr !== undefined,
          simulated: this.hr?.source !== 'WATCH'
        })
          .margin({ top: 24, bottom: 20 })
          .onClick(() => {
            this.activeTab = TabIndex.HEART;
          })

        Row({ space: 8 }) {
          StatusChip({
            label: this.medsChip(),
            risk: this.meds.length === 0 ? undefined : this.medsRisk(),
            onTap: () => {
              this.activeTab = TabIndex.MEDICINES;
            }
          })
          StatusChip({
            label: $r('app.string.home_alarm_on'),
            onTap: () => {
              this.activeTab = TabIndex.HEART;
            }
          })
        }
        .margin({ bottom: 20 })

        this.agentCard()
      }
      .padding({ left: $r('app.float.space_screen'), right: $r('app.float.space_screen'), bottom: 24 })
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .backgroundColor($r('app.color.bg'))
  }
}
