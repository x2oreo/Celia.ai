// Motion switches (DESIGN.md §8). When `reduced` is true, looping animations drop to static.
// The flag is app-level because ArkTS exposes no reduce-motion query we could verify for API 20.

export class Motion {
  static reduced: boolean = false;
  static readonly BREATH_MS: number = 2000;   // one half of the 4 s breathing cycle
  static readonly REVEAL_MS: number = 240;
  static readonly BEAT_MS: number = 1100;
}
