// Small shared building blocks: card surface, section header, risk badge, primary/secondary buttons.
// Press feedback everywhere uses the native clickEffect (subtle scale), no custom motion.

import { RiskLevel } from '../model/DrugVerdict';
import { RiskUi } from '../common/RiskUi';

@ComponentV2
export struct Card {
  @Param pad: number = 16;
  @BuilderParam content: () => void = this.emptyContent;

  @Builder
  emptyContent() {
  }

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(this.pad)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius($r('app.float.radius_m'))
  }
}

@ComponentV2
export struct SectionHeader {
  @Param title: ResourceStr = '';
  @Param action: ResourceStr = '';
  @Event onAction: () => void = () => {
  };

  build() {
    Row() {
      Text(this.title)
        .fontSize($r('app.float.font_small'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
        .layoutWeight(1)
      if (this.action !== '') {
        Text(this.action)
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.brand_accent'))
          .padding({ left: 8, top: 4, bottom: 4 })
          .onClick(() => this.onAction())
      }
    }
    .width('100%')
    .padding({ left: 4, right: 4, top: 8, bottom: 4 })
  }
}

@ComponentV2
export struct RiskBadge {
  @Param risk: RiskLevel = 'UNKNOWN_DRUG';
  @Param compact: boolean = false;

  build() {
    Row({ space: 6 }) {
      Image(RiskUi.icon(this.risk))
        .width(this.compact ? 14 : 18)
        .height(this.compact ? 14 : 18)
        .fillColor(RiskUi.color(this.risk))
      Text(RiskUi.label(this.risk))
        .fontSize(this.compact ? $r('app.float.font_caption') : $r('app.float.font_small'))
        .fontWeight(FontWeight.Medium)
        .fontColor(RiskUi.color(this.risk))
    }
    .padding({ left: 10, right: 10, top: this.compact ? 3 : 6, bottom: this.compact ? 3 : 6 })
    .backgroundColor(RiskUi.soft(this.risk))
    .borderRadius(100)
  }
}

@ComponentV2
export struct PrimaryButton {
  @Param label: ResourceStr = '';
  @Param icon: Resource | undefined = undefined;
  @Param active: boolean = true;
  @Param danger: boolean = false;
  @Param large: boolean = false;
  @Event onTap: () => void = () => {
  };

  build() {
    Row({ space: 8 }) {
      if (this.icon !== undefined) {
        Image(this.icon).width(this.large ? 26 : 20).height(this.large ? 26 : 20).fillColor($r('app.color.on_accent'))
      }
      Text(this.label)
        .fontSize(this.large ? $r('app.float.font_subtitle') : $r('app.float.font_body'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.on_accent'))
    }
    .width('100%')
    .height(this.large ? $r('app.float.button_height_l') : $r('app.float.button_height'))
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.danger ? $r('app.color.emergency_header') : $r('app.color.brand_accent'))
    .borderRadius(100)
    .opacity(this.active ? 1 : 0.4)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
    .onClick(() => {
      if (this.active) {
        this.onTap();
      }
    })
  }
}

@ComponentV2
export struct SecondaryButton {
  @Param label: ResourceStr = '';
  @Param icon: Resource | undefined = undefined;
  @Event onTap: () => void = () => {
  };

  build() {
    Row({ space: 8 }) {
      if (this.icon !== undefined) {
        Image(this.icon).width(20).height(20).fillColor($r('app.color.brand_accent'))
      }
      Text(this.label)
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.brand_accent'))
    }
    .width('100%')
    .height($r('app.float.button_height'))
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.brand_accent_soft'))
    .borderRadius(100)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
    .onClick(() => this.onTap())
  }
}

// Tappable list row: icon, title, subtitle, chevron.
@ComponentV2
export struct NavRow {
  @Param icon: Resource = $r('app.media.ic_chevron_right');
  @Param title: ResourceStr = '';
  @Param subtitle: ResourceStr = '';
  @Event onTap: () => void = () => {
  };

  build() {
    Row({ space: 12 }) {
      Image(this.icon).width(22).height(22).fillColor($r('app.color.brand_accent'))
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize($r('app.float.font_body'))
          .fontColor($r('sys.color.font_primary'))
        if (this.subtitle !== '') {
          Text(this.subtitle)
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('sys.color.font_secondary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Image($r('app.media.ic_chevron_right')).width(18).height(18).fillColor($r('sys.color.icon_secondary'))
    }
    .width('100%')
    .padding({ top: 14, bottom: 14, left: 16, right: 12 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius($r('app.float.radius_m'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
    .onClick(() => this.onTap())
  }
}

// Page title used at the top of each tab.
@ComponentV2
export struct PageTitle {
  @Param title: ResourceStr = '';
  @Param subtitle: ResourceStr = '';

  build() {
    Column({ space: 4 }) {
      Text(this.title)
        .fontSize($r('app.float.font_headline'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      if (this.subtitle !== '') {
        Text(this.subtitle)
          .fontSize($r('app.float.font_small'))
          .fontColor($r('sys.color.font_secondary'))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 12, bottom: 8 })
  }
}
