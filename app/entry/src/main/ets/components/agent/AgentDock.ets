// The bottom of the agent screen: the voice dock (scan, talk, end or type) and the chat bar (scan, input, send or
// back to voice). Both only report taps; the page decides what they do.

import { VoicePhase } from '../../voice/RealtimeSession';

@ComponentV2
export struct VoiceDock {
  @Param phase: VoicePhase = 'OFF';
  @Param recording: boolean = false;   // a tap-to-talk question is being recorded
  @Param muted: boolean = false;
  @Param active: boolean = false;      // a voice session or recording is running
  @Event onMic: () => void = () => {
  };
  @Event onScan: () => void = () => {
  };
  @Event onEnd: () => void = () => {
  };
  @Event onKeyboard: () => void = () => {
  };

  @Builder
  dockSide(icon: Resource, a11y: Resource) {
    Row() {
      Image(icon).width(22).height(22).fillColor($r('app.color.ink'))
    }
    .width($r('app.float.dock_side'))
    .height($r('app.float.dock_side'))
    .justifyContent(FlexAlign.Center)
    .borderRadius(26)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .accessibilityText(a11y)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
  }

  // Coral mic to talk; outlined with a struck mic when muted; ink "send" while a tap-to-talk question records.
  @Builder
  dockMic() {
    Row() {
      Image(this.recording ? $r('app.media.ic_send') : (this.muted ? $r('app.media.ic_mic_off') :
        $r('app.media.ic_mic')))
        .width(30)
        .height(30)
        .fillColor(this.recording ? $r('app.color.chat_user_text') : (this.muted ? $r('app.color.ink') :
          $r('app.color.on_accent')))
    }
    .width($r('app.float.dock_main'))
    .height($r('app.float.dock_main'))
    .justifyContent(FlexAlign.Center)
    .borderRadius(36)
    .backgroundColor(this.recording ? $r('app.color.chat_user_bg') : (this.muted ? $r('app.color.surface') :
      $r('app.color.brand_accent')))
    .border({ width: this.muted ? 1.5 : 0, color: $r('app.color.border_strong') })
    .opacity(this.phase === 'CONNECTING' ? 0.6 : 1)
    .accessibilityText(this.recording ? $r('app.string.a11y_send') : (this.muted ? $r('app.string.a11y_unmute') :
      (this.phase === 'OFF' ? $r('app.string.a11y_mic') : $r('app.string.a11y_mute'))))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
    .onClick(() => {
      this.onMic();
    })
  }

  build() {
    Row() {
      Stack() {
        this.dockSide($r('app.media.ic_camera'), $r('app.string.a11y_camera'))
      }
      .onClick(() => {
        this.onScan();
      })
      this.dockMic()
      if (this.active) {
        Stack() {
          this.dockSide($r('app.media.ic_close'), $r('app.string.a11y_end'))
        }
        .onClick(() => {
          this.onEnd();
        })
      } else {
        Stack() {
          this.dockSide($r('app.media.ic_keyboard'), $r('app.string.a11y_keyboard'))
        }
        .onClick(() => {
          this.onKeyboard();
        })
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceEvenly)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 32, right: 32, top: 8, bottom: 20 })
  }
}

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
