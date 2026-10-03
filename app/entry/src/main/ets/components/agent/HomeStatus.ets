// Status strip of the agent home (DESIGN.md §10.1a, item 1): heart-rate chip with its source badge, medicines chip,
// then the chats and settings buttons. The chips scroll sideways when they do not fit; the buttons never move.

import { RiskLevel } from '../../model/DrugVerdict';
import { SourceBadge, StatusChip } from '../Common';

@ComponentV2
export struct HomeStatus {
  @Param bpm: number = 0;                  // 0 = no reading yet
  @Param simulated: boolean = true;
  @Param medsLabel: ResourceStr = '';
  @Param medsRisk: RiskLevel | undefined = undefined;
  @Event onHeart: () => void = () => {
  };
  @Event onMeds: () => void = () => {
  };
  @Event onChats: () => void = () => {
  };
  @Event onSettings: () => void = () => {
  };

  @Builder
  iconButton(icon: Resource, a11y: Resource, onTap: () => void) {
    Row() {
      Image(icon).width(22).height(22).fillColor($r('app.color.ink_2'))
    }
    .width($r('app.float.touch_min'))
    .height($r('app.float.touch_min'))
    .justifyContent(FlexAlign.Center)
    .borderRadius(22)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.92 })
    .accessibilityText(a11y)
    .onClick(() => onTap())
  }

  build() {
    Row() {
      Scroll() {
        Row({ space: 8 }) {
          Row({ space: 6 }) {
            StatusChip({
              label: this.bpm > 0 ? $r('app.string.home_bpm_chip', Math.round(this.bpm)) :
                $r('app.string.home_bpm_waiting'),
              onTap: () => {
                this.onHeart();
              }
            })
            SourceBadge({
              label: this.simulated ? $r('app.string.badge_simulated') : $r('app.string.badge_watch'),
              solid: !this.simulated
            })
          }
          .accessibilityGroup(true)
          .accessibilityText($r('app.string.a11y_home_hr'))
          .onClick(() => {
            this.onHeart();
          })

          StatusChip({
            label: this.medsLabel,
            risk: this.medsRisk,
            onTap: () => {
              this.onMeds();
            }
          })
            .accessibilityText($r('app.string.a11y_home_meds'))
        }
        .padding({ left: 16, right: 8 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .align(Alignment.Start)

      this.iconButton($r('app.media.ic_history'), $r('app.string.a11y_chats'), () => {
        this.onChats();
      })
      this.iconButton($r('app.media.ic_settings'), $r('app.string.a11y_settings'), () => {
        this.onSettings();
      })
    }
    .width('100%')
    .height($r('app.float.touch_min'))
    .padding({ right: 8 })
    .margin({ top: 8 })
  }
}
