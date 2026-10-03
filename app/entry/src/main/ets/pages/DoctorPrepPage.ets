// Doctor visit prep (F-31): pick the specialist → safety brief from my own data → send as an encrypted link that
// opens on any device (site/report, 48 h), or share/copy as text. Opened on a saved visit (B6, DoctorPrepParam
// visitId) the brief adds the visit's reason and worries, the specialty is fixed, and a checked AI summary is kept
// with the visit.

import { common } from '@kit.AbilityKit';
import { LocalStore } from '../data/LocalStore';
import { Profile } from '../model/Profile';
import {
  BriefSection, briefText, buildBrief, Specialty, SPECIALTIES, specialtyName, visitDay
} from '../doctor/DoctorPrep';
import { copyText } from '../common/Clipboard';
import { DoctorPrepParam, Routes } from '../common/Routes';
import { shareText } from '../common/Share';
import { toast } from '../common/Toast';
import { NavRow, PrimaryButton, QuietButton, SecondaryButton, SourceBadge, TypingDots } from '../components/Common';
import { DoctorSummary, parseSummary, SummaryOutcome, SummaryResult } from '../doctor/DoctorSummary';
import { DoctorVisit } from '../doctor/Visit';
import { VisitStore } from '../doctor/VisitStore';
import { personalTerms } from '../doctor/Redact';
import { Motion } from '../common/Motion';
import { buildReport, ReportPayload } from '../doctor/ReportPayload';
import { contentHash, ShareRecord, ShareService } from '../share/ShareService';
import { loadRestingHistory, demoHistory } from '../vitals/RestingHistory';
import { DailyResting } from '../vitals/RestingTrend';
import { ReminderService } from '../reminders/ReminderService';

type SummaryState = 'IDLE' | 'LOADING' | SummaryResult;

interface SavedSummary {
  summary: string;
}

const REPORT_BRIEF_KEY: string = 'share.report.brief';   // hash of the brief behind the live report link

@ComponentV2
export struct DoctorPrepPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local specialty: Specialty = 'GP';
  @Local visit: DoctorVisit | undefined = undefined;
  @Local sections: BriefSection[] = [];
  @Local profile: Profile | undefined = undefined;
  @Local sending: boolean = false;
  @Local summary: string = '';
  @Local summaryState: SummaryState = 'IDLE';
  private generation: number = 0;   // a newer build_ wins when two overlap (aboutToAppear, then onReady)

  aboutToAppear(): void {
    this.build_();
  }

  private async build_(): Promise<void> {
    const gen: number = ++this.generation;
    const profile: Profile | undefined = await LocalStore.get().getProfile();
    const sections: BriefSection[] = profile === undefined ? [] : buildBrief(profile,
      await LocalStore.get().listMeds(), await LocalStore.get().listScans(), await LocalStore.get().listEvents(),
      this.specialty, Date.now(), this.visit);
    if (gen !== this.generation) {
      return;
    }
    this.profile = profile;
    this.sections = sections;
    // A summary saved with the visit passed the checks when it arrived; check it again before showing it.
    const stored: SavedSummary = { summary: this.visit === undefined ? '' : this.visit.summary };
    const saved: SummaryOutcome = stored.summary === '' ? new SummaryOutcome('REJECTED', '') :
      parseSummary(JSON.stringify(stored));
    this.summary = saved.text;
    this.summaryState = saved.result === 'OK' ? 'OK' : 'IDLE';
  }

  private async openVisit(id: number): Promise<void> {
    const v: DoctorVisit | undefined = await VisitStore.get(id);
    if (v === undefined) {
      return;
    }
    this.visit = v;
    this.specialty = v.specialty;
    await this.build_();
  }

  private async summarise(): Promise<void> {
    if (this.profile === undefined || this.summaryState === 'LOADING') {
      return;
    }
    const forSpecialty: Specialty = this.specialty;
    const visit: DoctorVisit | undefined = this.visit;
    this.summaryState = 'LOADING';
    let out: SummaryOutcome;
    try {
      out = await DoctorSummary.fetch(this.sections, forSpecialty, this.profile.genotype, visit,
        personalTerms(this.profile));
    } catch (e) {
      out = new SummaryOutcome('FAILED', '');
    }
    if (forSpecialty !== this.specialty || visit !== this.visit) {
      return;   // the brief changed while waiting
    }
    this.summary = out.text;
    this.summaryState = out.result;
    if (out.result === 'OK' && visit !== undefined) {
      visit.summary = out.text;
      visit.summaryAt = Date.now();
      await VisitStore.save(visit);
    }
  }

  // AI summary (DESIGN.md §6.9 AI block pattern): optional, labelled, never changes the brief below.
  @Builder
  summaryBlock() {
    if (this.summaryState === 'OK') {
      Column({ space: 8 }) {
        SourceBadge({ label: $r('app.string.med_ai_badge'), solid: true })
        Text(this.summary)
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.ink'))
          .lineHeight(22)
        Text(this.visit === undefined ? $r('app.string.dp_ai_caption') : $r('app.string.doc_summary_saved'))
          .fontSize($r('app.float.font_micro'))
          .fontColor($r('app.color.ink_4'))
          .lineHeight(15)
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
    } else {
      Column({ space: 8 }) {
        QuietButton({
          label: $r('app.string.dp_ai_button'),
          icon: $r('app.media.ic_wave'),
          onTap: () => {
            this.summarise();
          }
        })
        if (this.summaryState !== 'IDLE') {
          Text(this.summaryState === 'REJECTED' ? $r('app.string.dp_ai_rejected') : $r('app.string.dp_ai_failed'))
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.ink_3'))
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  private text(): string {
    return briefText(this.sections, this.specialty, Date.now());
  }

  private ctx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private str(r: Resource): string {
    try {
      return this.ctx().resourceManager.getStringSync(r.id);
    } catch (e) {
      return '';
    }
  }

  // Full structured report → encrypted share (the server deletes it after 48 hours). One report link is live at a
  // time, so while the brief is unchanged Send and Copy reuse the link already made — a second tap must not revoke
  // the link a doctor just received. A changed brief (new specialty, medicine, event) makes a new link.
  private async reportLink(): Promise<string | undefined> {
    if (this.profile === undefined) {
      return undefined;
    }
    const briefKey: string = contentHash(`${this.specialty}\n${JSON.stringify(this.sections)}`);
    const current: ShareRecord | undefined = await ShareService.current('report');
    if (current !== undefined && (await LocalStore.get().getSetting(REPORT_BRIEF_KEY, '')) === briefKey) {
      return ShareService.url(current);
    }
    const now: number = Date.now();
    let resting: DailyResting[] = await loadRestingHistory(now);
    if (resting.length === 0) {
      resting = demoHistory(now);   // labelled SIMULATED in the report
    }
    const payload: ReportPayload = buildReport(this.profile, await LocalStore.get().listMeds(),
      await LocalStore.get().listScans(), await LocalStore.get().listEvents(), this.specialty, resting,
      await ReminderService.list(), await ReminderService.doseLog(), now);
    const r: ShareRecord | undefined = await ShareService.share('report', JSON.stringify(payload));
    if (r === undefined) {
      return undefined;
    }
    await LocalStore.get().setSetting(REPORT_BRIEF_KEY, briefKey);
    return ShareService.url(r);
  }

  private async sendLink(copyOnly: boolean): Promise<void> {
    if (this.sending) {
      return;
    }
    this.sending = true;
    try {
      const url: string | undefined = await this.reportLink();
      if (url === undefined) {
        toast(this.getUIContext(), $r('app.string.dp_link_failed'));
        return;
      }
      if (copyOnly) {
        const ok: boolean = await copyText(url);
        toast(this.getUIContext(), ok ? $r('app.string.dp_link_copied') : $r('app.string.error_generic'));
      } else {
        shareText(this.ctx(), 'Long QT safety report', `${this.str($r('app.string.dp_link_message'))}\n${url}`);
      }
    } finally {
      this.sending = false;
    }
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          Text(this.visit === undefined ? $r('app.string.dp_intro') : $r('app.string.doc_visits_intro'))
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.ink_3'))
            .width('100%')
          if (this.visit === undefined) {
            NavRow({
              icon: $r('app.media.ic_doctor'),
              title: $r('app.string.doc_my_visits'),
              subtitle: $r('app.string.doc_my_visits_sub'),
              onTap: () => {
                this.navStack.pushPathByName(Routes.VISITS, null);
              }
            })
          }
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.visit === undefined ? SPECIALTIES : [], (s: Specialty) => {
              Text(specialtyName(s))
                .fontSize($r('app.float.font_small'))
                .fontColor(this.specialty === s ? $r('app.color.chat_user_text') : $r('app.color.ink'))
                .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                .margin({ right: 8, bottom: 8 })
                .backgroundColor(this.specialty === s ? $r('app.color.chat_user_bg') : $r('app.color.surface'))
                .border({ width: this.specialty === s ? 0 : 1.5, color: $r('app.color.border_strong') })
                .borderRadius(100)
                .onClick(() => {
                  this.specialty = s;
                  this.build_();
                })
            }, (s: Specialty) => s)
          }
          .width('100%')

          if (this.profile === undefined) {
            Text($r('app.string.emergency_no_profile'))
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.ink_3'))
          } else {
            if (DoctorSummary.available()) {
              this.summaryBlock()
            }
            ForEach(this.sections, (sec: BriefSection) => {
              Column({ space: 6 }) {
                Text(sec.title)
                  .fontSize($r('app.float.font_small'))
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.brand_text'))
                ForEach(sec.lines, (l: string) => {
                  Row({ space: 8 }) {
                    Text('•').fontColor($r('app.color.ink_3'))
                    Text(l)
                      .fontSize($r('app.float.font_body'))
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                  }
                  .alignItems(VerticalAlign.Top)
                  .width('100%')
                }, (l: string, i: number) => `${i}-${l}`)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(16)
              .backgroundColor($r('app.color.surface'))
              .border({ width: 1, color: $r('app.color.border') })
              .borderRadius($r('app.float.radius_m'))
            }, (sec: BriefSection) => `${this.specialty}-${sec.title}`)

            if (ShareService.available()) {
              PrimaryButton({
                label: this.sending ? $r('app.string.share_preparing') : $r('app.string.dp_send_link'),
                icon: $r('app.media.ic_share'),
                active: !this.sending,
                onTap: () => {
                  this.sendLink(false);
                }
              })
              SecondaryButton({
                label: $r('app.string.dp_copy_link'),
                onTap: () => {
                  this.sendLink(true);
                }
              })
              Text($r('app.string.dp_link_caption'))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.ink_3'))
                .width('100%')
                .textAlign(TextAlign.Center)
            }
            QuietButton({
              label: $r('app.string.dp_share_text'),
              onTap: () => {
                shareText(this.ctx(), 'Long QT safety brief', this.text());
              }
            })
            QuietButton({
              label: $r('app.string.dp_copy'),
              onTap: async () => {
                const ok: boolean = await copyText(this.text());
                toast(this.getUIContext(), ok ? $r('app.string.dp_copied') : $r('app.string.error_generic'));
              }
            })
            Text($r('app.string.disclaimer'))
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.ink_4'))
              .width('100%')
              .textAlign(TextAlign.Center)
          }
        }
        .padding({ left: 16, right: 16, bottom: 32 })
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .title(this.visit === undefined ? $r('app.string.home_doctor') :
      `${specialtyName(this.visit.specialty)} · ${visitDay(this.visit.date)}`)
    .backgroundColor($r('app.color.bg'))
    .onReady((ctx: NavDestinationContext) => {
      const p: DoctorPrepParam | undefined = ctx.pathInfo.param as DoctorPrepParam | undefined;
      if (p !== undefined && p !== null && typeof p.visitId === 'number' && p.visitId >= 0) {
        this.openVisit(p.visitId);
        return;
      }
      const s: Specialty | undefined = SPECIALTIES.find((x: Specialty) => x === p?.specialty);
      if (s !== undefined && s !== this.specialty) {
        this.specialty = s;
        this.build_();
      }
    })
  }
}
