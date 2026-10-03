// OWNER: Georgi — tab body. Emergency card (readable by a stranger) + Call 112 / ICE contacts.

import { PlaceholderView } from '../components/PlaceholderView';

@ComponentV2
export struct EmergencyPage {
  build() {
    PlaceholderView({
      icon: $r('app.media.ic_tab_emergency'),
      title: $r('app.string.emergency_title'),
      subtitle: $r('app.string.emergency_placeholder')
    })
  }
}
