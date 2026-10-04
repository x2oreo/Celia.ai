// Risk shapes (DESIGN §3): octagon + ✕, triangle + !, diamond + !, circle + ✓, dashed circle + ?.
// Same geometry as the landing page's SVG symbols.
import React from 'react';
import { color, risk, type RiskLevel } from '../theme/tokens';

export const RiskShape: React.FC<{ level: RiskLevel; dim: number; badge?: number }> = ({ level, dim, badge = 1 }) => {
  const s = risk[level];
  const glyph = color.white;
  // Badge settle: the glyph fades and scales from 0.85 so the shape lands calmly (no bounce).
  const g = { opacity: badge, transform: `scale(${0.85 + 0.15 * badge})`, transformOrigin: '12px 12px' };
  return (
    <svg width={dim} height={dim} viewBox="0 0 24 24" style={{ flex: 'none', display: 'block' }}>
      {level === 'KNOWN' && (
        <>
          <path d="M8 2h8l6 6v8l-6 6H8l-6-6V8z" fill={s.solid} />
          <path d="M8.5 8.5l7 7m0-7l-7 7" stroke={glyph} strokeWidth={2.4} strokeLinecap="round" style={g} />
        </>
      )}
      {level === 'POSSIBLE' && (
        <>
          <path d="M12 2.5l10.5 18.5H1.5z" fill={s.solid} />
          <g style={g}>
            <path d="M12 9v5.5" stroke={glyph} strokeWidth={2.4} strokeLinecap="round" />
            <circle cx={12} cy={17.8} r={1.4} fill={glyph} />
          </g>
        </>
      )}
      {level === 'CONDITIONAL' && (
        <>
          <path d="M12 1.5L22.5 12 12 22.5 1.5 12z" fill={s.solid} />
          <g style={g}>
            <path d="M12 7.5v5.5" stroke={glyph} strokeWidth={2.4} strokeLinecap="round" />
            <circle cx={12} cy={16.3} r={1.4} fill={glyph} />
          </g>
        </>
      )}
      {level === 'NOT_LISTED' && (
        <>
          <circle cx={12} cy={12} r={10.5} fill={s.solid} />
          <path
            d="M7 12.4l3.2 3.2L17 8.8"
            stroke={glyph}
            strokeWidth={2.4}
            fill="none"
            strokeLinecap="round"
            strokeLinejoin="round"
            style={g}
          />
        </>
      )}
      {level === 'UNKNOWN' && (
        <>
          <circle cx={12} cy={12} r={9.5} fill="none" stroke={s.solid} strokeWidth={2.2} strokeDasharray="3 2.6" />
          <g style={g}>
            <path
              d="M9.6 9.4a2.5 2.5 0 114 2c-.9.6-1.6 1.1-1.6 2.3"
              stroke={s.solid}
              strokeWidth={2}
              fill="none"
              strokeLinecap="round"
            />
            <circle cx={12} cy={17} r={1.2} fill={s.solid} />
          </g>
        </>
      )}
    </svg>
  );
};
