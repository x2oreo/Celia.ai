// The bottom of the agent stage in voice mode (DESIGN.md §10.1a, screens 02 and 03): the orb sits where a mic
// button would, with one round button on each side. The dock floats over the conversation, which runs the full
// height of the stage underneath it. OrbBackdrop (below) fades the conversation out behind the orb and lets a
// soft glow push out from the orb with the voice. No rings, no lines: only light.
//   idle       scan · orb (tap: talk) · type
//   live       End  · orb (tap: mute / unmute) · type
//   recording  cancel · orb (tap: send) · type      (tap-to-talk, when live voice is unavailable)
// The dock only reports taps; the page decides what they do. The state is always written above the orb.

import { Config } from '../../common/Config';
import { VoicePhase } from '../../voice/RealtimeSession';
import { SourceBadge } from '../Common';
import { SilkOrb } from '../SilkOrb';

const ORB: number = 104;
const DOCK_H: number = 128;        // orb row
const GLOW: number = 300;          // diameter of the glow at rest; it sits centred on the orb
const FADE_H: number = 310;        // the conversation fades into the background over this height
const LEVEL_MS: number = 160;
const FADE_MS: number = 320;

// Room the conversation leaves at its end so its last lines can scroll clear of the floating dock.
export const DOCK_CLEARANCE: number = 250;

// Behind the floating dock: the conversation fades into the background, and a soft glow pushes out from the orb.
// Warm for the agent, neutral while the user is heard; it opens a little with the voice. Takes no touches.
@ComponentV2
export struct OrbBackdrop {
  @Param phase: VoicePhase = 'OFF';
  @Param level: number = 0;
  @Param muted: boolean = false;

  private userVoice(): boolean {
    return this.phase === 'HEARING' || this.phase === 'LISTENING';
  }

  // 0..1: how far the glow opens. Idle keeps a faint glow so the orb never sits on a dead surface.
  private glow(): number {
    if (this.muted) {
      return 0.1;
    }
    if (this.phase === 'OFF') {
      return 0.3;
    }
    if (this.phase === 'HEARING' || this.phase === 'SPEAKING') {
      return 0.6 + 0.4 * Math.max(0.25, Math.min(1, this.level));
    }
    return 0.5;
  }

  @Builder
  glowDisc(from: Resource, to: Resource, on: boolean) {
    Row()
      .width(GLOW)
      .height(GLOW)
      .radialGradient({ center: ['50%', '50%'], radius: '50%', colors: [[from, 0], [to, 1]] })
      .opacity(on ? 1 : 0)
      .animation({ duration: FADE_MS, curve: Curve.EaseInOut })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Row()
        .width('100%')
        .height('100%')
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [[$r('app.color.bg_clear'), 0], [$r('app.color.bg'), 0.3], [$r('app.color.bg'), 1]]
        })
      Stack() {
        this.glowDisc($r('app.color.orb_glow'), $r('app.color.orb_glow_clear'), !this.userVoice())
        this.glowDisc($r('app.color.orb_glow_user'), $r('app.color.orb_glow_user_clear'), this.userVoice())
      }
      .width(GLOW)
      .height(GLOW)
      // Centred on the orb: the orb row is DOCK_H tall and sits 8 vp above the bottom edge.
      .margin({ bottom: 8 + DOCK_H / 2 - GLOW / 2 })
      .opacity(this.glow())
      .scale({ x: 0.8 + 0.5 * this.glow(), y: 0.8 + 0.5 * this.glow() })
      .animation({ duration: LEVEL_MS, curve: Curve.EaseOut })
    }
    .width('100%')
    .height(FADE_H)
    .clip(true)
    .hitTestBehavior(HitTestMode.None)
  }
}

@ComponentV2
export struct OrbDock {
  @Param phase: VoicePhase = 'OFF';    // what the orb shows (thinking while a typed turn runs, too)
  @Param level: number = 0;
  @Param muted: boolean = false;
  @Param recording: boolean = false;   // a tap-to-talk question is being recorded
  @Param active: boolean = false;      // a voice session or recording is running
  @Param label: ResourceStr = '';
  @Event onOrb: () => void = () => {
  };
  @Event onScan: () => void = () => {
  };
  @Event onEnd: () => void = () => {
  };
  @Event onKeyboard: () => void = () => {
  };
  private userVoice(): boolean {
    return this.phase === 'HEARING' || this.phase === 'LISTENING';
  }

  private hint(): Resource | undefined {
    if (this.recording) {
      return $r('app.string.agent_orb_send');
    }
    if (!this.active) {
      return undefined;
    }
    return this.muted ? $r('app.string.agent_orb_unmute') : $r('app.string.agent_orb_mute');
  }

  private orbA11y(): Resource {
    if (this.recording) {
      return $r('app.string.a11y_send');
    }
    if (!this.active) {
      return $r('app.string.a11y_orb');
    }
    return this.muted ? $r('app.string.a11y_unmute') : $r('app.string.a11y_mute');
  }

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

  // End is ink, not red: ending a conversation is not an emergency.
  @Builder
  endButton() {
    Column({ space: 1 }) {
      Image($r('app.media.ic_close')).width(18).height(18).fillColor($r('app.color.chat_user_text'))
      Text($r('app.string.agent_end'))
        .fontSize($r('app.float.font_micro'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.chat_user_text'))
    }
    .width($r('app.float.dock_side'))
    .height($r('app.float.dock_side'))
    .justifyContent(FlexAlign.Center)
    .borderRadius(30)
    .backgroundColor($r('app.color.chat_user_bg'))
    .accessibilityGroup(true)
    .accessibilityText($r('app.string.a11y_end'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
    .onClick(() => {
      this.onEnd();
    })
  }

  @Builder
  typeButton() {
    Row() {
      Text($r('app.string.agent_type'))
        .fontSize($r('app.float.font_button'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
    }
    .width($r('app.float.dock_side'))
    .height($r('app.float.dock_side'))
    .justifyContent(FlexAlign.Center)
    .borderRadius(30)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .accessibilityGroup(true)
    .accessibilityText($r('app.string.a11y_keyboard'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
    .onClick(() => {
      this.onKeyboard();
    })
  }

  @Builder
  orb() {
    Stack() {
      SilkOrb({ dim: ORB, phase: this.phase, level: this.level, muted: this.muted })
    }
    .width(ORB)
    .height(ORB)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.94 })
    .accessibilityGroup(true)
    .accessibilityText(this.orbA11y())
    .onClick(() => {
      this.onOrb();
    })
  }

  build() {
    Column({ space: 4 }) {
        if (Config.DEMO_VOICE_INPUT) {
          SourceBadge({ label: $r('app.string.demo_voice_badge') })
            .margin({ bottom: 4 })
        }
        Row({ space: 8 }) {
          if (this.phase !== 'OFF' && !this.muted) {
            Circle().width(8).height(8).fill(this.userVoice() ? $r('app.color.ink_4') : $r('app.color.brand_accent'))
          }
          Text(this.label)
            .fontSize($r('app.float.font_button'))
            .fontWeight(FontWeight.Bold)
            .fontColor(this.muted ? $r('app.color.ink_3') : $r('app.color.brand_text'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .padding({ left: 20, right: 20 })
        .accessibilityGroup(true)
        if (this.hint() !== undefined) {
          Text(this.hint())
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.ink_3'))
        }
        Row() {
          if (this.active) {
            if (this.recording) {
              this.sideIcon($r('app.media.ic_close'), $r('app.string.a11y_end'), () => {
                this.onEnd();
              })
            } else {
              this.endButton()
            }
          } else {
            this.sideIcon($r('app.media.ic_scan'), $r('app.string.a11y_camera'), () => {
              this.onScan();
            })
          }
          this.orb()
          this.typeButton()
        }
        .width('100%')
        .height(DOCK_H)
        .justifyContent(FlexAlign.SpaceEvenly)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 24, right: 24 })
        .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .padding({ top: 4, bottom: 8 })
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
