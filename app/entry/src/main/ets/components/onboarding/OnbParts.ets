// Small building blocks shared by the onboarding steps (DESIGN.md 10.2 "Onboarding": title-1 per step).

@ComponentV2
export struct OnbHeading {
  @Param heading: ResourceStr = '';
  @Param subtitle: ResourceStr = '';

  build() {
    Column({ space: 6 }) {
      Text(this.heading)
        .fontSize($r('app.float.font_title_1'))
        .fontWeight(FontWeight.Bolder)
        .fontColor($r('app.color.ink'))
        .accessibilityLevel('yes')
      if (this.subtitle !== '') {
        Text(this.subtitle)
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink_3'))
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

@ComponentV2
export struct OnbInput {
  @Param value: string = '';
  @Param hint: ResourceStr = '';
  @Param inputType: InputType = InputType.Normal;
  @Event onInput: (value: string) => void = (value: string) => {
  };

  build() {
    TextInput({ text: this.value, placeholder: this.hint })
      .type(this.inputType)
      .width('100%')
      .height($r('app.float.touch_min'))
      .fontSize($r('app.float.font_body'))
      .backgroundColor($r('app.color.surface_alt'))
      .borderRadius($r('app.float.radius_s'))
      .onChange((v: string) => this.onInput(v))
  }
}
