// OWNER: Georgi — tab body. Live HR, source badge, alert list, demo scenario panel (VitalsService).

import { PlaceholderView } from '../components/PlaceholderView';

@ComponentV2
export struct HeartPage {
  build() {
    PlaceholderView({
      icon: $r('app.media.ic_tab_heart'),
      title: $r('app.string.heart_title'),
      subtitle: $r('app.string.heart_placeholder')
    })
  }
}
