// Bottom tab bar hosted inside the root Navigation (pages/Index.ets): Today · Medicines · (orb) · Health · Emergency
// (DESIGN.md §6.5, §10.1a). The orb in the middle is not a tab: it opens the agent stage. Any descendant can switch
// tabs through @Consumer('tabIndex') — see TabIndex in common/Routes.ets. Pushed pages use TabRequest instead.

import { HomePage } from '../pages/HomePage';
import { MedicinesPage } from '../pages/MedicinesPage';
import { HeartPage } from '../pages/HeartPage';
import { EmergencyPage } from '../pages/EmergencyPage';
import { Routes, TabIndex } from '../common/Routes';
import { TabRequest } from '../common/TabRequest';
import { Motion } from '../common/Motion';
import { common } from '@kit.AbilityKit';
import { SilkOrb } from './SilkOrb';
import { Brief, HomeBrief } from './agent/HomeBrief';

const ORB_DISC: number = 68;    // surface disc the orb sits on; about half of it stands above the bar

@ComponentV2
export struct MainTabs {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Provider('tabIndex') currentIndex: number = TabIndex.HOME;
  @Local nudge: boolean = HomeBrief.latest().nudge;   // the agent has something to say
  private offs: (() => void)[] = [];

  aboutToAppear(): void {
    Motion.start(this.getUIContext().getHostContext() as common.UIAbilityContext);
    const pending: number = TabRequest.take();
    if (pending >= 0) {
      this.currentIndex = pending;
    }
    this.offs.push(TabRequest.onOpen((tab: number) => {
      this.currentIndex = tab;
    }));
    this.offs.push(HomeBrief.onChange((b: Brief) => {
      this.nudge = b.nudge;
    }));
    TabRequest.setCurrent(this.currentIndex);
  }

  // The tab also changes from descendants (@Consumer('tabIndex')); keep TabRequest in step with all of them.
  @Monitor('currentIndex')
  onTabChange(m: IMonitor): void {
    TabRequest.setCurrent(this.currentIndex);
  }

  aboutToDisappear(): void {
    for (const off of this.offs) {
      off();
    }
    this.offs = [];
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
  iconTab(index: number, text: Resource, icon: Resource, a11y: Resource) {
    Column({ space: 4 }) {
      Image(icon)
        .width(24)
        .height(24)
        .fillColor(this.currentIndex === index ? $r('app.color.brand_accent') : $r('app.color.tab_inactive'))
      this.label(index, text, false)
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .accessibilityGroup(true)
    .accessibilityText(a11y)
    .accessibilitySelected(this.currentIndex === index)
    .onClick(() => {
      this.currentIndex = index;
    })
  }

  // Emergency is always tinted: an SOS pill plus a risk-text label. Findable but calm. Selected: the pill is solid.
  // Long press starts the same cancellable countdown as the Start SOS tile.
  @Builder
  emergencyTab() {
    Column({ space: 4 }) {
      Text($r('app.string.tab_sos'))
        .fontSize(10)   // DESIGN.md §6.5: 10 fp; no float token has this value (font_micro is 11, font_mono 9)
        .fontWeight(800)
        .letterSpacing(0.6)
        .fontColor(this.currentIndex === TabIndex.EMERGENCY ? $r('app.color.on_accent') :
          $r('app.color.risk_known_text'))
        .textAlign(TextAlign.Center)
        .height(24)
        .padding({ left: 10, right: 10 })
        .borderRadius(12)
        .backgroundColor(this.currentIndex === TabIndex.EMERGENCY ? $r('app.color.danger') :
          $r('app.color.brand_accent_soft'))
      this.label(TabIndex.EMERGENCY, $r('app.string.tab_emergency'), true)
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .accessibilityGroup(true)
    .accessibilityText($r('app.string.a11y_tab_emergency'))
    .accessibilitySelected(this.currentIndex === TabIndex.EMERGENCY)
    .onClick(() => {
      this.currentIndex = TabIndex.EMERGENCY;
    })
    .gesture(LongPressGesture({ duration: 600 }).onAction(() => {
      this.navStack.pushPathByName(Routes.SOS, null);
    }))
  }

  // The agent: the silk orb on a surface disc, raised above the bar, with a dot when it has something to say.
  @Builder
  talkOrb() {
    Column({ space: 2 }) {
      Stack({ alignContent: Alignment.TopEnd }) {
        Stack() {
          SilkOrb({ dim: 56, small: true })
        }
        .width(ORB_DISC)
        .height(ORB_DISC)
        .borderRadius(ORB_DISC / 2)
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.border') })
        .clip(true)
        if (this.nudge) {
          Circle()
            .width(12)
            .height(12)
            .fill($r('app.color.ink'))
            .stroke($r('app.color.surface'))
            .strokeWidth(2)
            .margin({ top: 6, right: 6 })
        }
      }
      .width(ORB_DISC)
      .height(ORB_DISC)
      Text($r('app.string.tab_talk'))
        .fontSize($r('app.float.font_micro'))
        .fontWeight(700)
        .fontColor($r('app.color.brand_text'))
        .maxLines(1)
    }
    .margin({ bottom: 8 })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.94 })
    .accessibilityGroup(true)
    .accessibilityText(this.nudge ? $r('app.string.a11y_tab_talk_nudge') : $r('app.string.a11y_tab_talk'))
    .onClick(() => {
      this.navStack.pushPathByName(Routes.AGENT_CHAT, null);
    })
  }

  @Builder
  bar() {
    Row() {
      this.iconTab(TabIndex.HOME, $r('app.string.tab_today'), $r('app.media.ic_tab_home'),
        $r('app.string.a11y_tab_today'))
      this.iconTab(TabIndex.MEDICINES, $r('app.string.tab_medicines'), $r('app.media.ic_tab_medicines'),
        $r('app.string.a11y_tab_medicines'))
      Blank().layoutWeight(1)   // the orb's slot
      this.iconTab(TabIndex.HEART, $r('app.string.tab_health'), $r('app.media.ic_tab_heart'),
        $r('app.string.a11y_tab_health'))
      this.emergencyTab()
    }
    .width('100%')
    .height($r('app.float.tab_bar_height'))
    .backgroundColor($r('app.color.surface'))
    .border({ width: { top: 1 }, color: $r('app.color.border') })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        Tabs({ index: this.currentIndex }) {
          TabContent() { HomePage() }
          TabContent() { MedicinesPage() }
          TabContent() { HeartPage() }
          TabContent() { EmergencyPage() }
        }
        .barHeight(0)
        .scrollable(false)
        .animationDuration(0)
        .layoutWeight(1)
        .onChange((index: number) => {
          this.currentIndex = index;
        })
        this.bar()
      }
      .width('100%')
      .height('100%')

      this.talkOrb()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg'))
  }
}
