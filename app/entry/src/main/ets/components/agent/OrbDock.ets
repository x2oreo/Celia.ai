// The bottom of the agent stage in voice mode (DESIGN.md §10.1a, screens 02 and 03): the orb sits where a mic
// button would, with one round button on each side. Slow rings leave the orb while someone talks, and OrbLight
// (below) glows behind the lower half of the stage and follows the voice, so the screen feels alive without
// anything that reads as a pulse or a trace.
//   idle       scan · orb (tap: talk) · type
//   live       End  · orb (tap: mute / unmute) · type
//   recording  cancel · orb (tap: send) · type      (tap-to-talk, when live voice is unavailable)
// The dock only reports taps; the page decides what they do. The state is always written above the orb.

import { Config } from '../../common/Config';
import { Motion } from '../../common/Motion';
import { VoicePhase } from '../../voice/RealtimeSession';
import { SourceBadge } from '../Common';
import { SilkOrb } from '../SilkOrb';

const ORB: number = 104;
const DOCK_H: number = 136;        // orb row
const LIGHT_H: number = 460;       // how far the ambient light reaches up from the bottom edge
const LEVEL_MS: number = 160;
const FADE_MS: number = 320;
const RING_MS: number = 2600;

// One slow ring leaving the orb. A component of its own so the loop restarts each time the dock goes live.
@ComponentV2
struct OrbRing {
  @Param delay: number = 0;
  @Param user: boolean = false;    // neutral for the user's voice, warm for the agent's
  @Local out: boolean = false;

  build() {
    Circle()
      .width(ORB)
      .height(ORB)
      .fillOpacity(0)
      .stroke(this.user ? $r('app.color.ink_4') : $r('app.color.orb_mid'))
      .strokeWidth(1.5)
      .animation({ duration: FADE_MS, curve: Curve.EaseInOut })
      .scale({ x: this.out ? 2.6 : 1, y: this.out ? 2.6 : 1 })
      .opacity(this.out ? 0 : 0.35)
      .animation({ duration: RING_MS, delay: this.delay, curve: Curve.EaseOut, iterations: -1 })
      .onAppear(() => {
        this.out = true;
      })
  }
}

// Light rising from the orb: a wide radial glow behind the whole lower half of the stage, warm for the agent and
// neutral while the user is heard. The page puts it behind its content, so it takes no room in the layout.
@ComponentV2
export struct OrbLight {
  @Param phase: VoicePhase = 'OFF';
  @Param level: number = 0;
  @Param muted: boolean = false;

  private userVoice(): boolean {
    return this.phase === 'HEARING' || this.phase === 'LISTENING';
  }

  // 0..1: how much the light opens. Idle keeps a faint glow so the orb never sits on a dead surface.
  private glow(): number {
    if (this.muted) {
      return 0.15;
    }
    if (this.phase === 'OFF') {
      return 0.4;
    }
    if (this.phase === 'HEARING' || this.phase === 'SPEAKING') {
      return 0.7 + 0.3 * Math.max(0.25, Math.min(1, this.level));
    }
    return 0.6;
  }

  build() {
    Stack() {
      Row()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: ['50%', '78%'],
          radius: '70%',
          colors: [[$r('app.color.orb_glow'), 0], [$r('app.color.orb_glow_clear'), 1]]
        })
        .opacity(this.userVoice() ? 0 : 1)
        .animation({ duration: FADE_MS, curve: Curve.EaseInOut })
      Row()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: ['50%', '78%'],
          radius: '70%',
          colors: [[$r('app.color.orb_glow_user'), 0], [$r('app.color.orb_glow_user_clear'), 1]]
        })
        .opacity(this.userVoice() ? 1 : 0)
        .animation({ duration: FADE_MS, curve: Curve.EaseInOut })
    }
    .width('100%')
    .height(LIGHT_H)
    .opacity(this.glow())
    .animation({ duration: LEVEL_MS, curve: Curve.EaseOut })
    .hitTestBehavior(HitTestMode.None)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
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
  @Local reduced: boolean = Motion.reduced;
  private offMotion: () => void = () => {
  };

  aboutToAppear(): void {
    this.offMotion = Motion.onChange((on: boolean) => {
      this.reduced = on;
    });
  }

  aboutToDisappear(): void {
    this.offMotion();
  }

  private userVoice(): boolean {
    return this.phase === 'HEARING' || this.phase === 'LISTENING';
  }

  private voiced(): boolean {
    return !this.muted && (this.phase === 'HEARING' || this.phase === 'SPEAKING');
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
      if (this.voiced() && !this.reduced) {
        OrbRing({ delay: 0, user: this.userVoice() })
        OrbRing({ delay: RING_MS / 2, user: this.userVoice() })
      }
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
    }
    .width('100%')
    .padding({ top: 4, bottom: 8 })
  }
}
