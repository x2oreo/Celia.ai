// The hero orb of the voice conversation (DESIGN.md §6.6a): the silk orb at stage size. The orb itself carries the
// state (see components/SilkOrb.ets); the caller always shows the state in words next to it.

import { VoicePhase } from '../voice/RealtimeSession';
import { SilkOrb } from './SilkOrb';

@ComponentV2
export struct VoiceOrb {
  @Param dim: number = 168;
  @Param phase: VoicePhase = 'OFF';
  @Param level: number = 0;       // 0..1 loudness of whoever is talking
  @Param muted: boolean = false;

  build() {
    SilkOrb({ dim: this.dim, phase: this.phase, level: this.level, muted: this.muted })
  }
}
