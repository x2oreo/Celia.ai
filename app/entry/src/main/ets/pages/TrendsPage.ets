// Trends: resting heart rate, doses and symptoms per day over 14 or 30 days, plus the fixed-rule findings from the
// watch data. Heart rate only — never QT, never a diagnosis.

import { Card, EmptyCard, SectionHeader, SourceBadge } from '../components/Common';
import { TrendChart } from '../components/TrendChart';
import { WatchInsight } from '../model/WatchData';
import { loadTrends, TrendData, TrendStats, trendStats } from '../vitals/Trends';

const SPANS: number[] = [14, 30];

@ComponentV2
export struct TrendsPage {
  @Local span: number = 14;
  @Local data: TrendData | undefined = undefined;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    const forSpan: number = this.span;
    const d: TrendData = await loadTrends(Date.now(), forSpan);
    if (forSpan === this.span) {
      this.data = d;
    }
  }

  private stats(): TrendStats {
    return trendStats(this.data !== undefined ? this.data.days : []);
  }

  private changeText(): ResourceStr {
    const s: TrendStats = this.stats();
    if (!s.hasChange) {
      return '–';
    }
    return s.change > 0 ? `+${s.change}` : `${s.change}`;
  }

  @Builder
  tile(value: ResourceStr, unit: ResourceStr, label: ResourceStr) {
    Column({ space: 2 }) {
      Row({ space: 4 }) {
        Text(value)
          .fontSize($r('app.float.font_title'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Text(unit)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.ink_3'))
      }
      .alignItems(VerticalAlign.Bottom)
      Text(label)
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.ink_3'))
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_m'))
    .accessibilityGroup(true)
  }

  @Builder
  spanChips() {
    Row({ space: 8 }) {
      ForEach(SPANS, (n: number) => {
        Text($r('app.string.trends_days', n))
          .fontSize($r('app.float.font_small'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.span === n ? $r('app.color.chat_user_text') : $r('app.color.ink'))
          .backgroundColor(this.span === n ? $r('app.color.chat_user_bg') : $r('app.color.surface'))
          .border({ width: this.span === n ? 0 : 1.5, color: $r('app.color.border_strong') })
          .borderRadius($r('app.float.radius_btn'))
          .height($r('app.float.touch_min'))
          .padding({ left: 16, right: 16 })
          .accessibilityText($r('app.string.trends_days_a11y', n))
          .onClick(() => {
            if (this.span !== n) {
              this.span = n;
              this.load();
            }
          })
      }, (n: number) => `${n}`)
      Blank()
      if (this.data !== undefined && this.data.simulated) {
        SourceBadge({ label: $r('app.string.badge_simulated') })
      }
    }
    .width('100%')
  }

  @Builder
  insightRow(i: WatchInsight) {
    Column({ space: 4 }) {
      Text(i.severity === 'INFO' ? $r('app.string.trends_note') : $r('app.string.trends_important'))
        .fontSize($r('app.float.font_badge'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink_3'))
        .letterSpacing(0.6)
      Text(i.message)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.ink'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_m'))
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          this.spanChips()

          if (this.data === undefined) {
            LoadingProgress().width(32).height(32).color($r('app.color.ink_3')).margin({ top: 48 })
          } else if (this.data.source === 'OFFLINE') {
            EmptyCard({ message: $r('app.string.trends_offline') })
          } else {
            Card() {
              Column({ space: 8 }) {
                Text($r('app.string.trends_chart_title'))
                  .fontSize($r('app.float.font_headline'))
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.ink'))
                TrendChart({
                  days: this.data.days,
                  doseLabel: $r('app.string.trends_row_dose'),
                  symptomLabel: $r('app.string.trends_row_symptom')
                })
                Text($r('app.string.trends_not_ecg'))
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.ink_3'))
              }
              .alignItems(HorizontalAlign.Start)
            }

            Row({ space: 8 }) {
              this.tile(this.stats().avgResting > 0 ? `${this.stats().avgResting}` : '–', $r('app.string.trends_bpm'),
                $r('app.string.trends_avg'))
              this.tile(this.changeText(), $r('app.string.trends_bpm'), $r('app.string.trends_change'))
            }
            .width('100%')
            Row({ space: 8 }) {
              this.tile(`${this.stats().doseDays}`, $r('app.string.trends_of_days', this.span),
                $r('app.string.trends_dose_days'))
              this.tile(`${this.stats().symptomDays}`, $r('app.string.trends_of_days', this.span),
                $r('app.string.trends_symptom_days'))
            }
            .width('100%')

            if (this.data.insights.length > 0) {
              SectionHeader({ title: $r('app.string.trends_findings') })
              ForEach(this.data.insights, (i: WatchInsight) => {
                this.insightRow(i)
              }, (i: WatchInsight) => `${i.kind}-${i.ts}`)
            }

            Text($r('app.string.trends_disclaimer'))
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.ink_3'))
              .margin({ top: 4 })
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
    .title($r('app.string.trends_title'))
    .backgroundColor($r('app.color.bg'))
  }
}
