// Bottom tab bar hosted inside the root Navigation (pages/Index.ets): Agent · Medicines · Heart · Emergency
// (DESIGN.md §6.5). Any descendant can switch tabs through @Consumer('tabIndex') — see TabIndex in
// common/Routes.ets. Pushed pages use TabRequest instead.

import { HomePage } from '../pages/HomePage';
import { MedicinesPage } from '../pages/MedicinesPage';
import { HeartPage } from '../pages/HeartPage';
import { EmergencyPage } from '../pages/EmergencyPage';
import { TabIndex } from '../common/Routes';
import { TabRequest } from '../common/TabRequest';
import { AgentAvatar } from './AgentAvatar';

@ComponentV2
export struct MainTabs {
  @Provider('tabIndex') currentIndex: number = TabIndex.HOME;
  private offOpen: () => void = () => {
  };

  aboutToAppear(): void {
    const pending: number = TabRequest.take();
    if (pending >= 0) {
      this.currentIndex = pending;
    }
    this.offOpen = TabRequest.onOpen((tab: number) => {
      this.currentIndex = tab;
    });
  }

  aboutToDisappear(): void {
    this.offOpen();
  }

  @Builder
  label(index: number, text: Resource, emergency: boolean) {
    Text(text)
      .fontSize($r('app.float.font_micro'))
      .fontWeight(this.currentIndex === index ? 700 : 600)
      .fontColor(emergency ? $r('app.color.risk_known_text') :
        (this.currentIndex === index ? $r('app.color.brand_text') : $r('app.color.tab_inactive')))
      .maxLines(1)
  }

  @Builder
  iconTab(index: number, text: Resource, icon: Resource) {
    Column({ space: 4 }) {
      Image(icon)
        .width(24)
        .height(24)
        .fillColor(this.currentIndex === index ? $r('app.color.brand_accent') : $r('app.color.tab_inactive'))
      this.label(index, text, false)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  // The agent tab uses the small orb; it only breathes while its tab is active.
  @Builder
  agentTab() {
    Column({ space: 4 }) {
      Stack() {
        AgentAvatar({ dim: 24, breathing: false })
          .opacity(this.currentIndex === TabIndex.HOME ? 1 : 0.55)
      }
      .width(24)
      .height(24)
      this.label(TabIndex.HOME, $r('app.string.tab_agent'), false)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  // Emergency is always tinted: an SOS pill plus a risk-text label. Findable but calm.
  @Builder
  emergencyTab() {
    Column({ space: 4 }) {
      Text($r('app.string.tab_sos'))
        .fontSize(10)
        .fontWeight(800)
        .letterSpacing(0.6)
        .fontColor($r('app.color.risk_known_text'))
        .textAlign(TextAlign.Center)
        .height(24)
        .padding({ left: 10, right: 10 })
        .borderRadius(12)
        .backgroundColor($r('app.color.brand_accent_soft'))
      this.label(TabIndex.EMERGENCY, $r('app.string.tab_emergency'), true)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() { HomePage() }.tabBar(this.agentTab())
      TabContent() { MedicinesPage() }
        .tabBar(this.iconTab(TabIndex.MEDICINES, $r('app.string.tab_medicines'), $r('app.media.ic_tab_medicines')))
      TabContent() { HeartPage() }
        .tabBar(this.iconTab(TabIndex.HEART, $r('app.string.tab_heart'), $r('app.media.ic_tab_heart')))
      TabContent() { EmergencyPage() }.tabBar(this.emergencyTab())
    }
    .scrollable(false)
    .animationDuration(0)
    .barHeight($r('app.float.tab_bar_height'))
    .barBackgroundColor($r('app.color.surface'))
    .divider({ strokeWidth: 1, color: $r('app.color.border') })
    .onChange((index: number) => {
      this.currentIndex = index;
    })
  }
}
