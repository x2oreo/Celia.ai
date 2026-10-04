// Every colour, size and type style the film uses. Values are copied from
// app/entry/src/main/resources/base/element/{color,float}.json and docs/design/DESIGN.md (§2–§5, §7, §10.2b).
// No other file may contain a hex value.

export const color = {
  // Brand and neutrals (DESIGN §2.1)
  bg: '#F8F5F2',
  surface: '#FFFFFF',
  surfaceAlt: '#F3EFEB',
  border: '#ECE6E1',
  borderStrong: '#D9D1CA',
  divider: '#F1ECE8',
  ink: '#1F1A17',
  ink2: '#3D3530',
  ink3: '#6B625C',
  ink4: '#8A817B',
  tabInactive: '#7A716B',
  brand: '#E5484D',
  brandText: '#C7353A',
  brandTint: '#FDECEC',
  onBrand: '#FFFFFF',
  danger: '#D92D20',
  statusOfflineBg: '#EFEAE6',
  statusOfflineText: '#4A423D',

  // Silk orb, palette "Dawn" (DESIGN §6.6, color.json orb_*, SilkOrb.ets)
  orbLight: '#FFCEB0',
  orbMid: '#F27470',
  orbDark: '#D4609C',
  orbBlobA: '#FFDCAA',
  orbBlobB: '#C460B2',
  orbBlobC: '#FF8C76',
  orbBand: '#FFF6F0',
  orbSheen: 'rgba(255, 255, 255, 0.55)',
  orbSheenClear: 'rgba(255, 255, 255, 0)',
  orbGlow: 'rgba(242, 116, 112, 0.30)',
  orbGlowClear: 'rgba(242, 116, 112, 0)',
  orbGlowUser: 'rgba(138, 129, 123, 0.20)',
  orbGlowUserClear: 'rgba(138, 129, 123, 0)',
  bgClear: 'rgba(248, 245, 242, 0)',

  // Scan surface (color.json scan_*)
  scanBg: '#14100F',
  scanFrame: '#2A2421',
  scanText: '#D6CCC6',

  // Warm dark from DESIGN §2.2 / landing §10.2b
  night: '#120E0D',
  night2: '#1A1514',
  nightLine: 'rgba(255, 240, 232, 0.09)',
  nightInk: '#F5F0EC',
  nightInk2: '#B8AEA8',
  nightInk3: '#8C817B',

  // Watch v2: the phone's dark mode on true black (DESIGN §2.3, watch Theme.ets)
  black: '#000000',
  ringTrack: '#1A1614',
  watchSurface: '#1F1A17',
  watchButton: '#2A2421',
  watchBorder: '#332C28',
  watchText: '#F5F0EC',
  watchText2: '#B8AEA8',
  watchText3: '#8A817B',
  watchBrand: '#F26B6F',
  calm: '#12B76A',
  calmTint: '#0B2A1C',
  elevated: '#FDB022',
  elevatedTint: '#33240A',
  alert: '#F04438',
  alertTint: '#33100D',
  chartBar: '#4A423D',
  riskKnownTextDark: '#F97066',
  watchBezel: '#1C1A19',
  watchBezelEdge: '#2E2A28',
  // Kept names used by older parts
  watchMuted: '#8A817B',
  watchChip: '#1F1A17',
  watchChipText: '#F5F0EC',
  watchUnit: '#B8AEA8',

  // Always-light emergency card (color.json card_fixed_*)
  cardBg: '#FFFFFF',
  cardInk: '#1F1A17',
  cardInk2: '#3D3530',
  cardInk3: '#6B625C',
  cardBorder: '#ECE6E1',
  cardAlert: '#B42318',
  cardAlertTint: '#FEE4E2',
  cardAlertBorder: '#F4B5AF',

  // Device hardware, from site/assets/landing.css (.phone / .watch)
  phoneBezelLight: '#3A322E',
  phoneBezelMid: '#1F1A17',
  phoneBezelDark: '#0E0B0A',

  // Generic medicine box (no real brand's trade dress): neutral white carton with a quiet teal band.
  boxFace: '#FBFAF8',
  boxSide: '#E6E1DC',
  boxBand: '#2F6F73',
  boxInk: '#23302F',
  barcode: '#111111',

  // Film-only light: a warm key light on dark (cold open), never a brand wash
  keyLight: 'rgba(255, 246, 240, 0.12)',
  keyLightClear: 'rgba(255, 246, 240, 0)',
  dotIdle: 'rgba(245, 240, 236, 0.38)',
  dotLost: 'rgba(245, 240, 236, 0.05)',

  // Scrim and shadows (DESIGN §5.3)
  scrim: 'rgba(31, 26, 23, 0.45)',
  white: '#FFFFFF',
} as const;

export type RiskLevel = 'KNOWN' | 'POSSIBLE' | 'CONDITIONAL' | 'NOT_LISTED' | 'UNKNOWN';

export interface RiskStyle {
  label: string;
  title: string;
  subtitle: string;
  solid: string;
  tint: string;
  text: string;
  border: string;
}

// Risk language (DESIGN §3). Fixed: colour + shape + word.
export const risk: Record<RiskLevel, RiskStyle> = {
  KNOWN: {
    label: 'KNOWN RISK',
    title: 'Known risk',
    subtitle: 'Can affect heart rhythm',
    solid: '#D92D20',
    tint: '#FEE4E2',
    text: '#B42318',
    border: '#F4B5AF',
  },
  POSSIBLE: {
    label: 'POSSIBLE RISK',
    title: 'Possible risk',
    subtitle: 'Check with your doctor',
    solid: '#F79009',
    tint: '#FEF0C7',
    text: '#93370D',
    border: '#FEC84B',
  },
  CONDITIONAL: {
    label: 'CONDITIONAL',
    title: 'Conditional',
    subtitle: 'Risky only in some situations',
    solid: '#EAAA08',
    tint: '#FEF7C3',
    text: '#854A0E',
    border: '#FDE272',
  },
  NOT_LISTED: {
    label: 'NOT LISTED',
    title: 'Not listed',
    subtitle: "Not listed doesn't guarantee safety",
    solid: '#12B76A',
    tint: '#DCFAE6',
    text: '#067647',
    border: '#A6EFC4',
  },
  UNKNOWN: {
    label: 'UNKNOWN',
    title: 'Unknown',
    subtitle: "Couldn't identify",
    solid: '#667085',
    tint: '#EAECF0',
    text: '#475467',
    border: '#D0D5DD',
  },
};

export const knownSubtitle = '#912018';

// Spacing (DESIGN §5.1), vp
export const space = { xs: 4, s: 8, sm: 12, m: 16, screen: 20, l: 24, xl: 32 } as const;

// Radius (DESIGN §5.2), vp
export const radius = { xs: 6, s: 12, btn: 14, m: 16, ml: 20, l: 24, sheet: 28 } as const;

// Sizes (float.json)
export const size = {
  buttonHeight: 48,
  buttonHeightSheet: 52,
  buttonHeightL: 64,
  chipHeight: 44,
  tabBarHeight: 64,
  avatarS: 28,
  avatarM: 40,
  avatarL: 96,
  avatarTab: 56,
  orbDock: 104,
  dockSideV2: 60,
  avatarHero: 168,
  dockSide: 52,
  dockMain: 72,
  phoneW: 360,
  phoneH: 780,
  watch: 466,
} as const;

export const fontFamily = {
  sans: '"Figtree", "HarmonyOS Sans", -apple-system, system-ui, sans-serif',
  mono: '"JetBrains Mono", ui-monospace, Menlo, monospace',
} as const;

export interface TypeStyle {
  fontSize: number;
  lineHeight: string;
  fontWeight: number;
  letterSpacing?: string;
}

// Type scale (DESIGN §4), fp
export const type = {
  display: { fontSize: 60, lineHeight: '60px', fontWeight: 800, letterSpacing: '-0.02em' },
  title1: { fontSize: 28, lineHeight: '32px', fontWeight: 800, letterSpacing: '-0.01em' },
  title2: { fontSize: 24, lineHeight: '30px', fontWeight: 700 },
  title3: { fontSize: 20, lineHeight: '26px', fontWeight: 700 },
  headline: { fontSize: 17, lineHeight: '22px', fontWeight: 700 },
  body: { fontSize: 16, lineHeight: '23px', fontWeight: 500 },
  button: { fontSize: 15, lineHeight: '20px', fontWeight: 700 },
  bodySm: { fontSize: 14, lineHeight: '20px', fontWeight: 500 },
  label: { fontSize: 12, lineHeight: '16px', fontWeight: 700, letterSpacing: '0.04em' },
  caption: { fontSize: 11, lineHeight: '15px', fontWeight: 500 },
  mono: { fontSize: 9, lineHeight: '12px', fontWeight: 700, letterSpacing: '0.04em' },
} satisfies Record<string, TypeStyle>;

// Film-scale type: DESIGN title-1 (800) scaled up for 1080p, the landing page's h-display rhythm.
export const film = {
  headline: { fontSize: 76, lineHeight: '80px', fontWeight: 800, letterSpacing: '-0.035em' },
  headlineTall: { fontSize: 84, lineHeight: '88px', fontWeight: 800, letterSpacing: '-0.035em' },
  hook: { fontSize: 92, lineHeight: '96px', fontWeight: 800, letterSpacing: '-0.04em' },
  wordmark: { fontSize: 132, lineHeight: '132px', fontWeight: 800, letterSpacing: '-0.045em' },
  sub: { fontSize: 30, lineHeight: '40px', fontWeight: 500, letterSpacing: '-0.005em' },
  subTall: { fontSize: 40, lineHeight: '52px', fontWeight: 500, letterSpacing: '-0.005em' },
  kicker: { fontSize: 20, lineHeight: '24px', fontWeight: 700, letterSpacing: '0.12em' },
  kickerTall: { fontSize: 26, lineHeight: '30px', fontWeight: 700, letterSpacing: '0.12em' },
  caption: { fontSize: 18, lineHeight: '24px', fontWeight: 500 },
  captionTall: { fontSize: 24, lineHeight: '32px', fontWeight: 500 },
} satisfies Record<string, TypeStyle>;

// Elevation (DESIGN §5.3)
export const shadow = {
  e1: '0 8px 24px rgba(31, 26, 23, 0.14)',
  float: '0 40px 80px -24px rgba(31, 26, 23, 0.28), 0 8px 24px rgba(31, 26, 23, 0.14)',
  floatDark: '0 40px 80px -24px rgba(0, 0, 0, 0.6), 0 8px 24px rgba(0, 0, 0, 0.3)',
} as const;

export const orbGradient = `radial-gradient(circle at 36% 30%, ${color.orbLight} 0%, ${color.orbMid} 60%, ${color.orbDark} 100%)`;
export const orbSheenGradient = `radial-gradient(circle at 30% 24%, ${color.orbSheen} 0%, ${color.orbSheenClear} 42%)`;

/** Brand coral at an alpha, for washes and glows. */
export const brandAlpha = (a: number): string => `rgba(229, 72, 77, ${a})`;
/** Ink at an alpha. */
export const inkAlpha = (a: number): string => `rgba(31, 26, 23, ${a})`;
