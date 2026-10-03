// Bottom tab bar hosted inside the root Navigation (pages/Index.ets).
// Any descendant can switch tabs through @Consumer('tabIndex') — see TabIndex in common/Routes.ets.

import { HomePage } from '../pages/HomePage';
import { AgentPage } from '../pages/AgentPage';
import { MedicinesPage } from '../pages/MedicinesPage';
import { HeartPage } from '../pages/HeartPage';
import { EmergencyPage } from '../pages/EmergencyPage';
import { TabIndex } from '../common/Routes';
import { TabRequest } from '../common/TabRequest';

class TabSpec {
  index: number;
  label: Resource;
  icon: Resource;

  constructor(index: number, label: Resource, icon: Resource) {
    this.index = index;
    this.label = label;
    this.icon = icon;
  }
}

@ComponentV2
export struct MainTabs {
  @Provider('tabIndex') currentIndex: number = TabIndex.HOME;

  private tabs: TabSpec[] = [
    new TabSpec(TabIndex.HOME, $r('app.string.tab_home'), $r('app.media.ic_tab_home')),
    new TabSpec(TabIndex.MEDICINES, $r('app.string.tab_medicines'), $r('app.media.ic_tab_medicines')),
    new TabSpec(TabIndex.HEART, $r('app.string.tab_heart'), $r('app.media.ic_tab_heart')),
    new TabSpec(TabIndex.EMERGENCY, $r('app.string.tab_emergency'), $r('app.media.ic_tab_emergency')),
    new TabSpec(TabIndex.AGENT, $r('app.string.tab_agent'), $r('app.media.ic_tab_agent'))
  ];

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
  tabBar(spec: TabSpec) {
    Column({ space: 4 }) {
      Image(spec.icon)
        .width(24)
        .height(24)
        .fillColor(this.currentIndex === spec.index ? $r('app.color.brand_accent') : $r('sys.color.icon_secondary'))
      Text(spec.label)
        .fontSize($r('app.float.font_caption'))
        .fontColor(this.currentIndex === spec.index ? $r('app.color.brand_accent') : $r('sys.color.font_secondary'))
        .maxLines(1)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() { HomePage() }.tabBar(this.tabBar(this.tabs[0]))
      TabContent() { MedicinesPage() }.tabBar(this.tabBar(this.tabs[1]))
      TabContent() { HeartPage() }.tabBar(this.tabBar(this.tabs[2]))
      TabContent() { EmergencyPage() }.tabBar(this.tabBar(this.tabs[3]))
      TabContent() { AgentPage() }.tabBar(this.tabBar(this.tabs[4]))
    }
    .scrollable(false)
    .animationDuration(0)
    .barHeight(64)
    .barBackgroundColor($r('app.color.card_bg'))
    .onChange((index: number) => {
      this.currentIndex = index;
    })
  }
}
