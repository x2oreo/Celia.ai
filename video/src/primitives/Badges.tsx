// Risk badge pill (DESIGN §3) and mono source badge (DESIGN §6.2).
import React from 'react';
import { color, fontFamily, risk, type, type RiskLevel } from '../theme/tokens';
import { RiskShape } from './RiskShape';

export const RiskBadge: React.FC<{ level: RiskLevel; badge?: number; compact?: boolean; title?: boolean }> = ({
  level,
  badge = 1,
  compact = false,
  title = false,
}) => {
  const s = risk[level];
  const h = compact ? 24 : 32;
  return (
    <div
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: compact ? 6 : 8,
        height: h,
        borderRadius: h / 2,
        padding: compact ? '0 10px 0 3px' : '0 12px 0 4px',
        background: s.tint,
        color: s.text,
        fontSize: compact ? 11 : 13,
        fontWeight: 800,
        letterSpacing: '0.03em',
        whiteSpace: 'nowrap',
        flex: 'none',
      }}
    >
      <RiskShape level={level} dim={compact ? 18 : 24} badge={badge} />
      {title ? s.title : s.label}
    </div>
  );
};

export const SourceBadge: React.FC<{ label: string; solid?: boolean; scale?: number; dark?: boolean }> = ({
  label,
  solid = false,
  scale = 1,
  dark = false,
}) => {
  const fg = dark ? color.nightInk : color.ink;
  return (
    <span
      style={{
        display: 'inline-block',
        fontFamily: fontFamily.mono,
        fontSize: type.mono.fontSize * scale,
        lineHeight: `${12 * scale}px`,
        fontWeight: 700,
        letterSpacing: '0.04em',
        borderRadius: 4 * scale,
        padding: `${3 * scale}px ${5 * scale}px`,
        background: solid ? fg : dark ? 'transparent' : color.surface,
        color: solid ? (dark ? color.ink : color.white) : fg,
        border: `${Math.max(1, scale)}px solid ${fg}`,
        whiteSpace: 'nowrap',
      }}
    >
      {label}
    </span>
  );
};
