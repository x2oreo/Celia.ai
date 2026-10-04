// Settings list pieces (DESIGN.md 6.11): a caps-labelled group card, its rows and the inset divider between them.

import { CapsLabel } from './Common';

// One group: caps label, then a surface card holding SettingsRow / SettingsDivider children.
@ComponentV2
export struct SettingsGroup {
  @Param label: ResourceStr = '';
  @BuilderParam content: () => void;

  build() {
    Column({ space: 8 }) {
      if (this.label !== '') {
        CapsLabel({ text: this.label })
          .padding({ left: 4 })
      }
      Column() {
        this.content()
      }
      .width('100%')
      .backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.border') })
      .borderRadius($r('app.float.radius_l'))
      .clip(true)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

// 1 vp divider that starts after the icon well.
@ComponentV2
export struct SettingsDivider {
  build() {
    Divider()
      .strokeWidth(1)
      .color($r('app.color.divider'))
      .margin({ left: 64 })
  }
}

// Icon well, title, value line in words, chevron. `danger` is the clear-data row: red, no chevron.
@ComponentV2
export struct SettingsRow {
  @Param icon: Resource = $r('app.media.ic_settings');
  @Param title: ResourceStr = '';
  @Param value: ResourceStr = '';
  @Param danger: boolean = false;
  @Event onTap: () => void = () => {
  };

  build() {
    Row({ space: 12 }) {
      Row() {
        Image(this.icon)
          .width(20)
          .height(20)
          .fillColor(this.danger ? $r('app.color.risk_known') : $r('app.color.ink_2'))
      }
      .width(36)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.danger ? $r('app.color.risk_known_tint') : $r('app.color.surface_alt'))
      .borderRadius($r('app.float.radius_s'))
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize($r('app.float.font_body'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.danger ? $r('app.color.risk_known') : $r('app.color.ink'))
        if (this.value !== '') {
          Text(this.value)
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.ink_3'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (!this.danger) {
        Image($r('app.media.ic_chevron_right')).width(18).height(18).fillColor($r('app.color.ink_4'))
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 60 })
    .padding({ top: 12, bottom: 12, left: 16, right: 16 })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
    .accessibilityGroup(true)
    .onClick(() => this.onTap())
  }
}
