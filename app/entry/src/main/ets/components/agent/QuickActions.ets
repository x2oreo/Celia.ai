// Quick-action row of the agent home (DESIGN.md §10.1a, item 5): the features that used to sit at the bottom of
// other tabs, one tap away. Add an action here as one more chip.

import { Routes } from '../../common/Routes';
import { QuickReplyChip } from '../Common';

@ComponentV2
export struct QuickActions {
  @Event onOpen: (route: string) => void = (route: string) => {
  };

  @Builder
  action(label: Resource, icon: Resource, route: string) {
    QuickReplyChip({
      label: label,
      icon: icon,
      onTap: () => {
        this.onOpen(route);
      }
    })
      .accessibilityText(label)
  }

  build() {
    Scroll() {
      Row({ space: 8 }) {
        this.action($r('app.string.home_scan_box'), $r('app.media.ic_box'), Routes.SCAN)
        this.action($r('app.string.home_log_feel'), $r('app.media.ic_heart_fill'), Routes.SYMPTOM_LOG)
        this.action($r('app.string.home_doctor_prep'), $r('app.media.ic_doctor'), Routes.DOCTOR_PREP)
        this.action($r('app.string.trends_title'), $r('app.media.ic_wave'), Routes.TRENDS)
      }
      .padding({ left: 20, right: 20 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .align(Alignment.Start)
    .padding({ top: 4, bottom: 4 })
  }
}
