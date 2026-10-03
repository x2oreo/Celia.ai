import { Theme } from './Theme';

/** Capsule button used on alert screens (W2/W3/W5/W6). */
@ComponentV2
export struct Pill {
  @Param @Require label: string;
  @Param bg: string = Theme.BUTTON;
  @Param fg: string = Theme.TEXT;
  @Param pillWidth: number = 80;
  @Param pillHeight: number = 34;
  @Param fontSize: number = 14;
  @Event onTap: () => void = () => {};

  build() {
    Button(this.label)
      .width(this.pillWidth)
      .height(this.pillHeight)
      .fontSize(this.fontSize)
      .fontWeight(FontWeight.Bold)
      .backgroundColor(this.bg)
      .fontColor(this.fg)
      .padding({ left: 4, right: 4 })
      .onClick(() => this.onTap())
  }
}
