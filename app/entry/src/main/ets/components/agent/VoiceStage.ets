// Voice stage: the orb and what it is doing (DESIGN.md §6.6a, §10.1a screens 02 and 03). 168 until something is
// said, 120 above the captions, 84 above the full thread. While a session is live and nothing has been said it takes
// the whole height (`full`). The page owns the voice state and decides what a tap on the orb does.

import { Config } from '../../common/Config';
import { VoicePhase } from '../../voice/RealtimeSession';
import { SourceBadge } from '../Common';
import { VoiceOrb } from '../VoiceOrb';

const STAGE_MS: number = 320;
const ROOM: number = 1.3;   // stage height per orb size: room for the halo

@ComponentV2
export struct VoiceStage {
  @Param phase: VoicePhase = 'OFF';
  @Param level: number = 0;
  @Param muted: boolean = false;
  @Param dim: number = 168;
  @Param full: boolean = false;        // live session, nothing said yet: the stage fills the screen
  @Param label: ResourceStr = '';
  @Event onOrbTap: () => void = () => {
  };

  // Neutral for the user's voice, coral for the agent: the same family as the orb's halo.
  private dotColor(): Resource {
    return this.phase === 'HEARING' || this.phase === 'LISTENING' ? $r('app.color.ink_4') :
      $r('app.color.brand_accent');
  }

  build() {
    Column() {
      Stack() {
        VoiceOrb({ dim: this.dim, phase: this.phase, level: this.level, muted: this.muted })
      }
      .width('100%')
      .height(this.dim * ROOM)
      .animation({ duration: STAGE_MS, curve: Curve.EaseInOut })
      .accessibilityGroup(true)
      .accessibilityText($r('app.string.a11y_orb'))
      .onClick(() => {
        this.onOrbTap();
      })

      Row({ space: 8 }) {
        if (this.phase !== 'OFF' && !this.muted) {
          Circle().width(8).height(8).fill(this.dotColor())
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

      if (Config.DEMO_VOICE_INPUT) {
        SourceBadge({ label: $r('app.string.demo_voice_badge') })
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .height(this.full ? '100%' : 'auto')
    .justifyContent(FlexAlign.Center)
    .padding({ bottom: 8 })
  }
}
