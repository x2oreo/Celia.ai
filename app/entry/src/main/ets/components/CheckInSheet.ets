// Heart-rate check-in (design B3): a sheet over whatever the user is looking at. The agent asks, the user answers
// with one tap. Escalation is offered but never forced; no answer falls back to the SOS countdown (AgentCore).

import { AgentAvatar } from './AgentAvatar';
import { InkButton, PrimaryButton, RiskShape, SecondaryButton } from './Common';

@ComponentV2
export struct CheckInSheet {
  @Param message: string = '';
  @Param bpm: number = 0;
  @Param time: string = '';
  @Param simulated: boolean = true;
  @Event onFine: () => void = () => {
  };
  @Event onUnwell: () => void = () => {
  };
  @Event onHelp: () => void = () => {
  };

  private chipLabel(): Resource {
    if (this.bpm <= 0) {
      return $r('app.string.checkin_alert');
    }
    return this.bpm < 50 ? $r('app.string.checkin_low') : $r('app.string.checkin_high');
  }

  build() {
    Column({ space: 16 }) {
      Row({ space: 12 }) {
        AgentAvatar({ dim: 40 })
        Column({ space: 2 }) {
          Text($r('app.string.agent_name'))
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          Row({ space: 4 }) {
            Text(`${this.time} ·`)
              .fontSize($r('app.float.font_badge'))
              .fontColor($r('app.color.ink_3'))
            Text(this.simulated ? $r('app.string.checkin_from_sim') : $r('app.string.checkin_from_watch'))
              .fontSize($r('app.float.font_badge'))
              .fontColor($r('app.color.ink_3'))
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      // Out-of-range heart rate: Possible-risk tint + triangle + words, never colour alone.
      Row({ space: 12 }) {
        RiskShape({ risk: 'POSSIBLE_RISK', dim: 32 })
          .accessibilityLevel('no-hide-descendants')
        Column() {
          Text(this.bpm > 0 ? $r('app.string.heart_bpm_value', this.bpm) : '-')
            .fontSize($r('app.float.font_title'))
            .fontWeight(800)
            .fontColor($r('app.color.risk_possible_text'))
          Text(this.chipLabel())
            .fontSize($r('app.float.font_small'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.risk_possible_text'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor($r('app.color.risk_possible_tint'))
      .borderRadius($r('app.float.radius_m'))
      .accessibilityGroup(true)

      Text(this.message)
        .fontSize(this.message.length > 90 ? $r('app.float.font_headline') : $r('app.float.font_title_3'))
        .fontWeight(FontWeight.Bold)
        .lineHeight(this.message.length > 90 ? 24 : 26)
        .fontColor($r('app.color.ink'))
        .width('100%')

      Column({ space: 10 }) {
        SecondaryButton({ label: $r('app.string.checkin_fine'), large: true, onTap: () => this.onFine() })
        InkButton({ label: $r('app.string.checkin_dizzy'), large: true, onTap: () => this.onUnwell() })
        PrimaryButton({ label: $r('app.string.checkin_help'), danger: true, large: true, onTap: () => this.onHelp() })
      }
      .width('100%')

      Text($r('app.string.checkin_note'))
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.ink_3'))
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 8, bottom: 24 })
  }
}
