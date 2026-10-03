// Voice stage: the orb and what it is doing (DESIGN.md §6.6a). Full size until something is said, then it steps back
// above the conversation. The page owns the voice state and decides what a tap on the orb does.

import { Config } from '../../common/Config';
import { VoicePhase } from '../../voice/RealtimeSession';
import { SourceBadge } from '../Common';
import { VoiceOrb } from '../VoiceOrb';

const ORB_DIM: number = 168;
const ORB_DIM_COMPACT: number = 84;
const STAGE_OPEN: number = 264;      // orb at full size, nothing said yet
const STAGE_COMPACT: number = 124;   // orb at half size above the conversation
const STAGE_MS: number = 320;

@ComponentV2
export struct VoiceStage {
  @Param phase: VoicePhase = 'OFF';
  @Param level: number = 0;
  @Param muted: boolean = false;
  @Param compact: boolean = false;     // a thread exists: the orb steps back
  @Param label: ResourceStr = '';
  @Event onOrbTap: () => void = () => {
  };

  build() {
    Column() {
      Stack() {
        VoiceOrb({
          dim: this.compact ? ORB_DIM_COMPACT : ORB_DIM,
          phase: this.phase,
          level: this.level,
          muted: this.muted
        })
      }
      .width('100%')
      .height(this.compact ? STAGE_COMPACT : STAGE_OPEN)
      .animation({ duration: STAGE_MS, curve: Curve.EaseInOut })
      .accessibilityText($r('app.string.a11y_orb'))
      .onClick(() => {
        this.onOrbTap();
      })

      Text(this.label)
        .fontSize(this.compact ? $r('app.float.font_badge') : $r('app.float.font_title_3'))
        .fontWeight(FontWeight.Bold)
        .fontColor(this.compact ? $r('app.color.ink_3') : $r('app.color.ink'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 20, right: 20 })

      if (Config.DEMO_VOICE_INPUT) {
        SourceBadge({ label: $r('app.string.demo_voice_badge') })
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .padding({ bottom: 12 })
  }
}
