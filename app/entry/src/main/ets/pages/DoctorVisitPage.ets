// One doctor visit (DESIGN.md §10.1a "07 Doctor visits"): the page you hand to the doctor. Share sits in the
// header. Top to bottom: who the patient is and why they came, what not to prescribe, a short AI summary, then the
// full brief folded away. Everything except the labelled AI summary is fixed data: the profile, the medicine list,
// the event log and the visit plan (doctor/VisitPlan.ets) built from the QT dataset.

import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { LocalStore } from '../data/LocalStore';
import { Profile } from '../model/Profile';
import { Medication } from '../model/Medication';
import { RiskLevel } from '../model/DrugVerdict';
import { DrugChecker } from '../drugs/DrugChecker';
import { BriefSection, buildBrief, specialtyName, VisitAnswers } from '../doctor/DoctorPrep';
import { AvoidDrug, cautionNames, knownNames, PlanGroup, visitPlan, visitText } from '../doctor/VisitPlan';
import { DoctorVisit, VisitStore, visitWhen } from '../doctor/VisitStore';
import { dayKey } from '../reminders/DoseSchedule';
import { DoctorSummary, SummaryOutcome, SummaryResult } from '../doctor/DoctorSummary';
import { buildReport, ReportPayload, reportVisit } from '../doctor/ReportPayload';
import { contentHash, ShareRecord, ShareService } from '../share/ShareService';
import { loadRestingHistory, demoHistory } from '../vitals/RestingHistory';
import { DailyResting } from '../vitals/RestingTrend';
import { ReminderService } from '../reminders/ReminderService';
import { copyText } from '../common/Clipboard';
import { dayLabel } from '../common/Format';
import { Motion } from '../common/Motion';
import { VisitParam } from '../common/Routes';
import { shareText } from '../common/Share';
import { toast } from '../common/Toast';
import { Logger } from '../common/Logger';
import {
  CapsLabel, QuietButton, resText, RiskBadge, RiskShape, SecondaryButton, TypingDots
} from '../components/Common';
import { QuietPill, SpecialtyWell } from '../components/VisitParts';

type SummaryState = 'IDLE' | 'LOADING' | SummaryResult;

const log: Logger = new Logger('DoctorVisitPage');
const REPORT_BRIEF_KEY: string = 'share.report.brief';   // hash of the brief behind the live report link
const MEDS_SHOWN: number = 4;
const SKIPPED_SECTIONS: string[] = ['Patient'];          // shown in the top card instead

const NO_VISIT: DoctorVisit = {
  id: 0, specialty: 'GP', doctor: '', reason: '', date: '', worries: '', createdAt: 0, summary: '', sharedAt: 0
};
const NO_PROFILE: Profile = { condition: 'LQTS', genotype: 'UNKNOWN', hasIcd: false, notes: '', contacts: [] };

@ComponentV2
export struct DoctorVisitPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local visit: DoctorVisit | undefined = undefined;
  @Local missing: boolean = false;
  @Local profile: Profile | undefined = undefined;
  @Local meds: Medication[] = [];
  @Local sections: BriefSection[] = [];
  @Local plan: PlanGroup[] = [];
  @Local open: string[] = [];
  @Local showCaution: boolean = false;
  @Local sending: boolean = false;
  @Local summaryState: SummaryState = 'IDLE';

  // Builders read the visit and the profile through these: a @Builder argument is passed by value and would keep
  // showing the old visit after the summary or the share time is saved.
  @Computed
  get v(): DoctorVisit {
    return this.visit ?? NO_VISIT;
  }

  @Computed
  get p(): Profile {
    return this.profile ?? NO_PROFILE;
  }

  private async load(id: number): Promise<void> {
    const v: DoctorVisit | undefined = await VisitStore.get(id);
    this.profile = await LocalStore.get().getProfile();
    if (v === undefined || this.profile === undefined) {
      this.missing = true;
      return;
    }
    this.meds = await LocalStore.get().listMeds();
    this.sections = buildBrief(this.profile, this.meds, await LocalStore.get().listScans(),
      await LocalStore.get().listEvents(), v.specialty, Date.now(), this.answers(v));
    this.plan = visitPlan(v.reason, v.specialty);
    this.visit = v;
    if (v.summary.length > 0) {
      this.summaryState = 'OK';
    } else if (DoctorSummary.available()) {
      this.summarise();
    }
  }

  private async summarise(): Promise<void> {
    const v: DoctorVisit | undefined = this.visit;
    if (v === undefined || this.profile === undefined || this.summaryState === 'LOADING') {
      return;
    }
    this.summaryState = 'LOADING';
    let out: SummaryOutcome;
    try {
      out = await DoctorSummary.fetch(this.sections, v.specialty, this.profile.genotype, this.plan);
    } catch (e) {
      out = new SummaryOutcome('FAILED', '');
    }
    if (out.result === 'OK') {
      await this.save(v, out.text, v.sharedAt);
    }
    this.summaryState = out.result;
  }

  private async save(v: DoctorVisit, summary: string, sharedAt: number): Promise<void> {
    const next: DoctorVisit = {
      id: v.id, specialty: v.specialty, doctor: v.doctor, reason: v.reason, date: v.date, worries: v.worries,
      createdAt: v.createdAt, summary: summary, sharedAt: sharedAt
    };
    this.visit = next;
    await VisitStore.update(next);
  }

  // "This visit" (date) and "What worries me" in the brief. The reason is left out: the page and the shared text
  // already lead with it.
  private answers(v: DoctorVisit): VisitAnswers {
    const a: VisitAnswers = { date: dayKey(visitWhen(v)), reason: '', worries: v.worries };
    return a;
  }

  private ctx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private text(v: DoctorVisit): string {
    return visitText(v.specialty, v.doctor, v.reason, this.plan, this.sections, Date.now());
  }

  private riskOf(m: Medication): RiskLevel {
    return DrugChecker.get().checkSync(m.ingredient !== '' ? m.ingredient : m.name).risk;
  }

  private factsLine(p: Profile): string {
    const ui: UIContext = this.getUIContext();
    return `${resText(ui, $r('app.string.dv_condition'))} · ` +
      `${p.genotype === 'UNKNOWN' ? resText(ui, $r('app.string.dv_genotype_unknown')) : p.genotype} · ` +
      resText(ui, p.hasIcd ? $r('app.string.dv_icd_yes') : $r('app.string.dv_icd_no'));
  }

  // Full structured report → encrypted share (the server deletes it after 48 hours). One report link is live at a
  // time, so while this visit is unchanged Share and Copy link reuse the link already made: a second tap must not
  // revoke the link a doctor just received. Another visit, or a change to this one, makes a new link.
  private async reportLink(v: DoctorVisit): Promise<string | undefined> {
    if (this.profile === undefined) {
      return undefined;
    }
    const briefKey: string = contentHash(`${v.id}\n${v.summary}\n${JSON.stringify(this.sections)}`);
    const current: ShareRecord | undefined = await ShareService.current('report');
    if (current !== undefined && (await LocalStore.get().getSetting(REPORT_BRIEF_KEY, '')) === briefKey) {
      return ShareService.url(current);
    }
    const now: number = Date.now();
    let resting: DailyResting[] = await loadRestingHistory(now);
    if (resting.length === 0) {
      resting = demoHistory(now);   // labelled SIMULATED in the report
    }
    const payload: ReportPayload = buildReport(this.profile, this.meds, await LocalStore.get().listScans(),
      await LocalStore.get().listEvents(), v.specialty, resting, await ReminderService.list(),
      await ReminderService.doseLog(), now, reportVisit(v.doctor, v.reason, this.plan, v.summary));
    const r: ShareRecord | undefined = await ShareService.share('report', JSON.stringify(payload));
    if (r === undefined) {
      return undefined;
    }
    await LocalStore.get().setSetting(REPORT_BRIEF_KEY, briefKey);
    return ShareService.url(r);
  }

  // The header button. With a backend it sends the encrypted link; without one it shares the brief as text.
  private async share(copyOnly: boolean): Promise<void> {
    const v: DoctorVisit | undefined = this.visit;
    if (v === undefined || this.sending) {
      return;
    }
    const ui: UIContext = this.getUIContext();
    if (!ShareService.available()) {
      if (await shareText(this.ctx(), 'Long QT safety brief', this.text(v))) {
        await this.save(v, v.summary, Date.now());
      }
      return;
    }
    this.sending = true;
    try {
      const url: string | undefined = await this.reportLink(v);
      if (url === undefined) {
        toast(ui, $r('app.string.dp_link_failed'));
        return;
      }
      if (copyOnly) {
        const ok: boolean = await copyText(url);
        toast(ui, ok ? $r('app.string.dp_link_copied') : $r('app.string.error_generic'));
      } else {
        shareText(this.ctx(), 'Long QT safety report', `${resText(ui, $r('app.string.dp_link_message'))}\n${url}`);
      }
      await this.save(v, v.summary, Date.now());
    } catch (e) {
      log.warn(`share visit: ${(e as Error).message}`);
      toast(ui, $r('app.string.dp_link_failed'));
    } finally {
      this.sending = false;
    }
  }

  private confirmDelete(v: DoctorVisit): void {
    const ui: UIContext = this.getUIContext();
    ui.getPromptAction().showDialog({
      title: resText(ui, $r('app.string.dv_delete_title')),
      message: resText(ui, $r('app.string.dv_delete_body')),
      buttons: [
        { text: resText(ui, $r('app.string.agent_cancel')), color: $r('app.color.ink_2') },
        { text: resText(ui, $r('app.string.chats_delete')), color: $r('app.color.danger') }
      ]
    }).then((r: promptAction.ShowDialogSuccessResponse) => {
      if (r.index === 1) {
        VisitStore.remove(v.id).then(() => {
          this.navStack.pop();
        }).catch((e: Error) => log.warn(`delete visit: ${e.message}`));
      }
    }).catch((e: Error) => log.warn(`delete dialog: ${e.message}`));
  }

  private toggle(title: string): void {
    this.open = this.open.includes(title) ? this.open.filter((t: string) => t !== title) :
      this.open.concat([title]);
  }

  // Back, who the page is for, and Share: the one thing the user came to do.
  @Builder
  header() {
    Row({ space: 4 }) {
      Row() {
        Image($r('app.media.ic_chevron_left')).width(24).height(24).fillColor($r('app.color.ink'))
      }
      .width($r('app.float.touch_min'))
      .height($r('app.float.touch_min'))
      .justifyContent(FlexAlign.Center)
      .accessibilityGroup(true)
      .accessibilityText($r('app.string.a11y_back'))
      .onClick(() => {
        this.navStack.pop();
      })
      Column({ space: 1 }) {
        Text(specialtyName(this.v.specialty))
          .fontSize($r('app.float.font_headline'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.v.doctor.length > 0 ? `${this.v.doctor} · ${dayLabel(visitWhen(this.v), Date.now())}` :
          dayLabel(visitWhen(this.v), Date.now()))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.ink_3'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Row({ space: 6 }) {
        Image($r('app.media.ic_share')).width(18).height(18).fillColor($r('app.color.on_accent'))
        Text(this.sending ? $r('app.string.dv_share_busy') : $r('app.string.dv_share'))
          .fontSize($r('app.float.font_button'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.on_accent'))
      }
      .height($r('app.float.chip_height'))
      .padding({ left: 16, right: 18 })
      .backgroundColor($r('app.color.brand_accent'))
      .borderRadius(22)
      .opacity(this.sending ? 0.5 : 1)
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
      .accessibilityGroup(true)
      .accessibilityText($r('app.string.dv_share_a11y'))
      .onClick(() => {
        this.share(false);
      })
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .padding({ left: 4, right: 16 })
  }

  // The first thing the doctor reads: who, what condition, why they came, what they take.
  @Builder
  glance() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        SpecialtyWell({ specialty: this.v.specialty, dim: 44 })
        Column({ space: 2 }) {
          Text(this.p.name !== undefined && this.p.name.length > 0 ? this.p.name : $r('app.string.dv_patient'))
            .fontSize($r('app.float.font_title_3'))
            .fontWeight(800)
            .fontColor($r('app.color.ink'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.factsLine(this.p))
            .fontSize($r('app.float.font_small'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand_text'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      Divider().color($r('app.color.divider'))
      Column({ space: 6 }) {
        CapsLabel({ text: $r('app.string.dv_here_for') })
        Text(this.v.reason.length > 0 ? this.v.reason : $r('app.string.dv_no_reason'))
          .fontSize($r('app.float.font_body'))
          .fontWeight(this.v.reason.length > 0 ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(this.v.reason.length > 0 ? $r('app.color.ink') : $r('app.color.ink_3'))
          .lineHeight(23)
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.plan, (g: PlanGroup) => {
            QuietPill({ label: g.title })
              .margin({ right: 6, top: 6 })
          }, (g: PlanGroup) => g.purpose)
        }
        .width('100%')
        if (this.v.worries.length > 0) {
          CapsLabel({ text: $r('app.string.dv_worries_label') })
            .margin({ top: 6 })
          Text(this.v.worries)
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.ink'))
            .lineHeight(23)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Divider().color($r('app.color.divider'))
      Column({ space: 8 }) {
        CapsLabel({ text: $r('app.string.dv_takes') })
        if (this.meds.length === 0) {
          Text($r('app.string.dv_no_meds'))
            .fontSize($r('app.float.font_small'))
            .fontColor($r('app.color.ink_3'))
        }
        ForEach(this.meds.slice(0, MEDS_SHOWN), (m: Medication) => {
          Row({ space: 8 }) {
            Text(`${m.name}${m.dose === '' ? '' : ` ${m.dose}`}`)
              .fontSize($r('app.float.font_button'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            RiskBadge({ risk: this.riskOf(m), compact: true })
          }
          .width('100%')
        }, (m: Medication) => `${m.id}`)
        if (this.meds.length > MEDS_SHOWN) {
          Text($r('app.string.dv_more', this.meds.length - MEDS_SHOWN))
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.ink_3'))
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.p.notes.length > 0) {
        Text(this.p.notes)
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink_2'))
          .lineHeight(20)
          .width('100%')
          .padding(10)
          .backgroundColor($r('app.color.surface_alt'))
          .borderRadius($r('app.float.radius_s'))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_l'))
  }

  @Builder
  nameChips(names: string[]) {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(names, (n: string) => {
        Text(n)
          .fontSize($r('app.float.font_small'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .height(30)
          .padding({ left: 10, right: 10 })
          .margin({ right: 6, top: 6 })
          .backgroundColor($r('app.color.surface_alt'))
          .borderRadius(15)
      }, (n: string) => n)
    }
    .width('100%')
  }

  // What not to prescribe. Known risk is spelled out; possible and conditional risk fold open; then what is not on
  // the lists. Colour, shape and word together, all from the dataset.
  @Builder
  avoidCard() {
    Column() {
      Row({ space: 10 }) {
        RiskShape({ risk: 'KNOWN_RISK', dim: 32 })
          .accessibilityLevel('no-hide-descendants')
        Column({ space: 1 }) {
          Text($r('app.string.dv_avoid_title'))
            .fontSize($r('app.float.font_body'))
            .fontWeight(800)
            .fontColor($r('app.color.risk_known_text'))
          Text($r('app.string.dv_avoid_sub'))
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.risk_known_subtitle'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 12 })
      .backgroundColor($r('app.color.risk_known_tint'))
      .accessibilityGroup(true)

      Column({ space: 14 }) {
        if (knownNames(this.plan).length === 0) {
          Text($r('app.string.dv_avoid_none'))
            .fontSize($r('app.float.font_small'))
            .fontColor($r('app.color.ink_2'))
            .lineHeight(20)
        }
        ForEach(this.plan.filter((g: PlanGroup) => g.avoid.some((a: AvoidDrug) => a.risk === 'KNOWN_RISK')),
          (g: PlanGroup) => {
            Column() {
              CapsLabel({ text: g.title })
              this.nameChips(g.avoid.filter((a: AvoidDrug) => a.risk === 'KNOWN_RISK')
                .map((a: AvoidDrug) => a.name))
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }, (g: PlanGroup) => g.purpose)

        if (cautionNames(this.plan).length > 0) {
          Divider().color($r('app.color.divider'))
          Column({ space: 10 }) {
            Row({ space: 8 }) {
              RiskShape({ risk: 'POSSIBLE_RISK', dim: 20 })
                .accessibilityLevel('no-hide-descendants')
              Column({ space: 1 }) {
                Text($r('app.string.dv_check_first', cautionNames(this.plan).length))
                  .fontSize($r('app.float.font_button'))
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.ink'))
                Text($r('app.string.dv_check_sub'))
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.ink_3'))
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Image($r('app.media.ic_chevron_right'))
                .width(18)
                .height(18)
                .fillColor($r('app.color.ink_4'))
                .rotate({ angle: this.showCaution ? 270 : 90 })
            }
            .width('100%')
            .constraintSize({ minHeight: $r('app.float.chip_height') })
            .accessibilityGroup(true)
            .onClick(() => {
              this.showCaution = !this.showCaution;
            })
            if (this.showCaution) {
              ForEach(this.plan.filter((g: PlanGroup) => g.avoid.some((a: AvoidDrug) => a.risk !== 'KNOWN_RISK')),
                (g: PlanGroup) => {
                  Column({ space: 6 }) {
                    CapsLabel({ text: g.title })
                    ForEach(g.avoid.filter((a: AvoidDrug) => a.risk !== 'KNOWN_RISK'), (a: AvoidDrug) => {
                      Row({ space: 8 }) {
                        Text(a.name)
                          .fontSize($r('app.float.font_small'))
                          .fontWeight(FontWeight.Medium)
                          .fontColor($r('app.color.ink'))
                          .layoutWeight(1)
                        RiskBadge({ risk: a.risk, compact: true })
                      }
                      .width('100%')
                    }, (a: AvoidDrug) => a.name)
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Start)
                }, (g: PlanGroup) => g.purpose)
            }
          }
          .width('100%')
        }

        if (this.plan.some((g: PlanGroup) => g.options.length > 0)) {
          Divider().color($r('app.color.divider'))
          Column({ space: 8 }) {
            Row({ space: 8 }) {
              RiskShape({ risk: 'NOT_LISTED', dim: 20 })
                .accessibilityLevel('no-hide-descendants')
              Text($r('app.string.dv_options'))
                .fontSize($r('app.float.font_button'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.ink'))
            }
            .accessibilityGroup(true)
            ForEach(this.plan.filter((g: PlanGroup) => g.options.length > 0), (g: PlanGroup) => {
              Text(`${g.title}: ${g.options.join(', ')}`)
                .fontSize($r('app.float.font_small'))
                .fontColor($r('app.color.ink_2'))
                .lineHeight(20)
            }, (g: PlanGroup) => g.purpose)
            Text($r('app.string.dv_options_caption'))
              .fontSize($r('app.float.font_micro'))
              .fontColor($r('app.color.ink_4'))
              .lineHeight(15)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(14)
    }
    .width('100%')
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1.5, color: $r('app.color.risk_known_border') })
    .borderRadius($r('app.float.radius_ml'))
    .clip(true)
  }

  // AI summary: labelled, visually separate, never changes anything above or below it.
  @Builder
  summaryBlock() {
    if (this.summaryState === 'OK' && this.v.summary.length > 0) {
      Column({ space: 8 }) {
        Text($r('app.string.dv_ai_label'))
          .fontFamily('monospace')
          .fontSize($r('app.float.font_micro'))
          .fontWeight(FontWeight.Bold)
          .letterSpacing(0.6)
          .fontColor($r('app.color.ink_3'))
        Text(this.v.summary)
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.ink'))
          .lineHeight(23)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .backgroundColor($r('app.color.surface_alt'))
      .borderRadius($r('app.float.radius_ml'))
      .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 12 }))
        .animation({ duration: Motion.REVEAL_MS, curve: Curve.EaseOut }))
    } else if (this.summaryState === 'LOADING') {
      Row() {
        TypingDots({ label: $r('app.string.dp_ai_loading') })
      }
      .width('100%')
      .height($r('app.float.button_height'))
      .padding({ left: 16 })
      .backgroundColor($r('app.color.surface_alt'))
      .borderRadius($r('app.float.radius_btn'))
    } else if (this.summaryState !== 'IDLE') {
      Column({ space: 6 }) {
        QuietButton({
          label: $r('app.string.dp_ai_button'),
          icon: $r('app.media.ic_wave'),
          onTap: () => {
            this.summarise();
          }
        })
        Text(this.summaryState === 'REJECTED' ? $r('app.string.dp_ai_rejected') : $r('app.string.dp_ai_failed'))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.ink_3'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  // One folded section of the full brief.
  @Builder
  depthRow(sec: BriefSection) {
    Column() {
      Row({ space: 8 }) {
        Text(sec.title)
          .fontSize($r('app.float.font_button'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .layoutWeight(1)
        Text(`${sec.lines.length}`)
          .fontSize($r('app.float.font_caption'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink_3'))
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor($r('app.color.surface_alt'))
          .borderRadius(10)
        Image($r('app.media.ic_chevron_right'))
          .width(18)
          .height(18)
          .fillColor($r('app.color.ink_4'))
          .rotate({ angle: this.open.includes(sec.title) ? 270 : 90 })
      }
      .width('100%')
      .constraintSize({ minHeight: 52 })
      .padding({ left: 16, right: 14 })
      .accessibilityGroup(true)
      .onClick(() => {
        this.toggle(sec.title);
      })
      if (this.open.includes(sec.title)) {
        Column({ space: 8 }) {
          ForEach(sec.lines, (l: string) => {
            Row({ space: 8 }) {
              Text('•').fontColor($r('app.color.ink_4'))
              Text(l)
                .fontSize($r('app.float.font_small'))
                .fontColor($r('app.color.ink_2'))
                .lineHeight(20)
                .layoutWeight(1)
            }
            .alignItems(VerticalAlign.Top)
            .width('100%')
          }, (l: string, i: number) => `${i}-${l}`)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 14 })
      }
    }
    .width('100%')
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_m'))
  }

  @Builder
  page() {
    Column() {
      this.header()
      Scroll() {
        Column({ space: 12 }) {
          this.glance()
          this.avoidCard()
          this.summaryBlock()

          CapsLabel({ text: $r('app.string.dv_depth') })
            .margin({ top: 8 })
          ForEach(this.sections.filter((s: BriefSection) => !SKIPPED_SECTIONS.includes(s.title)),
            (sec: BriefSection) => {
              this.depthRow(sec)
            }, (sec: BriefSection) => `${sec.title}-${this.open.includes(sec.title)}`)

          Row({ space: 10 }) {
            if (ShareService.available()) {
              SecondaryButton({
                label: $r('app.string.dp_copy_link'),
                onTap: () => {
                  this.share(true);
                }
              })
                .layoutWeight(1)
            }
            SecondaryButton({
              label: $r('app.string.dp_copy'),
              onTap: async () => {
                const ok: boolean = await copyText(this.text(this.v));
                toast(this.getUIContext(), ok ? $r('app.string.dp_copied') : $r('app.string.error_generic'));
              }
            })
              .layoutWeight(1)
          }
          .width('100%')
          .margin({ top: 8 })
          if (ShareService.available()) {
            Text($r('app.string.dp_share_text'))
              .fontSize($r('app.float.font_small'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.brand_text'))
              .constraintSize({ minHeight: $r('app.float.chip_height') })
              .textAlign(TextAlign.Center)
              .width('100%')
              .onClick(() => {
                shareText(this.ctx(), 'Long QT safety brief', this.text(this.v));
              })
            Text($r('app.string.dp_link_caption'))
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.ink_3'))
              .width('100%')
              .textAlign(TextAlign.Center)
          }
          Text($r('app.string.disclaimer'))
            .fontSize($r('app.float.font_micro'))
            .fontColor($r('app.color.ink_4'))
            .width('100%')
            .textAlign(TextAlign.Center)
          Text($r('app.string.dv_delete'))
            .fontSize($r('app.float.font_small'))
            .fontColor($r('app.color.ink_3'))
            .decoration({ type: TextDecorationType.Underline })
            .constraintSize({ minHeight: $r('app.float.chip_height') })
            .textAlign(TextAlign.Center)
            .width('100%')
            .onClick(() => {
              this.confirmDelete(this.v);
            })
        }
        .padding({ left: $r('app.float.space_screen'), right: $r('app.float.space_screen'), bottom: 32 })
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    NavDestination() {
      if (this.visit !== undefined && this.profile !== undefined) {
        this.page()
      } else if (this.missing) {
        Column({ space: 16 }) {
          Text($r('app.string.dv_not_found'))
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.ink_3'))
            .textAlign(TextAlign.Center)
          SecondaryButton({
            label: $r('app.string.a11y_back'),
            fill: false,
            onTap: () => {
              this.navStack.pop();
            }
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .padding(24)
      }
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg'))
    .onReady((ctx: NavDestinationContext) => {
      const p: VisitParam | undefined = ctx.pathInfo.param as VisitParam | undefined;
      if (p === undefined || p === null) {
        this.missing = true;
        return;
      }
      this.load(p.id).catch((e: Error) => {
        log.warn(`load visit: ${e.message}`);
        this.missing = true;
      });
    })
  }
}
