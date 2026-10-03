// Today tab (DESIGN.md §10.1a, screen 01): header, the agent's one line, the next dose, resting heart rate over
// seven days, four quick actions, the medicines chip and the tip. Everything here is deterministic data; the agent
// itself is one tap away (the line, or the orb in the tab bar).

import { ComboVerdict, RiskLevel } from '../model/DrugVerdict';
import { VitalsSample } from '../model/Vitals';
import { VitalsService } from '../vitals/VitalsService';
import { RiskCounts } from '../drugs/MedsReview';
import { Routes, TabIndex } from '../common/Routes';
import { CoachTip, tipOfTheDay } from '../coach/Coach';
import { TravelService, travelCountry } from '../emergency/TravelService';
import { emergencyFor, systemCountry } from '../common/EmergencyNumbers';
import { cardText, languageForCountry } from '../common/CardStrings';
import { dayHello, doseWhen } from '../components/agent/AgentLogic';
import { Brief, HomeBrief } from '../components/agent/HomeBrief';
import { AgentAvatar } from '../components/AgentAvatar';
import { RiskShape, RoundIconButton, SourceBadge, StatusChip } from '../components/Common';
import { ReminderService } from '../reminders/ReminderService';
import { loadTrends, TrendData, TrendDay, TrendStats, trendStats } from '../vitals/Trends';
import { pulse } from '../common/Haptics';

const MONTHS: string[] = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September',
  'October', 'November', 'December'];
const DAYS: string[] = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const WEEK: number = 7;
const BAR_MAX: number = 40;
const BAR_MIN: number = 8;
const RING: number = 84;

@ComponentV2
export struct HomePage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Consumer('tabIndex') activeTab: number = TabIndex.HOME;
  @Local brief: Brief = HomeBrief.latest();
  @Local hr: VitalsSample | undefined = undefined;
  @Local here: string = TravelService.current();
  @Local trend: TrendData | undefined = undefined;
  @Local tipOpen: boolean = false;
  @Local now: number = Date.now();
  private offs: (() => void)[] = [];

  aboutToAppear(): void {
    this.offs.push(TravelService.onChange((c: string) => {
      this.here = c;
    }));
    this.offs.push(HomeBrief.onChange((b: Brief) => {
      this.brief = b;
      this.now = Date.now();
    }));
    this.hr = VitalsService.get().latest();
    this.offs.push(VitalsService.get().onSample((s: VitalsSample) => {
      this.hr = s;
    }));
    this.loadTrend();
  }

  aboutToDisappear(): void {
    for (const off of this.offs) {
      off();
    }
    this.offs = [];
  }

  // Coming back to the tab: the week may have a new day and the clock has moved.
  @Monitor('activeTab')
  onTab(m: IMonitor): void {
    if (this.activeTab === TabIndex.HOME) {
      this.now = Date.now();
      this.loadTrend();
      HomeBrief.refresh();
    }
  }

  private async loadTrend(): Promise<void> {
    this.trend = await loadTrends(Date.now(), WEEK * 2);
  }

  private firstName(): string {
    const name: string = this.brief.profile?.name ?? '';
    return name.length > 0 ? name.split(' ')[0] : '';
  }

  private today(): string {
    const d: Date = new Date(this.now);
    return `${DAYS[d.getDay()]}, ${d.getDate()} ${MONTHS[d.getMonth()]}`;
  }

  // ---- medicines chip ------------------------------------------------------------------------------------------

  private counts(): RiskCounts {
    return this.brief.counts;
  }

  // Medicines that need a conversation with the doctor (anything but Not listed).
  private toReview(): number {
    const c: RiskCounts = this.counts();
    return c.known + c.possible + c.conditional + c.unknown;
  }

  private medsRisk(): RiskLevel {
    const c: RiskCounts = this.counts();
    if (c.known > 0) {
      return 'KNOWN_RISK';
    }
    if (c.possible > 0) {
      return 'POSSIBLE_RISK';
    }
    if (c.conditional > 0) {
      return 'CONDITIONAL_RISK';
    }
    return c.unknown > 0 ? 'UNKNOWN_DRUG' : 'NOT_LISTED';
  }

  private medsChip(): ResourceStr {
    const n: number = this.brief.meds.length;
    if (n === 0) {
      return $r('app.string.home_meds_none');
    }
    const review: number = this.toReview();
    if (review > 0) {
      return $r('app.string.home_meds_review', review);
    }
    if (n === 1) {
      return $r('app.string.home_meds_ok');
    }
    return $r('app.string.home_meds_checked', n);
  }

  // ---- travel and tip ------------------------------------------------------------------------------------------

  private abroad(): string {
    return travelCountry(this.here, this.brief.profile?.country ?? systemCountry());
  }

  private coachTip(): CoachTip {
    return tipOfTheDay(this.brief.profile?.genotype ?? 'UNKNOWN', this.now);
  }

  // ---- resting week --------------------------------------------------------------------------------------------

  private week(): TrendDay[] {
    return this.trend === undefined ? [] : this.trend.days.slice(-WEEK);
  }

  private weekHasData(): boolean {
    return this.week().some((d: TrendDay) => d.restingBpm > 0);
  }

  private barHeight(d: TrendDay): number {
    const values: number[] = this.week().filter((x: TrendDay) => x.restingBpm > 0).map((x: TrendDay) => x.restingBpm);
    if (d.restingBpm <= 0 || values.length === 0) {
      return 2;
    }
    const lo: number = Math.min(...values) - 6;
    const hi: number = Math.max(...values);
    return hi <= lo ? BAR_MAX : BAR_MIN + (BAR_MAX - BAR_MIN) * (d.restingBpm - lo) / (hi - lo);
  }

  // "64 avg · 2 lower than last week": numbers reported, never judged.
  private weekLine(): ResourceStr {
    if (this.trend === undefined) {
      return $r('app.string.a11y_loading');
    }
    if (!this.weekHasData()) {
      return $r('app.string.today_week_empty');
    }
    const avg: number = trendStats(this.week()).avgResting;
    const all: TrendStats = trendStats(this.trend.days);
    if (!all.hasChange || all.change === 0) {
      return $r('app.string.today_week_avg', avg);
    }
    const by: number = Math.abs(all.change);
    return all.change < 0 ? $r('app.string.today_week_lower', avg, by) : $r('app.string.today_week_higher', avg, by);
  }

  // Map 40–180 bpm onto the ring so a resting rate fills roughly a third (same scale as the Health ring).
  private ringValue(): number {
    const bpm: number = this.hr?.hr ?? 0;
    return bpm <= 0 ? 0 : Math.max(4, Math.min(100, (bpm - 40) / 140 * 100));
  }

  private focusName(): string {
    return this.brief.focus === undefined ? '' : this.brief.focus.reminder.medName;
  }

  private bpmNow(): number {
    return this.hr === undefined ? 0 : Math.round(this.hr.hr);
  }

  private openAgent(): void {
    this.navStack.pushPathByName(Routes.AGENT_CHAT, null);
  }

  private async takeDose(): Promise<void> {
    if (this.brief.focus === undefined) {
      return;
    }
    pulse(20);
    await ReminderService.mark(this.brief.focus.reminder, 'TAKEN');
    HomeBrief.refresh();
  }

  // ---- builders ------------------------------------------------------------------------------------------------

  @Builder
  capsLabel(text: ResourceStr) {
    Text(text)
      .fontSize($r('app.float.font_caption'))
      .fontWeight(FontWeight.Bold)
      .letterSpacing(0.7)
      .fontColor($r('app.color.ink_3'))
      .textCase(TextCase.UpperCase)
  }

  @Builder
  header() {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text(this.today())
          .fontSize($r('app.float.font_small'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ink_3'))
        Text(dayHello(new Date(this.now).getHours(), this.firstName()))
          .fontSize($r('app.float.font_title_3'))
          .fontWeight(800)
          .fontColor($r('app.color.ink'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (this.brief.profile !== undefined && this.brief.profile.genotype !== 'UNKNOWN') {
        Text(this.brief.profile.genotype)
          .fontSize($r('app.float.font_badge'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .height(32)
          .padding({ left: 12, right: 12 })
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.border') })
          .borderRadius(16)
      }
      RoundIconButton({
        icon: $r('app.media.ic_settings'),
        label: $r('app.string.a11y_settings'),
        onTap: () => {
          this.navStack.pushPathByName(Routes.SETTINGS, null);
        }
      })
    }
    .width('100%')
    .padding({ top: 12 })
  }

  // Travel banner (T23): where the phone is, the local emergency number, pharmacy card language.
  @Builder
  travelBanner() {
    Row({ space: 12 }) {
      Image($r('app.media.ic_location')).width(18).height(18).fillColor($r('app.color.ink_2'))
      Column({ space: 2 }) {
        Text(`You're in ${emergencyFor(this.abroad()).name}`)
          .fontSize($r('app.float.font_headline'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Text(`Emergency ${emergencyFor(this.abroad()).general} · Pharmacy card in ` +
          `${cardText(languageForCountry(this.abroad())).language}`)
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink_2'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Image($r('app.media.ic_chevron_right')).width(16).height(16).fillColor($r('app.color.ink_4'))
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_m'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
    .accessibilityGroup(true)
    .onClick(() => {
      this.navStack.pushPathByName(Routes.PHARMACY_CARD, null);
    })
  }

  // The agent's one line. Tap: the agent stage.
  @Builder
  agentLine() {
    Row({ space: 12 }) {
      AgentAvatar({ dim: 40 })
      Text(this.brief.line)
        .fontSize($r('app.float.font_button'))
        .fontWeight(600)
        .lineHeight(21)
        .fontColor($r('app.color.ink'))
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Image($r('app.media.ic_chevron_right')).width(16).height(16).fillColor($r('app.color.ink_3'))
    }
    .width('100%')
    .padding({ left: 12, right: 14, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_ml'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
    .accessibilityGroup(true)
    .accessibilityDescription($r('app.string.a11y_today_agent'))
    .onClick(() => {
      this.openAgent();
    })
  }

  @Builder
  takenPill() {
    Row({ space: 6 }) {
      Image($r('app.media.ic_check')).width(16).height(16).fillColor($r('app.color.chat_user_text'))
      Text($r('app.string.rem_taken'))
        .fontSize($r('app.float.font_button'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.chat_user_text'))
    }
    .height($r('app.float.touch_min'))
    .padding({ left: 16, right: 18 })
    .borderRadius(24)
    .backgroundColor($r('app.color.chat_user_bg'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
    .accessibilityGroup(true)
    .accessibilityText($r('app.string.rem_taken_a11y', this.focusName()))
    .onClick(() => {
      this.takeDose();
    })
  }

  @Builder
  nextDose() {
    Column({ space: 12 }) {
      Row() {
        this.capsLabel($r('app.string.today_next_dose'))
        Blank()
        Text(this.brief.reminders.length === 0 ? $r('app.string.today_set_reminder') :
          $r('app.string.today_all_reminders'))
          .fontSize($r('app.float.font_badge'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand_text'))
          .padding({ top: 6, bottom: 6, left: 8 })
          .onClick(() => {
            this.navStack.pushPathByName(Routes.REMINDERS, null);
          })
      }
      .width('100%')
      Row({ space: 12 }) {
        Row() {
          Image($r('app.media.ic_pill')).width(22).height(22).fillColor($r('app.color.ink_2'))
        }
        .width(44)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.surface_alt'))
        .borderRadius($r('app.float.radius_s'))
        if (this.brief.focus !== undefined) {
          Column({ space: 2 }) {
            Text(this.brief.focus.reminder.medName)
              .fontSize($r('app.float.font_headline'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(doseWhen(this.brief.focus, this.now))
              .fontSize($r('app.float.font_small'))
              .fontColor(this.brief.focus.status === 'MISSED' ? $r('app.color.risk_possible_text') :
                $r('app.color.ink_3'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          this.takenPill()
        } else {
          Text(this.brief.reminders.length === 0 ? $r('app.string.rem_none_today') : $r('app.string.rem_all_done'))
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink_2'))
            .layoutWeight(1)
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_l'))
  }

  // Live bpm in a small ring with its source badge, then the week as seven bars. Daily averages, never a trace.
  @Builder
  restingWeek() {
    Row({ space: 16 }) {
      Column({ space: 6 }) {
        Stack() {
          Progress({ value: this.ringValue(), total: 100, type: ProgressType.Ring })
            .width(RING)
            .height(RING)
            .color($r('app.color.brand_accent'))
            .backgroundColor($r('app.color.border'))
            .style({ strokeWidth: 6 })
          Column() {
            Text(this.hr === undefined ? '--' : `${Math.round(this.hr.hr)}`)
              .fontSize($r('app.float.font_title'))
              .fontWeight(800)
              .fontColor($r('app.color.ink'))
            Text($r('app.string.trends_bpm'))
              .fontSize($r('app.float.font_micro'))
              .fontColor($r('app.color.ink_3'))
          }
        }
        SourceBadge({
          label: this.hr?.source === 'WATCH' ? $r('app.string.badge_watch') : $r('app.string.badge_simulated'),
          solid: this.hr?.source === 'WATCH'
        })
      }
      Column({ space: 8 }) {
        this.capsLabel($r('app.string.today_resting_week'))
        Row({ space: 4 }) {
          ForEach(this.week(), (d: TrendDay, i: number) => {
            Row()
              .layoutWeight(1)
              .height(this.barHeight(d))
              .borderRadius(4)
              .backgroundColor(i === this.week().length - 1 ? $r('app.color.brand_accent') :
                $r('app.color.brand_accent_soft'))
          }, (d: TrendDay, i: number) => `${d.day}-${d.restingBpm}-${i}`)
        }
        .width('100%')
        .height(BAR_MAX)
        .alignItems(VerticalAlign.Bottom)
        Text(this.weekLine())
          .fontSize($r('app.float.font_small'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ink_2'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Image($r('app.media.ic_chevron_right')).width(16).height(16).fillColor($r('app.color.ink_3'))
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_l'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
    .accessibilityGroup(true)
    .accessibilityText($r('app.string.a11y_today_heart', this.bpmNow()))
    .onClick(() => {
      this.activeTab = TabIndex.HEART;
    })
  }

  @Builder
  tile(label: Resource, icon: Resource, onTap: () => void) {
    Row({ space: 10 }) {
      Row() {
        Image(icon).width(20).height(20).fillColor($r('app.color.brand_accent'))
      }
      .width(36)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.brand_accent_soft'))
      .borderRadius(10)
      Text(label)
        .fontSize($r('app.float.font_button'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .maxLines(2)
        .layoutWeight(1)
    }
    .layoutWeight(1)
    .height(64)
    .padding({ left: 12, right: 10 })
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_ml'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
    .accessibilityGroup(true)
    .accessibilityText(label)
    .onClick(onTap)
  }

  @Builder
  quickActions() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        this.tile($r('app.string.home_scan_box'), $r('app.media.ic_scan'), () => {
          this.navStack.pushPathByName(Routes.SCAN, null);
        })
        this.tile($r('app.string.home_log_feel'), $r('app.media.ic_tab_heart'), () => {
          this.navStack.pushPathByName(Routes.SYMPTOM_LOG, null);
        })
      }
      .width('100%')
      Row({ space: 10 }) {
        this.tile($r('app.string.doctor_visit'), $r('app.media.ic_doctor'), () => {
          this.navStack.pushPathByName(Routes.DOCTOR_PREP, null);
        })
        this.tile($r('app.string.home_check'), $r('app.media.ic_pill'), () => {
          this.activeTab = TabIndex.MEDICINES;
        })
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  interaction(c: ComboVerdict) {
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
    .accessibilityGroup(true)
    .onClick(() => {
      this.activeTab = TabIndex.MEDICINES;
    })
  }

  // Tip of the day (F-39): static, sourced genotype tips — never AI, never a risk colour. Collapsed by default.
  @Builder
  tip() {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        this.capsLabel($r('app.string.today_tip'))
        Text(this.coachTip().title)
          .fontSize($r('app.float.font_button'))
          .fontWeight(600)
          .fontColor($r('app.color.ink'))
          .maxLines(this.tipOpen ? 3 : 1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Image($r('app.media.ic_chevron_right'))
          .width(14)
          .height(14)
          .fillColor($r('app.color.ink_3'))
          .rotate({ angle: this.tipOpen ? -90 : 90 })
      }
      .width('100%')
      if (this.tipOpen) {
        Text(this.coachTip().body)
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink_2'))
          .lineHeight(20)
          .width('100%')
      }
    }
    .width('100%')
    .constraintSize({ minHeight: $r('app.float.chip_height') })
    .justifyContent(FlexAlign.Center)
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.surface_alt'))
    .borderRadius($r('app.float.radius_btn'))
    .accessibilityGroup(true)
    .accessibilityDescription(this.tipOpen ? $r('app.string.a11y_expanded') : $r('app.string.a11y_collapsed'))
    .onClick(() => {
      this.tipOpen = !this.tipOpen;
    })
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        this.header()
        if (this.abroad() !== '') {
          this.travelBanner()
        }
        this.agentLine()
        this.nextDose()
        this.restingWeek()
        this.quickActions()
        Row() {
          StatusChip({
            label: this.medsChip(),
            risk: this.brief.meds.length === 0 ? undefined : this.medsRisk(),
            onTap: () => {
              this.activeTab = TabIndex.MEDICINES;
            }
          })
        }
        .width('100%')
        ForEach(this.brief.interactions, (c: ComboVerdict) => {
          this.interaction(c)
        }, (c: ComboVerdict) => c.drugs.join('+'))
        this.tip()
      }
      .padding({ left: $r('app.float.space_m'), right: $r('app.float.space_m'), bottom: 48 })
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .backgroundColor($r('app.color.bg'))
  }
}
