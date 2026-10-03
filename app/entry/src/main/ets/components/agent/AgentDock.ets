// The chat bar of the agent stage (typing mode): scan, input, send or back to voice. It only reports taps; the page
// decides what they do. The voice dock is components/agent/OrbDock.ets.

@ComponentV2
export struct ChatBar {
  @Param draft: string = '';
  @Event onDraft: (text: string) => void = (text: string) => {
  };
  @Event onSend: () => void = () => {
  };
  @Event onScan: () => void = () => {
  };
  @Event onVoice: () => void = () => {
  };

  @Builder
  roundButton(icon: Resource, filled: boolean, a11y: Resource) {
    Row() {
      Image(icon)
        .width(22)
        .height(22)
        .fillColor(filled ? $r('app.color.on_accent') : $r('app.color.ink'))
    }
    .width($r('app.float.touch_min'))
    .height($r('app.float.touch_min'))
    .justifyContent(FlexAlign.Center)
    .borderRadius(24)
    .backgroundColor(filled ? $r('app.color.brand_accent') : $r('app.color.surface'))
    .border({ width: filled ? 0 : 1, color: $r('app.color.border') })
    .accessibilityText(a11y)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
  }

  build() {
    Row({ space: 8 }) {
      Stack() {
        this.roundButton($r('app.media.ic_camera'), false, $r('app.string.a11y_camera'))
      }
      .onClick(() => {
        this.onScan();
      })
      TextInput({ text: this.draft, placeholder: $r('app.string.agent_input_hint') })
        .layoutWeight(1)
        .height($r('app.float.touch_min'))
        .borderRadius(24)
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.border') })
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.ink'))
        .placeholderColor($r('app.color.ink_4'))
        .enterKeyType(EnterKeyType.Send)
        .onChange((v: string) => {
          this.onDraft(v);
        })
        .onSubmit(() => {
          this.onSend();
        })
      if (this.draft.trim().length > 0) {
        Stack() {
          this.roundButton($r('app.media.ic_send'), true, $r('app.string.a11y_send'))
        }
        .onClick(() => {
          this.onSend();
        })
      } else {
        Stack() {
          this.roundButton($r('app.media.ic_wave'), true, $r('app.string.a11y_voice'))
        }
        .onClick(() => {
          this.onVoice();
        })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 12 })
  }
}
