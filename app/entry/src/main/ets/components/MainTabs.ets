// Bottom tab bar hosted inside the root Navigation (pages/Index.ets).

import { AgentPage } from '../pages/AgentPage';
import { MedicinesPage } from '../pages/MedicinesPage';
import { HeartPage } from '../pages/HeartPage';
import { EmergencyPage } from '../pages/EmergencyPage';

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
  @Local currentIndex: number = 0;

  private tabs: TabSpec[] = [
    new TabSpec(0, $r('app.string.tab_agent'), $r('app.media.ic_tab_agent')),
    new TabSpec(1, $r('app.string.tab_medicines'), $r('app.media.ic_tab_medicines')),
    new TabSpec(2, $r('app.string.tab_heart'), $r('app.media.ic_tab_heart')),
    new TabSpec(3, $r('app.string.tab_emergency'), $r('app.media.ic_tab_emergency'))
  ];

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
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() { AgentPage() }.tabBar(this.tabBar(this.tabs[0]))
      TabContent() { MedicinesPage() }.tabBar(this.tabBar(this.tabs[1]))
      TabContent() { HeartPage() }.tabBar(this.tabBar(this.tabs[2]))
      TabContent() { EmergencyPage() }.tabBar(this.tabBar(this.tabs[3]))
    }
    .scrollable(false)
    .barHeight(64)
    .onChange((index: number) => {
      this.currentIndex = index;
    })
  }
}
