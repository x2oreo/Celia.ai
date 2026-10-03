// Shared building blocks from docs/design/DESIGN.md §6: surfaces, buttons, risk badge and shape, chips, strips,
// source badges, typing dots. Press feedback uses the native clickEffect. Loops respect Motion.reduced.

import { RiskLevel } from '../model/DrugVerdict';
import { RiskUi } from '../common/RiskUi';
import { Motion } from '../common/Motion';

// Flat surface card: white, 1 vp border, no shadow (E0).
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
    .backgroundColor($r('app.color.surface'))
    .borderRadius($r('app.float.radius_l'))
    .border({ width: 1, color: $r('app.color.border') })
  }
}

// Caps section label ("MY MEDICINES · 3") with an optional coral text action.
@ComponentV2
export struct SectionHeader {
  @Param title: ResourceStr = '';
  @Param action: ResourceStr = '';
  @Event onAction: () => void = () => {
  };

  build() {
    Row() {
      Text(this.title)
        .fontSize($r('app.float.font_badge'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink_3'))
        .letterSpacing(0.6)
        .textCase(TextCase.UpperCase)
        .layoutWeight(1)
      if (this.action !== '') {
        Text(this.action)
          .fontSize($r('app.float.font_small'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.brand_text'))
          .padding({ left: 8, top: 4, bottom: 4 })
          .onClick(() => this.onAction())
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 2 })
  }
}

// Risk shape: octagon / triangle / diamond / check circle, or a dashed circle with "?" for Unknown.
@ComponentV2
export struct RiskShape {
  @Param risk: RiskLevel = 'UNKNOWN_DRUG';
  @Param dim: number = 24;

  build() {
    if (this.risk === 'UNKNOWN_DRUG') {
      Stack() {
        Circle()
          .width(this.dim)
          .height(this.dim)
          .fillOpacity(0)
          .stroke(RiskUi.color(this.risk))
          .strokeWidth(Math.max(1.5, this.dim / 14))
          .strokeDashArray([this.dim / 8, this.dim / 10])
        Text('?')
          .fontSize(this.dim * 0.55)
          .fontWeight(FontWeight.Bolder)
          .fontColor(RiskUi.color(this.risk))
      }
      .width(this.dim)
      .height(this.dim)
    } else {
      Image(RiskUi.icon(this.risk))
        .width(this.dim)
        .height(this.dim)
        .fillColor(RiskUi.color(this.risk))
    }
  }
}

// Risk badge pill (DESIGN.md §3): shape + CAPS word on the risk tint. `compact` is the small grid/list variant.
@ComponentV2
export struct RiskBadge {
  @Param risk: RiskLevel = 'UNKNOWN_DRUG';
  @Param compact: boolean = false;

  build() {
    Row({ space: this.compact ? 5 : 8 }) {
      RiskShape({ risk: this.risk, dim: this.compact ? 16 : 24 })
      Text(RiskUi.label(this.risk))
        .fontSize(this.compact ? $r('app.float.font_micro') : $r('app.float.font_badge'))
        .fontWeight(800)
        .letterSpacing(this.compact ? 0 : 0.4)
        .textCase(this.compact ? TextCase.Normal : TextCase.UpperCase)
        .fontColor(RiskUi.text(this.risk))
    }
    .height(this.compact ? 24 : 32)
    .padding({ left: 4, right: this.compact ? 8 : 12 })
    .backgroundColor(RiskUi.tint(this.risk))
    .borderRadius(this.compact ? 12 : 16)
  }
}

@Builder
function buttonContent(label: ResourceStr, icon: Resource | undefined, color: ResourceColor, weight: number) {
  if (icon !== undefined) {
    Image(icon).width(20).height(20).fillColor(color)
  }
  Text(label)
    .fontSize($r('app.float.font_button'))
    .fontWeight(weight)
    .fontColor(color)
    .maxLines(1)
    .textOverflow({ overflow: TextOverflow.Ellipsis })
}

// Coral primary (Scan, mic, send). `danger` turns it into the emergency-only red button.
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
      buttonContent(this.label, this.icon, $r('app.color.on_accent'), this.danger ? 800 : 700)
    }
    .width('100%')
    .height(this.large ? $r('app.float.button_height_sheet') : $r('app.float.button_height'))
    .padding({ left: 20, right: 20 })
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.danger ? $r('app.color.danger') : $r('app.color.brand_accent'))
    .borderRadius($r('app.float.radius_btn'))
    .opacity(this.active ? 1 : 0.4)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
    .onClick(() => {
      if (this.active) {
        this.onTap();
      }
    })
  }
}

// Ink button: the primary action inside verdicts and agent cards. Never coral.
@ComponentV2
export struct InkButton {
  @Param label: ResourceStr = '';
  @Param icon: Resource | undefined = undefined;
  @Param large: boolean = false;
  @Param fill: boolean = true;
  @Event onTap: () => void = () => {
  };

  build() {
    Row({ space: 8 }) {
      buttonContent(this.label, this.icon, $r('app.color.chat_user_text'), 700)
    }
    .width(this.fill ? '100%' : undefined)
    .height(this.large ? $r('app.float.button_height_sheet') : $r('app.float.button_height'))
    .padding({ left: 20, right: 20 })
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.chat_user_bg'))
    .borderRadius($r('app.float.radius_btn'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
    .onClick(() => this.onTap())
  }
}

// Secondary: transparent with a 1.5 vp strong border, ink text.
@ComponentV2
export struct SecondaryButton {
  @Param label: ResourceStr = '';
  @Param icon: Resource | undefined = undefined;
  @Param large: boolean = false;
  @Param fill: boolean = true;
  @Event onTap: () => void = () => {
  };

  build() {
    Row({ space: 8 }) {
      buttonContent(this.label, this.icon, $r('app.color.ink'), 600)
    }
    .width(this.fill ? '100%' : undefined)
    .height(this.large ? $r('app.float.button_height_sheet') : $r('app.float.button_height'))
    .padding({ left: 20, right: 20 })
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1.5, color: $r('app.color.border_strong') })
    .borderRadius($r('app.float.radius_btn'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
    .onClick(() => this.onTap())
  }
}

// Quiet button on surface_alt ("Ask something").
@ComponentV2
export struct QuietButton {
  @Param label: ResourceStr = '';
  @Param icon: Resource | undefined = undefined;
  @Param fill: boolean = true;
  @Event onTap: () => void = () => {
  };

  build() {
    Row({ space: 8 }) {
      buttonContent(this.label, this.icon, $r('app.color.ink'), 600)
    }
    .width(this.fill ? '100%' : undefined)
    .height($r('app.float.button_height'))
    .padding({ left: 20, right: 20 })
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.surface_alt'))
    .borderRadius($r('app.float.radius_btn'))
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
      Row() {
        Image(this.icon).width(20).height(20).fillColor($r('app.color.ink_2'))
      }
      .width(36)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.surface_alt'))
      .borderRadius($r('app.float.radius_s'))
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize($r('app.float.font_body'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ink'))
        if (this.subtitle !== '') {
          Text(this.subtitle)
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.ink_3'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Image($r('app.media.ic_chevron_right')).width(18).height(18).fillColor($r('app.color.ink_4'))
    }
    .width('100%')
    .constraintSize({ minHeight: $r('app.float.touch_min') })
    .padding({ top: 12, bottom: 12, left: 12, right: 12 })
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_m'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
    .onClick(() => this.onTap())
  }
}

// Screen title (title-1) with an optional subtitle.
@ComponentV2
export struct PageTitle {
  @Param title: ResourceStr = '';
  @Param subtitle: ResourceStr = '';

  build() {
    Column({ space: 4 }) {
      Text(this.title)
        .fontSize($r('app.float.font_title_1'))
        .fontWeight(800)
        .fontColor($r('app.color.ink'))
      if (this.subtitle !== '') {
        Text(this.subtitle)
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink_3'))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 16, bottom: 8 })
  }
}

// Back-arrow header for pushed pages.
@ComponentV2
export struct BackHeader {
  @Param title: ResourceStr = '';
  @Event onBack: () => void = () => {
  };

  build() {
    Row({ space: 4 }) {
      Row() {
        Image($r('app.media.ic_chevron_left')).width(24).height(24).fillColor($r('app.color.ink'))
      }
      .width(48)
      .height(48)
      .justifyContent(FlexAlign.Center)
      .onClick(() => this.onBack())
      Text(this.title)
        .fontSize($r('app.float.font_headline'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .layoutWeight(1)
    }
    .width('100%')
    .height(56)
    .padding({ left: 4, right: 16 })
  }
}

// Mono technical badge: WATCH (solid ink), SIMULATED (outlined), ON-DEVICE (outlined).
@ComponentV2
export struct SourceBadge {
  @Param label: ResourceStr = '';
  @Param solid: boolean = false;

  build() {
    Text(this.label)
      .fontFamily('monospace')
      .fontSize($r('app.float.font_mono'))
      .fontWeight(FontWeight.Bold)
      .letterSpacing(0.5)
      .fontColor(this.solid ? $r('app.color.chat_user_text') : $r('app.color.ink'))
      .backgroundColor(this.solid ? $r('app.color.chat_user_bg') : $r('app.color.surface'))
      .border({ width: this.solid ? 0 : 1, color: $r('app.color.ink') })
      .borderRadius(4)
      .padding({ left: 5, right: 5, top: 3, bottom: 3 })
  }
}

// Pill chip on surface with a border ("Medicines OK", "Gentle alarm on"); optional leading risk shape.
@ComponentV2
export struct StatusChip {
  @Param label: ResourceStr = '';
  @Param risk: RiskLevel | undefined = undefined;
  @Event onTap: () => void = () => {
  };

  build() {
    Row({ space: 6 }) {
      if (this.risk !== undefined) {
        RiskShape({ risk: this.risk, dim: 20 })
      }
      Text(this.label)
        .fontSize($r('app.float.font_small'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.ink'))
        .maxLines(1)
    }
    .height(40)
    .padding({ left: this.risk !== undefined ? 10 : 14, right: 14 })
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius(20)
    .onClick(() => this.onTap())
  }
}

export type ChipStyle = 'DEFAULT' | 'SELECTED' | 'ESCALATION';

// Quick-reply / filter chip (DESIGN.md §6.3). Escalation is outlined danger, never filled.
@ComponentV2
export struct QuickReplyChip {
  @Param label: ResourceStr = '';
  @Param chipStyle: ChipStyle = 'DEFAULT';
  @Param icon: Resource | undefined = undefined;
  @Event onTap: () => void = () => {
  };

  private fg(): ResourceColor {
    if (this.chipStyle === 'SELECTED') {
      return $r('app.color.chat_user_text');
    }
    return this.chipStyle === 'ESCALATION' ? $r('app.color.risk_known_text') : $r('app.color.ink');
  }

  build() {
    Row({ space: 6 }) {
      if (this.icon !== undefined) {
        Image(this.icon).width(18).height(18).fillColor(this.fg())
      }
      Text(this.label)
        .fontSize($r('app.float.font_button'))
        .fontWeight(this.chipStyle === 'ESCALATION' ? 700 : 600)
        .fontColor(this.fg())
        .maxLines(1)
    }
    .height($r('app.float.chip_height'))
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.chipStyle === 'SELECTED' ? $r('app.color.chat_user_bg') : $r('app.color.surface'))
    .border({
      width: this.chipStyle === 'SELECTED' ? 0 : 1.5,
      color: this.chipStyle === 'ESCALATION' ? $r('app.color.danger') : $r('app.color.border_strong')
    })
    .borderRadius(22)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
    .onClick(() => this.onTap())
  }
}

export type StripKind = 'OFFLINE' | 'ERROR';

// Offline (neutral grey, not an error) or error (amber, never red) strip, with an optional fallback action.
@ComponentV2
export struct StatusStrip {
  @Param kind: StripKind = 'OFFLINE';
  @Param label: ResourceStr = '';
  @Param action: ResourceStr = '';
  @Event onAction: () => void = () => {
  };

  build() {
    Row({ space: 10 }) {
      if (this.kind === 'OFFLINE') {
        Circle().width(8).height(8).fill($r('app.color.ink_4'))
      } else {
        RiskShape({ risk: 'POSSIBLE_RISK', dim: 18 })
      }
      Text(this.label)
        .fontSize($r('app.float.font_badge'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.kind === 'OFFLINE' ? $r('app.color.status_offline_text') : $r('app.color.risk_possible_text'))
        .layoutWeight(1)
      if (this.action !== '') {
        Text(this.action)
          .fontSize($r('app.float.font_badge'))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.kind === 'OFFLINE' ? $r('app.color.status_offline_text') : $r('app.color.risk_possible_text'))
          .decoration({ type: TextDecorationType.Underline })
          .onClick(() => this.onAction())
      }
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor(this.kind === 'OFFLINE' ? $r('app.color.status_offline_bg') : $r('app.color.risk_possible_tint'))
    .borderRadius($r('app.float.radius_s'))
  }
}

// Empty state: dashed card, centred message, one primary action.
@ComponentV2
export struct EmptyCard {
  @Param message: ResourceStr = '';
  @Param action: ResourceStr = '';
  @Event onAction: () => void = () => {
  };

  build() {
    Column({ space: 14 }) {
      Text(this.message)
        .fontSize($r('app.float.font_badge'))
        .fontColor($r('app.color.ink_3'))
        .textAlign(TextAlign.Center)
      if (this.action !== '') {
        PrimaryButton({ label: this.action, onTap: () => this.onAction() })
          .width(200)
      }
    }
    .width('100%')
    .padding(24)
    .border({ width: 2, color: $r('app.color.border_strong'), style: BorderStyle.Dashed })
    .borderRadius($r('app.float.radius_m'))
  }
}

// Three breathing dots, optionally with a label ("Reading the box…").
@ComponentV2
export struct TypingDots {
  @Param label: ResourceStr = '';
  @Local on: boolean = false;

  @Builder
  dot(delay: number) {
    Circle()
      .width(7)
      .height(7)
      .fill($r('app.color.ink_4'))
      .opacity(this.on ? 1 : 0.3)
      .animation(Motion.reduced ? undefined : {
        duration: 600,
        delay: delay,
        curve: Curve.EaseInOut,
        iterations: -1,
        playMode: PlayMode.Alternate
      })
  }

  build() {
    Row({ space: 10 }) {
      Row({ space: 5 }) {
        this.dot(0)
        this.dot(150)
        this.dot(300)
      }
      if (this.label !== '') {
        Text(this.label)
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink_3'))
      }
    }
    .onAppear(() => {
      this.on = true;
    })
  }
}

// Bottom-sheet grabber.
@ComponentV2
export struct SheetGrabber {
  build() {
    Row()
      .width(36)
      .height(4)
      .borderRadius(2)
      .backgroundColor($r('app.color.border_strong'))
      .margin({ top: 8, bottom: 8 })
  }
}
