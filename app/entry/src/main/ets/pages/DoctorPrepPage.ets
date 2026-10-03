// Doctor visit (F-31; DESIGN.md §10.1a, screen 07): pick the specialist → safety brief from my own data → send as an
// encrypted link that opens on any device (site/report, 48 h), or share/copy as text. The one primary action stays
// pinned at the bottom; the AI summary is labelled and visually separate.

import { common } from '@kit.AbilityKit';
import { LocalStore } from '../data/LocalStore';
import { Profile } from '../model/Profile';
import { BriefSection, briefText, buildBrief, Specialty, SPECIALTIES, specialtyName } from '../doctor/DoctorPrep';
import { copyText } from '../common/Clipboard';
import { DoctorPrepParam } from '../common/Routes';
import { shareText } from '../common/Share';
import { toast } from '../common/Toast';
import {
  CapsLabel, PrimaryButton, QuietButton, ScreenHeader, SecondaryButton, TypingDots
} from '../components/Common';
import { DoctorSummary, SummaryOutcome, SummaryResult } from '../doctor/DoctorSummary';
import { Motion } from '../common/Motion';
import { buildReport, ReportPayload } from '../doctor/ReportPayload';
import { contentHash, ShareRecord, ShareService } from '../share/ShareService';
import { loadRestingHistory, demoHistory } from '../vitals/RestingHistory';
import { DailyResting } from '../vitals/RestingTrend';
import { ReminderService } from '../reminders/ReminderService';

type SummaryState = 'IDLE' | 'LOADING' | SummaryResult;

const REPORT_BRIEF_KEY: string = 'share.report.brief';   // hash of the brief behind the live report link

@ComponentV2
export struct DoctorPrepPage {
  @Local specialty: Specialty = 'GP';
  @Local sections: BriefSection[] = [];
  @Local profile: Profile | undefined = undefined;
  @Local sending: boolean = false;
  @Local summary: string = '';
  @Local summaryState: SummaryState = 'IDLE';

  aboutToAppear(): void {
    this.build_();
  }

  private async build_(): Promise<void> {
    this.profile = await LocalStore.get().getProfile();
    if (this.profile === undefined) {
      this.sections = [];
      return;
    }
    this.sections = buildBrief(this.profile, await LocalStore.get().listMeds(), await LocalStore.get().listScans(),
      await LocalStore.get().listEvents(), this.specialty, Date.now());
    this.summary = '';
    this.summaryState = 'IDLE';
  }

  private async summarise(): Promise<void> {
    if (this.profile === undefined || this.summaryState === 'LOADING') {
      return;
    }
    const forSpecialty: Specialty = this.specialty;
    this.summaryState = 'LOADING';
    let out: SummaryOutcome;
    try {
      out = await DoctorSummary.fetch(this.sections, forSpecialty, this.profile.genotype);
    } catch (e) {
      out = new SummaryOutcome('FAILED', '');
    }
    if (forSpecialty !== this.specialty) {
      return;   // the brief changed while waiting
    }
    this.summary = out.text;
    this.summaryState = out.result;
  }

  // AI summary (DESIGN.md §6.9 AI block pattern): optional, labelled, never changes the brief below.
  @Builder
  summaryBlock() {
    if (this.summaryState === 'OK') {
      Column({ space: 8 }) {
        Text($r('app.string.dp_ai_label'))
          .fontFamily('monospace')
          .fontSize($r('app.float.font_micro'))
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1)
          .fontColor($r('app.color.ink_3'))
        Text(this.summary)
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.ink'))
          .lineHeight(22)
        Text($r('app.string.dp_ai_caption'))
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

  private async copyBrief(): Promise<void> {
    const ok: boolean = await copyText(this.text());
    toast(this.getUIContext(), ok ? $r('app.string.dp_copied') : $r('app.string.error_generic'));
  }

  @Builder
  chips() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(SPECIALTIES, (s: Specialty) => {
          Text(specialtyName(s))
            .fontSize($r('app.float.font_button'))
            .fontWeight(FontWeight.Bold)
            .fontColor(this.specialty === s ? $r('app.color.chat_user_text') : $r('app.color.ink'))
            .height($r('app.float.chip_height'))
            .padding({ left: 16, right: 16 })
            .backgroundColor(this.specialty === s ? $r('app.color.chat_user_bg') : $r('app.color.surface'))
            .border({ width: this.specialty === s ? 0 : 1, color: $r('app.color.border') })
            .borderRadius(22)
            .accessibilitySelected(this.specialty === s)
            .onClick(() => {
              this.specialty = s;
              this.build_();
            })
        }, (s: Specialty) => s)
      }
      .padding({ left: 16, right: 16 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .align(Alignment.Start)
  }

  @Builder
  section(sec: BriefSection) {
    Column({ space: 6 }) {
      CapsLabel({ text: sec.title })
      ForEach(sec.lines, (l: string) => {
        Text(l)
          .fontSize($r('app.float.font_body'))
          .fontWeight(600)
          .lineHeight(23)
          .fontColor($r('app.color.ink'))
          .width('100%')
      }, (l: string, i: number) => `${i}-${l}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_ml'))
    .accessibilityGroup(true)
  }

  // One primary action, pinned. With the share service: the encrypted report link. Without it: the brief as text.
  @Builder
  pinned() {
    Row({ space: 10 }) {
      if (ShareService.available()) {
        PrimaryButton({
          label: this.sending ? $r('app.string.share_preparing') : $r('app.string.dp_share_doctor'),
          active: !this.sending,
          large: true,
          onTap: () => {
            this.sendLink(false);
          }
        })
          .layoutWeight(1)
        SecondaryButton({
          label: $r('app.string.dp_copy_short'),
          large: true,
          fill: false,
          onTap: () => {
            this.sendLink(true);
          }
        })
      } else {
        PrimaryButton({
          label: $r('app.string.dp_share_doctor'),
          large: true,
          onTap: () => {
            shareText(this.ctx(), 'Long QT safety brief', this.text());
          }
        })
          .layoutWeight(1)
        SecondaryButton({
          label: $r('app.string.dp_copy_short'),
          large: true,
          fill: false,
          onTap: () => {
            this.copyBrief();
          }
        })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 16 })
    .backgroundColor($r('app.color.bg'))
    .border({ width: { top: 1 }, color: $r('app.color.border') })
  }

  build() {
    NavDestination() {
      Column() {
        ScreenHeader({ title: $r('app.string.doctor_visit'), settings: false })
        this.chips()
        Scroll() {
          Column({ space: 12 }) {
            if (this.profile === undefined) {
              Text($r('app.string.emergency_no_profile'))
                .fontSize($r('app.float.font_body'))
                .fontColor($r('app.color.ink_3'))
            } else {
              ForEach(this.sections, (sec: BriefSection) => {
                this.section(sec)
              }, (sec: BriefSection) => `${this.specialty}-${sec.title}`)
              if (DoctorSummary.available()) {
                this.summaryBlock()
              }
              if (ShareService.available()) {
                Text($r('app.string.dp_link_caption'))
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.ink_3'))
                  .width('100%')
                Row({ space: 8 }) {
                  QuietButton({
                    label: $r('app.string.dp_share_text'),
                    onTap: () => {
                      shareText(this.ctx(), 'Long QT safety brief', this.text());
                    }
                  })
                    .layoutWeight(1)
                  QuietButton({
                    label: $r('app.string.dp_copy'),
                    onTap: () => {
                      this.copyBrief();
                    }
                  })
                    .layoutWeight(1)
                }
                .width('100%')
              }
              Text($r('app.string.disclaimer'))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.ink_4'))
                .width('100%')
            }
          }
          .padding({ left: 16, right: 16, top: 12, bottom: 24 })
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
        if (this.profile !== undefined) {
          this.pinned()
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg'))
    .onReady((ctx: NavDestinationContext) => {
      const p: DoctorPrepParam | undefined = ctx.pathInfo.param as DoctorPrepParam | undefined;
      const s: Specialty | undefined = SPECIALTIES.find((x: Specialty) => x === p?.specialty);
      if (s !== undefined && s !== this.specialty) {
        this.specialty = s;
        this.build_();
      }
    })
  }
}
