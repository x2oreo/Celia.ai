/**
 * Watch tokens: the phone's dark mode on true black (docs/design/DESIGN.md §2.3 and §7). Screens use these names,
 * never a hex.
 */
export class Theme {
  // Neutrals
  static readonly BG: string = '#000000';
  static readonly RING_TRACK: string = '#1A1614';
  static readonly SURFACE: string = '#1F1A17';
  static readonly BUTTON: string = '#2A2421';
  static readonly BORDER: string = '#332C28';
  static readonly TEXT: string = '#F5F0EC';
  static readonly TEXT_2: string = '#B8AEA8';
  static readonly TEXT_3: string = '#8A817B';
  static readonly ON_LIGHT: string = '#1F1A17';
  static readonly TRANSPARENT: string = '#00000000';

  // Brand and zones
  static readonly BRAND: string = '#F26B6F';
  static readonly BRAND_SOFT: string = '#66F26B6F';
  static readonly CALM: string = '#12B76A';
  static readonly CALM_TINT: string = '#0B2A1C';
  static readonly ELEVATED: string = '#FDB022';
  static readonly ELEVATED_TINT: string = '#33240A';
  static readonly ALERT: string = '#F04438';
  static readonly ALERT_TINT: string = '#33100D';

  // Risk solids (§3), for verdict shapes
  static readonly RISK_KNOWN: string = '#D92D20';
  static readonly RISK_POSSIBLE: string = '#F79009';
  static readonly RISK_CONDITIONAL: string = '#EAAA08';
  static readonly RISK_UNKNOWN: string = '#667085';
  // Verdict words on black (the §3 text colours are for light tints)
  static readonly RISK_KNOWN_TEXT: string = '#F97066';
  static readonly RISK_POSSIBLE_TEXT: string = '#FDB022';
  static readonly RISK_CONDITIONAL_TEXT: string = '#FAC515';

  // Charts
  static readonly CHART_BAR: string = '#4A423D';

  // Type (fp)
  static readonly HERO: number = 64;
  static readonly NUMBER: number = 34;
  static readonly CODE: number = 40;
  static readonly TITLE: number = 17;
  static readonly BODY: number = 14;
  static readonly SMALL: number = 12;
  static readonly CAPS: number = 11;
  static readonly MICRO: number = 9;

  // Layout (vp)
  static readonly RING_STROKE: number = 8;
  /** Gap between the screen edge and the bezel ring. */
  static readonly RING_INSET: number = 6;
  static readonly PILL_HEIGHT: number = 40;
  static readonly CHIP_HEIGHT: number = 22;
  static readonly LIST_WIDTH: number = 184;
}
