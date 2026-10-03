// Home tab (F-24): greeting, quick actions, heart now, my medicines at a glance, interactions, recent checks.

import { LocalStore, StoreTopic } from '../data/LocalStore';
import { Profile } from '../model/Profile';
import { Medication } from '../model/Medication';
import { ScanRecord } from '../model/ScanRecord';
import { ComboVerdict } from '../model/DrugVerdict';
import { VitalsSample } from '../model/Vitals';
import { VitalsService } from '../vitals/VitalsService';
import { medsInteractions, riskCounts, RiskCounts } from '../drugs/MedsReview';
import { CheckParam, Routes, TabIndex } from '../common/Routes';
import { dateTime } from '../common/Format';
import { NavRow, RiskBadge, SectionHeader } from '../components/Common';
import { CoachTip, tipOfTheDay } from '../coach/Coach';

@ComponentV2
export struct HomePage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Consumer('tabIndex') activeTab: number = TabIndex.HOME;
  @Local profile: Profile | undefined = undefined;
  @Local meds: Medication[] = [];
  @Local counts: RiskCounts = new RiskCounts();
  @Local interactions: ComboVerdict[] = [];
  @Local recent: ScanRecord[] = [];
  @Local hr: VitalsSample | undefined = undefined;
  private offStore: () => void = () => {
  };
  private offHr: () => void = () => {
  };

  aboutToAppear(): void {
    this.reload();
    this.offStore = LocalStore.get().onChange((t: StoreTopic) => {
      if (t === 'profile' || t === 'meds' || t === 'scans') {
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
    const recent: ScanRecord[] = (await LocalStore.get().listScans()).slice(0, 3);
    if (seq !== this.reloadSeq) {
      return;
    }
    this.profile = profile;
    this.meds = meds;
    this.counts = riskCounts(meds);
    this.interactions = medsInteractions(meds);
    this.recent = recent;
  }

  private tip(): CoachTip {
    return tipOfTheDay(this.profile?.genotype ?? 'UNKNOWN', Date.now());
  }

  private greeting(): string {
    const h: number = new Date().getHours();
    const part: string = h < 12 ? 'Good morning' : (h < 18 ? 'Good afternoon' : 'Good evening');
    const name: string = this.profile?.name ?? '';
    return name.length > 0 ? `${part}, ${name.split(' ')[0]}` : part;
  }

  @Builder
  action(icon: Resource, label: Resource, accent: boolean, onTap: () => void) {
    Column({ space: 10 }) {
      Image(icon)
        .width(26)
        .height(26)
        .fillColor(accent ? $r('app.color.on_accent') : $r('app.color.brand_accent'))
      Text(label)
        .fontSize($r('app.float.font_small'))
        .fontWeight(FontWeight.Medium)
        .fontColor(accent ? $r('app.color.on_accent') : $r('sys.color.font_primary'))
        .textAlign(TextAlign.Center)
        .maxLines(2)
    }
    .layoutWeight(1)
    .height(104)
    .justifyContent(FlexAlign.Center)
    .padding(10)
    .backgroundColor(accent ? $r('app.color.brand_accent') : $r('app.color.card_bg'))
    .borderRadius($r('app.float.radius_m'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.96 })
    .onClick(onTap)
  }

  @Builder
  countCell(n: number, label: Resource, color: Resource) {
    Column({ space: 2 }) {
      Text(`${n}`)
        .fontSize($r('app.float.font_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor(n > 0 ? color : $r('sys.color.font_tertiary'))
      Text(label)
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
    }
    .layoutWeight(1)
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Row() {
          Column({ space: 4 }) {
            Text(this.greeting())
              .fontSize($r('app.float.font_headline'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_primary'))
            Text(this.profile === undefined ? '' : `Long QT · ${this.profile.genotype === 'UNKNOWN' ? 'genotype unknown' :
              this.profile.genotype}${this.profile.hasIcd ? ' · ICD' : ''}`)
              .fontSize($r('app.float.font_small'))
              .fontColor($r('sys.color.font_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Image($r('app.media.ic_settings'))
            .width(26)
            .height(26)
            .fillColor($r('sys.color.icon_secondary'))
            .padding(4)
            .accessibilityText($r('app.string.a11y_settings'))
            .onClick(() => {
              this.navStack.pushPathByName(Routes.SETTINGS, null);
            })
        }
        .width('100%')
        .padding({ top: 12, bottom: 4 })

        Row({ space: 10 }) {
          this.action($r('app.media.ic_search'), $r('app.string.home_check'), true, () => {
            this.activeTab = TabIndex.MEDICINES;
          })
          this.action($r('app.media.ic_tab_emergency'), $r('app.string.home_card'), false, () => {
            this.activeTab = TabIndex.EMERGENCY;
          })
          this.action($r('app.media.ic_doctor'), $r('app.string.home_doctor'), false, () => {
            this.navStack.pushPathByName(Routes.DOCTOR_PREP, null);
          })
        }
        .width('100%')

        // Tip of the day for my genotype (F-39)
        if (this.profile !== undefined) {
          Row({ space: 12 }) {
            Image($r('app.media.ic_risk_conditional')).width(22).height(22).fillColor($r('app.color.brand_accent'))
            Column({ space: 4 }) {
              Text(this.tip().title)
                .fontSize($r('app.float.font_body'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary'))
              Text(this.tip().body)
                .fontSize($r('app.float.font_small'))
                .fontColor($r('sys.color.font_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .alignItems(VerticalAlign.Top)
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.brand_accent_soft'))
          .borderRadius($r('app.float.radius_m'))
        }

        // Heart now
        Row({ space: 12 }) {
          Image($r('app.media.ic_tab_heart')).width(28).height(28).fillColor($r('app.color.brand_accent'))
          Column({ space: 2 }) {
            Text(this.hr === undefined ? '-- bpm' : `${this.hr.hr} bpm`)
              .fontSize($r('app.float.font_title'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_primary'))
            Text($r('app.string.home_heart_sim'))
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.sim_badge'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Image($r('app.media.ic_chevron_right')).width(18).height(18).fillColor($r('sys.color.icon_secondary'))
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius($r('app.float.radius_m'))
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
        .onClick(() => {
          this.activeTab = TabIndex.HEART;
        })

        // My medicines at a glance
        SectionHeader({
          title: $r('app.string.home_meds'),
          action: $r('app.string.home_manage'),
          onAction: () => {
            this.activeTab = TabIndex.MEDICINES;
          }
        })
        Column({ space: 12 }) {
          if (this.meds.length === 0) {
            Text($r('app.string.home_no_meds'))
              .fontSize($r('app.float.font_small'))
              .fontColor($r('sys.color.font_secondary'))
          } else {
            Row() {
              this.countCell(this.counts.known, $r('app.string.home_c_known'), $r('app.color.risk_known'))
              this.countCell(this.counts.possible + this.counts.conditional, $r('app.string.home_c_other'),
                $r('app.color.risk_possible'))
              this.countCell(this.counts.notListed, $r('app.string.home_c_ok'), $r('app.color.risk_not_listed'))
              this.countCell(this.counts.unknown, $r('app.string.home_c_unknown'), $r('app.color.risk_unknown'))
            }
            .width('100%')
          }
          ForEach(this.interactions, (c: ComboVerdict) => {
            Row({ space: 10 }) {
              Image($r('app.media.ic_risk_possible')).width(18).height(18).fillColor($r('app.color.risk_known'))
              Text(`${c.drugs.join(' + ')}: ${c.kind === 'CYP_INTERACTION' ? `interaction (${c.enzyme})` :
                'both affect QT'}`)
                .fontSize($r('app.float.font_small'))
                .fontColor($r('sys.color.font_primary'))
                .layoutWeight(1)
            }
            .width('100%')
            .padding(10)
            .backgroundColor($r('app.color.risk_known_soft'))
            .borderRadius($r('app.float.radius_s'))
          }, (c: ComboVerdict) => c.drugs.join('+'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius($r('app.float.radius_m'))

        // Recent checks
        SectionHeader({
          title: $r('app.string.home_recent'),
          action: this.recent.length > 0 ? $r('app.string.home_all') : '',
          onAction: () => {
            this.navStack.pushPathByName(Routes.HISTORY, null);
          }
        })
        if (this.recent.length === 0) {
          Text($r('app.string.home_no_checks'))
            .fontSize($r('app.float.font_small'))
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius($r('app.float.radius_m'))
        } else {
          ForEach(this.recent, (s: ScanRecord) => {
            Row({ space: 12 }) {
              Column({ space: 2 }) {
                Text(s.ingredient === '' ? s.query : s.ingredient)
                  .fontSize($r('app.float.font_body'))
                  .fontColor($r('sys.color.font_primary'))
                Text(dateTime(s.ts, Date.now()))
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('sys.color.font_secondary'))
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              RiskBadge({ risk: s.risk, compact: true })
            }
            .width('100%')
            .padding(14)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius($r('app.float.radius_m'))
            .onClick(() => {
              this.navStack.pushPathByName(Routes.CHECK_RESULT, new CheckParam(s.query, false));
            })
          }, (s: ScanRecord) => `${s.id}`)
        }

        SectionHeader({ title: $r('app.string.home_more') })
        NavRow({
          icon: $r('app.media.ic_bell'),
          title: $r('app.string.rem_title'),
          subtitle: $r('app.string.rem_subtitle'),
          onTap: () => {
            this.navStack.pushPathByName(Routes.REMINDERS, null);
          }
        })
        NavRow({
          icon: $r('app.media.ic_tab_heart'),
          title: $r('app.string.sym_title'),
          subtitle: $r('app.string.sym_subtitle'),
          onTap: () => {
            this.navStack.pushPathByName(Routes.SYMPTOM_LOG, null);
          }
        })
        NavRow({
          icon: $r('app.media.ic_pill'),
          title: $r('app.string.ph_title'),
          subtitle: $r('app.string.ph_subtitle'),
          onTap: () => {
            this.navStack.pushPathByName(Routes.PHARMACY_CARD, null);
          }
        })

        Text($r('app.string.disclaimer'))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('sys.color.font_tertiary'))
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ top: 8 })
      }
      .padding({ left: 16, right: 16, bottom: 24 })
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .backgroundColor($r('app.color.page_bg'))
  }
}
