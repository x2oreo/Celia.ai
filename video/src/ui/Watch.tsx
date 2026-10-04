// Watch v2 faces (DESIGN §7, docs/design/v2-watches 1.1, 1.2, 7, 13.1), rebuilt from watch/…/components/Parts.ets,
// HeartPage.ets, AlertScreen.ets and SosScreen.ets. 466 px = 233 vp, so every vp size below is doubled.
// True black, warm neutrals. Heart rate only, never QT, never a trace.
import React from 'react';
import { watch as copy } from '../copy/script';
import { color, fontFamily, size } from '../theme/tokens';
import { Icon } from '../primitives/Icon';

export type WatchZone = 'CALM' | 'ELEVATED' | 'ALERT';

const VP = 2;
const D = size.watch;
const STROKE = 8 * VP;
const R = D / 2 - 6 * VP - STROKE / 2;

export const zoneColor = (zone: WatchZone): string =>
  zone === 'CALM' ? color.calm : zone === 'ELEVATED' ? color.elevated : color.alert;

const arcPath = (fromDeg: number, toDeg: number): string => {
  // Degrees clockwise from 12 o'clock.
  const p = (deg: number): string => {
    const a = ((deg - 90) * Math.PI) / 180;
    return `${D / 2 + R * Math.cos(a)} ${D / 2 + R * Math.sin(a)}`;
  };
  const large = toDeg - fromDeg > 180 ? 1 : 0;
  return `M ${p(fromDeg)} A ${R} ${R} 0 ${large} 1 ${p(toDeg)}`;
};

/** Bezel in gauge mode: a 290° arc open at the bottom, filled from your min (left) to your max (right). */
export const GaugeBezel: React.FC<{ fill: number; ringColor: string }> = ({ fill, ringColor }) => {
  const start = 180 + 35;
  const span = 290;
  const f = Math.max(0.01, Math.min(1, fill));
  return (
    <svg width={D} height={D} style={{ position: 'absolute', inset: 0 }}>
      <path d={arcPath(start, start + span)} fill="none" stroke={color.ringTrack} strokeWidth={STROKE} strokeLinecap="round" />
      <path d={arcPath(start, start + span * f)} fill="none" stroke={ringColor} strokeWidth={STROKE} strokeLinecap="round" />
    </svg>
  );
};

/** Bezel in ring mode: a full circle, or a countdown draining clockwise from 12 o'clock. */
export const RingBezel: React.FC<{ ringColor: string; percent?: number }> = ({ ringColor, percent = 100 }) => {
  const c = 2 * Math.PI * R;
  return (
    <svg width={D} height={D} style={{ position: 'absolute', inset: 0, transform: 'rotate(-90deg)' }}>
      <circle cx={D / 2} cy={D / 2} r={R} fill="none" stroke={color.ringTrack} strokeWidth={STROKE} />
      <circle cx={D / 2} cy={D / 2} r={R} fill="none" stroke={ringColor} strokeWidth={STROKE} strokeLinecap="round" strokeDasharray={`${(percent / 100) * c} ${c}`} />
    </svg>
  );
};

/** Status mark (16 vp): filled dot = good, triangle = near / above. Drawn, not a font glyph. */
const StatusMark: React.FC<{ kind: 'dot' | 'up'; markColor: string }> = ({ kind, markColor }) => (
  <svg width={16 * VP * 0.8} height={16 * VP * 0.8} viewBox="0 0 16 16" style={{ flex: 'none' }}>
    {kind === 'dot' ? <circle cx={8} cy={8} r={6} fill={markColor} /> : <path d="M8 2 L15 14 L1 14 Z" fill={markColor} />}
  </svg>
);

const Chip: React.FC<{ text: string }> = ({ text }) => (
  <span style={{ height: 22 * VP, padding: `0 ${8 * VP}px`, borderRadius: 11 * VP, background: color.watchSurface, color: color.watchText, fontSize: 12 * VP, fontWeight: 700, display: 'inline-flex', alignItems: 'center' }}>
    {text}
  </span>
);

const OutlinedBadge: React.FC<{ text: string }> = ({ text }) => (
  <span style={{ fontFamily: fontFamily.mono, fontSize: 9 * VP, fontWeight: 700, letterSpacing: '0.04em', color: color.watchText2, border: `${VP}px solid ${color.watchText3}`, borderRadius: 4 * VP, padding: `${2 * VP}px ${4 * VP}px` }}>
    {text}
  </span>
);

const Pill: React.FC<{ text: string; fill: string; ink?: string }> = ({ text, fill, ink = color.watchText }) => (
  <span style={{ height: 40 * VP, padding: `0 ${18 * VP}px`, borderRadius: 20 * VP, background: fill, color: ink, fontSize: 14 * VP, fontWeight: 700, display: 'inline-flex', alignItems: 'center' }}>{text}</span>
);

const Face: React.FC<{ children: React.ReactNode; opacity?: number; y?: number }> = ({ children, opacity = 1, y = 0 }) => (
  <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center', opacity, transform: `translateY(${y}px)` }}>
    {children}
  </div>
);

const MIN = 45;
const MAX = 110;

/** Home (1.1 / 1.2) blending into the heart-rate-high alert (7) as `alert` goes 0 → 1. */
export const WatchLive: React.FC<{ bpm: number; alert: number }> = ({ bpm, alert }) => {
  const near = bpm >= MAX * 0.9 && bpm < MAX;
  const above = bpm >= MAX;
  const zone: WatchZone = above ? 'ALERT' : near ? 'ELEVATED' : 'CALM';
  const zc = zoneColor(zone);
  const fill = above ? 1 : (bpm - MIN) / (MAX - MIN);
  return (
    <>
      <div style={{ position: 'absolute', inset: 0, opacity: 1 - alert }}>
        <GaugeBezel fill={fill} ringColor={zc} />
      </div>
      <div style={{ position: 'absolute', inset: 0, opacity: alert }}>
        <RingBezel ringColor={color.alert} />
      </div>
      <Face opacity={1 - alert}>
        <OutlinedBadge text={copy.demo} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 * VP, marginTop: 8 * VP, fontSize: 15 * VP, fontWeight: 700, color: zc }}>
          <StatusMark kind={zone === 'CALM' ? 'dot' : 'up'} markColor={zc} />
          {zone === 'CALM' ? copy.calmLabel : above ? copy.aboveLabel : copy.nearLabel}
        </div>
        <div style={{ fontSize: 64 * VP, lineHeight: 1, fontWeight: 800, letterSpacing: '-0.03em', color: color.watchText, fontVariantNumeric: 'tabular-nums' }}>{Math.round(bpm)}</div>
        <div style={{ fontSize: 12 * VP, color: color.watchText2 }}>bpm</div>
        <div style={{ fontSize: 14 * VP, fontWeight: 600, color: color.watchText, marginTop: 4 * VP }}>{copy.context}</div>
        <div style={{ display: 'flex', gap: 4 * VP, marginTop: 6 * VP }}>
          {copy.chips.map((c) => (
            <Chip key={c} text={c} />
          ))}
        </div>
      </Face>
      <Face opacity={alert} y={(1 - alert) * 10}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 4 * VP, fontSize: 11 * VP, fontWeight: 700, letterSpacing: `${VP}px`, color: color.alert }}>
          <StatusMark kind="up" markColor={color.alert} />
          {copy.alertTitle}
        </div>
        <div style={{ fontSize: 64 * VP, lineHeight: 1.05, fontWeight: 800, letterSpacing: '-0.03em', color: color.alert, fontVariantNumeric: 'tabular-nums' }}>{Math.round(bpm)}</div>
        <div style={{ fontSize: 14 * VP, fontWeight: 600, color: color.watchText }}>{copy.alertSub}</div>
        <div style={{ fontSize: 12 * VP, color: color.watchText2, marginTop: 2 * VP }}>{copy.alertLimit}</div>
        <div style={{ display: 'flex', gap: 6 * VP, marginTop: 10 * VP }}>
          <Pill text={copy.ok} fill={color.watchButton} />
          <Pill text={copy.help} fill={color.alert} />
        </div>
      </Face>
    </>
  );
};

/** SOS sent (13.1): calm ring, check disc, the bystander line as the biggest text on screen. */
export const WatchSosSent: React.FC = () => (
  <>
    <RingBezel ringColor={color.calm} />
    <Face>
      <span style={{ width: 26 * VP, height: 26 * VP, borderRadius: 13 * VP, background: color.calm, display: 'grid', placeItems: 'center', color: color.black }}>
        <Icon name="check" size={16 * VP} />
      </span>
      <div style={{ fontSize: 17 * VP, fontWeight: 700, color: color.watchText, marginTop: 6 * VP }}>{copy.sosSent}</div>
      <div style={{ fontSize: 12 * VP, color: color.watchText2, width: 150 * VP, marginTop: 2 * VP }}>{copy.sosSentSub}</div>
      <div style={{ width: 170 * VP, marginTop: 8 * VP, padding: `${8 * VP}px ${10 * VP}px`, borderRadius: 10 * VP, background: color.alertTint, color: color.watchText, fontSize: 14 * VP, lineHeight: 1.25, fontWeight: 700 }}>
        {copy.bystander}
      </div>
      <div style={{ marginTop: 8 * VP }}>
        <Pill text={copy.done} fill={color.watchButton} />
      </div>
    </Face>
  </>
);
