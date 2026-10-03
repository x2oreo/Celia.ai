// Notes strip of the agent home (DESIGN.md §10.1a, item 2): what the old Home dashboard said, in one collapsible
// strip. Closed: the agent's greeting sentence on one line. Open: the sentence, interactions between the user's
// medicines, the alarm chip, the tip of the day and the travel banner. All of it is deterministic, none of it AI.

import { ComboVerdict } from '../../model/DrugVerdict';
import { RiskShape, StatusChip } from '../Common';

const NOTES_MAX: number = 300;   // the open strip scrolls inside this height so the dock stays on screen

@ComponentV2
export struct HomeNotes {
  @Param line: string = '';                    // the agent's greeting sentence
  @Param interactions: ComboVerdict[] = [];
  @Param tipLabel: string = '';
  @Param tipTitle: string = '';
  @Param tipBody: string = '';
  @Param travelTitle: string = '';             // '' when the phone is at home
  @Param travelDetail: string = '';
  @Event onAlarm: () => void = () => {
  };
  @Event onTravel: () => void = () => {
  };
  @Local open: boolean = false;

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
  }

  // Tip of the day (F-39): static, sourced genotype tips — never AI, never a risk colour.
  @Builder
  tip() {
    Column({ space: 6 }) {
      Text(this.tipLabel)
        .fontSize($r('app.float.font_micro'))
        .fontWeight(FontWeight.Bold)
        .letterSpacing(0.8)
        .fontColor($r('app.color.ink_3'))
      Text(this.tipTitle)
        .fontSize($r('app.float.font_headline'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
      Text(this.tipBody)
        .fontSize($r('app.float.font_small'))
        .fontColor($r('app.color.ink_2'))
        .lineHeight(20)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_l'))
    .accessibilityGroup(true)
  }

  // Travel banner (T23): where the phone is, the local emergency number, pharmacy card language.
  @Builder
  travel() {
    Row({ space: 12 }) {
      Image($r('app.media.ic_location')).width(18).height(18).fillColor($r('app.color.ink_2'))
      Column({ space: 2 }) {
        Text(this.travelTitle)
          .fontSize($r('app.float.font_headline'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Text(this.travelDetail)
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink_2'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Image($r('app.media.ic_chevron_right')).width(16).height(16).fillColor($r('app.color.ink_4'))
    }
    .width('100%')
    .constraintSize({ minHeight: $r('app.float.chip_height') })
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_m'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
    .accessibilityGroup(true)
    .onClick(() => {
      this.onTravel();
    })
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Text(this.line)
          .fontSize($r('app.float.font_small'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ink_2'))
          .maxLines(this.open ? 4 : 1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Image($r('app.media.ic_chevron_right'))
          .width(16)
          .height(16)
          .fillColor($r('app.color.ink_3'))
          .rotate({ angle: this.open ? -90 : 90 })
      }
      .width('100%')
      .constraintSize({ minHeight: $r('app.float.chip_height') })
      .padding({ left: 20, right: 20 })
      .accessibilityGroup(true)
      .accessibilityText(this.open ? $r('app.string.a11y_notes_close') : $r('app.string.a11y_notes_open'))
      .onClick(() => {
        this.open = !this.open;
      })

      if (this.open) {
        Scroll() {
          Column({ space: 12 }) {
            ForEach(this.interactions, (c: ComboVerdict) => {
              this.interaction(c)
            }, (c: ComboVerdict) => c.drugs.join('+'))
            Row() {
              StatusChip({
                label: $r('app.string.home_alarm_on'),
                onTap: () => {
                  this.onAlarm();
                }
              })
            }
            .width('100%')
            if (this.travelTitle !== '') {
              this.travel()
            }
            this.tip()
          }
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 12 })
        }
        .scrollBar(BarState.Off)
        .constraintSize({ maxHeight: NOTES_MAX })
      }
    }
    .width('100%')
  }
}
