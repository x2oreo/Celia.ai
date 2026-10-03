// OWNER: Georgi — tab body. My meds list + "Check a medicine" (text / photo → OcrService → DrugChecker).

import { PlaceholderView } from '../components/PlaceholderView';

@ComponentV2
export struct MedicinesPage {
  build() {
    PlaceholderView({
      icon: $r('app.media.ic_tab_medicines'),
      title: $r('app.string.medicines_title'),
      subtitle: $r('app.string.medicines_placeholder')
    })
  }
}
