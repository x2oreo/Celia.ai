// Device frames. Content is laid out at native size (phone 360 × 780 vp, watch 466 × 466 px) and the frame is
// scaled as a whole, so everything inside matches the app spec 1:1 (same approach as site/assets/landing.css).
import React from 'react';
import { color, fontFamily, inkAlpha, radius, shadow, size } from '../theme/tokens';

const BEZEL = 12;
const PHONE_OUTER_W = size.phoneW + BEZEL * 2;
const PHONE_OUTER_H = size.phoneH + BEZEL * 2;

export const phoneOuter = { w: PHONE_OUTER_W, h: PHONE_OUTER_H };

export const StatusBar: React.FC<{ time?: string; right?: string; dark?: boolean }> = ({
  time = '9:41',
  right = '5G · 82%',
  dark = false,
}) => (
  <div
    style={{
      display: 'flex',
      justifyContent: 'space-between',
      padding: '18px 28px 6px',
      fontSize: 14,
      fontWeight: 700,
      color: dark ? color.white : color.ink,
      flex: 'none',
      fontVariantNumeric: 'tabular-nums',
    }}
  >
    <span>{time}</span>
    <span>{right}</span>
  </div>
);

export const PhoneFrame: React.FC<{
  scale: number;
  children: React.ReactNode;
  screenBg?: string;
  dark?: boolean;
  style?: React.CSSProperties;
}> = ({ scale, children, screenBg = color.bg, dark = false, style }) => (
  <div style={{ width: PHONE_OUTER_W * scale, height: PHONE_OUTER_H * scale, flex: 'none', ...style }}>
    <div
      style={{
        width: PHONE_OUTER_W,
        height: PHONE_OUTER_H,
        padding: BEZEL,
        borderRadius: 58,
        background: `linear-gradient(145deg, ${color.phoneBezelLight} 0%, ${color.phoneBezelMid} 40%, ${color.phoneBezelDark} 100%)`,
        boxShadow: dark ? shadow.floatDark : shadow.float,
        transform: `scale(${scale})`,
        transformOrigin: 'top left',
        boxSizing: 'border-box',
      }}
    >
      <div
        style={{
          position: 'relative',
          width: size.phoneW,
          height: size.phoneH,
          borderRadius: 46,
          overflow: 'hidden',
          background: screenBg,
          display: 'flex',
          flexDirection: 'column',
          fontFamily: fontFamily.sans,
          color: color.ink,
          fontSize: 16,
          lineHeight: '23px',
        }}
      >
        {children}
      </div>
    </div>
  </div>
);

export const WatchFrame: React.FC<{ scale: number; children: React.ReactNode; style?: React.CSSProperties }> = ({
  scale,
  children,
  style,
}) => (
  <div style={{ width: size.watch * scale, height: size.watch * scale, flex: 'none', ...style }}>
    <div
      style={{
        position: 'relative',
        width: size.watch,
        height: size.watch,
        borderRadius: '50%',
        background: color.black,
        boxShadow: `0 0 0 14px ${color.watchBezel}, 0 0 0 15px ${color.watchBezelEdge}, ${shadow.floatDark}`,
        transform: `scale(${scale})`,
        transformOrigin: 'top left',
        overflow: 'hidden',
        color: color.white,
        fontFamily: fontFamily.sans,
        fontVariantNumeric: 'tabular-nums',
      }}
    >
      {children}
    </div>
  </div>
);

/** Bottom sheet surface inside the phone (radius 28 top corners, E1, grabber). */
export const Sheet: React.FC<{ children: React.ReactNode; style?: React.CSSProperties; bg?: string }> = ({
  children,
  style,
  bg = color.bg,
}) => (
  <div
    style={{
      position: 'absolute',
      left: 0,
      right: 0,
      bottom: 0,
      background: bg,
      borderRadius: `${radius.sheet}px ${radius.sheet}px 0 0`,
      boxShadow: `0 -8px 24px ${inkAlpha(0.14)}`,
      padding: '10px 20px 24px',
      display: 'flex',
      flexDirection: 'column',
      ...style,
    }}
  >
    <div style={{ width: 36, height: 4, borderRadius: 2, background: color.borderStrong, alignSelf: 'center', marginBottom: 14 }} />
    {children}
  </div>
);
