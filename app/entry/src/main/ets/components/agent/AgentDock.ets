// The bottom of the agent stage (DESIGN.md §10.1a): the voice dock and the chat bar. Voice dock, idle: camera, coral
// mic, "Aa" (type). Live: Mute, ink End, "Aa". Recording one question (tap-to-talk): cancel, ink send, "Aa".
// Both only report taps; the page decides what they do.

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
  sideIcon(icon: Resource, a11y: Resource, onTap: () => void) {
    Row() {
      Image(icon).width(24).height(24).fillColor($r('app.color.ink'))
    }
    .width($r('app.float.dock_side'))
    .height($r('app.float.dock_side'))
    .justifyContent(FlexAlign.Center)
    .borderRadius(30)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .accessibilityGroup(true)
    .accessibilityText(a11y)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
    .onClick(onTap)
  }

  @Builder
  sideWord(word: ResourceStr, a11y: Resource, on: boolean, onTap: () => void) {
    Row() {
      Text(word)
        .fontSize($r('app.float.font_badge'))
        .fontWeight(FontWeight.Bold)
        .fontColor(on ? $r('app.color.chat_user_text') : $r('app.color.ink'))
        .maxLines(1)
    }
    .width($r('app.float.dock_side'))
    .height($r('app.float.dock_side'))
    .justifyContent(FlexAlign.Center)
    .borderRadius(30)
    .backgroundColor(on ? $r('app.color.chat_user_bg') : $r('app.color.surface'))
    .border({ width: on ? 0 : 1, color: $r('app.color.border') })
    .accessibilityGroup(true)
    .accessibilityText(a11y)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
    .onClick(onTap)
  }

  // Idle: the coral mic. The microphone only opens on this tap (or a tap on the orb).
  @Builder
  micButton() {
    Row() {
      Image($r('app.media.ic_mic')).width(30).height(30).fillColor($r('app.color.on_accent'))
    }
    .width($r('app.float.dock_main'))
    .height($r('app.float.dock_main'))
    .justifyContent(FlexAlign.Center)
    .borderRadius(40)
    .backgroundColor($r('app.color.brand_accent'))
    .accessibilityGroup(true)
    .accessibilityText($r('app.string.a11y_mic'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
    .onClick(() => {
      this.onMic();
    })
  }

  // Live: End is ink, not red. Ending a conversation is not an emergency.
  @Builder
  endButton() {
    Column({ space: 2 }) {
      Image($r('app.media.ic_close')).width(20).height(20).fillColor($r('app.color.chat_user_text'))
      Text($r('app.string.agent_end'))
        .fontSize($r('app.float.font_badge'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.chat_user_text'))
    }
    .width($r('app.float.dock_main'))
    .height($r('app.float.dock_main'))
    .justifyContent(FlexAlign.Center)
    .borderRadius(40)
    .backgroundColor($r('app.color.chat_user_bg'))
    .accessibilityGroup(true)
    .accessibilityText($r('app.string.a11y_end'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
    .onClick(() => {
      this.onEnd();
    })
  }

  @Builder
  sendButton() {
    Row() {
      Image($r('app.media.ic_send')).width(30).height(30).fillColor($r('app.color.chat_user_text'))
    }
    .width($r('app.float.dock_main'))
    .height($r('app.float.dock_main'))
    .justifyContent(FlexAlign.Center)
    .borderRadius(40)
    .backgroundColor($r('app.color.chat_user_bg'))
    .accessibilityGroup(true)
    .accessibilityText($r('app.string.a11y_send'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
    .onClick(() => {
      this.onMic();
    })
  }

  build() {
    Row() {
      if (this.recording) {
        this.sideIcon($r('app.media.ic_close'), $r('app.string.a11y_end'), () => {
          this.onEnd();
        })
        this.sendButton()
      } else if (this.active) {
        this.sideWord(this.muted ? $r('app.string.agent_unmute') : $r('app.string.agent_mute'),
          this.muted ? $r('app.string.a11y_unmute') : $r('app.string.a11y_mute'), this.muted, () => {
            this.onMic();
          })
        this.endButton()
      } else {
        this.sideIcon($r('app.media.ic_scan'), $r('app.string.a11y_camera'), () => {
          this.onScan();
        })
        this.micButton()
      }
      this.sideWord($r('app.string.agent_type'), $r('app.string.a11y_keyboard'), false, () => {
        this.onKeyboard();
      })
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
