// Verdict card (DESIGN §6.4), rebuilt from components/VerdictCard.ets. Inline (chat) and sheet sizes.
// Colour, shape and word come only from the fixed `level`, never from text.
import React from 'react';
import { verdict as copy } from '../copy/script';
import { color, knownSubtitle, radius, risk, type, type RiskLevel } from '../theme/tokens';
import { Icon } from '../primitives/Icon';
import { RiskShape } from '../primitives/RiskShape';

export type VerdictVariant = 'INLINE' | 'SHEET';

const InkButton: React.FC<{ label: string; large: boolean; flex?: boolean }> = ({ label, large, flex = true }) => (
  <div
    style={{
      flex: flex ? 1 : 'none',
      height: large ? 52 : 44,
      borderRadius: large ? radius.btn : radius.s,
      background: color.ink,
      color: color.white,
      display: 'grid',
      placeItems: 'center',
      ...type.button,
    }}
  >
    {label}
  </div>
);

const SecondaryButton: React.FC<{ label: string; large: boolean }> = ({ label, large }) => (
  <div
    style={{
      height: large ? 52 : 44,
      padding: '0 18px',
      borderRadius: large ? radius.btn : radius.s,
      border: `1.5px solid ${color.borderStrong}`,
      color: color.ink,
      display: 'grid',
      placeItems: 'center',
      fontSize: 15,
      fontWeight: 600,
      boxSizing: 'border-box',
      whiteSpace: 'nowrap',
    }}
  >
    {label}
  </div>
);

export const VerdictCard: React.FC<{
  level: RiskLevel;
  variant: VerdictVariant;
  name?: string;
  ingredient?: string;
  reason?: string;
  badge?: number;
  traceOpen?: number; // 0..1: how far the "How we know" rows have ticked in
  showTrace?: boolean;
  showExtras?: boolean;
  actionLabel?: string;
}> = ({
  level,
  variant,
  name = copy.name,
  ingredient = copy.ingredient,
  reason = copy.reason,
  badge = 1,
  traceOpen = 0,
  showTrace = variant === 'SHEET',
  showExtras = variant === 'SHEET',
  actionLabel = copy.addToMeds,
}) => {
  const s = risk[level];
  const sheet = variant === 'SHEET';
  const rowsShown = traceOpen * copy.trace.length;

  return (
    <div
      style={{
        width: '100%',
        display: 'flex',
        flexDirection: 'column',
        background: sheet ? 'transparent' : color.surface,
        borderRadius: sheet ? 0 : radius.ml,
        border: sheet ? 'none' : `1.5px solid ${s.border}`,
        overflow: 'hidden',
        boxSizing: 'border-box',
      }}
    >
      {/* Header band: shape + word + subtitle on the risk tint */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 10,
          padding: '12px 14px',
          background: s.tint,
          borderRadius: sheet ? radius.m : 0,
        }}
      >
        <RiskShape level={level} dim={sheet ? 40 : 32} badge={badge} />
        <div style={{ display: 'flex', flexDirection: 'column', gap: 1, opacity: 0.4 + 0.6 * badge }}>
          <span style={{ fontSize: sheet ? 20 : 16, lineHeight: sheet ? '26px' : '21px', fontWeight: 800, color: s.text }}>
            {s.title}
          </span>
          <span style={{ fontSize: sheet ? 14 : 12, lineHeight: sheet ? '19px' : '16px', color: level === 'KNOWN' ? knownSubtitle : s.text }}>
            {s.subtitle}
          </span>
        </div>
      </div>

      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          gap: sheet ? 10 : 6,
          padding: sheet ? '14px 0 0' : '12px 14px',
        }}
      >
        <div style={{ fontSize: sheet ? 20 : 17, lineHeight: sheet ? '26px' : '22px', fontWeight: 700, color: color.ink, display: 'flex', alignItems: 'center', gap: 6 }}>
          {name}
          <Icon name="chevron" size={sheet ? 18 : 15} color={color.ink3} stroke={2} />
          {ingredient}
        </div>
        <div style={{ fontSize: sheet ? 16 : 14, lineHeight: sheet ? '23px' : '20px', fontWeight: 500, color: color.ink2 }}>
          {reason}
        </div>

        {showExtras && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            <span style={{ ...type.label, fontSize: 12, color: color.ink3, letterSpacing: '0.02em' }}>{copy.alternativesLabel}</span>
            <span style={{ ...type.bodySm, color: color.ink }}>{copy.alternatives}</span>
          </div>
        )}

        <div style={{ display: 'flex', gap: 8, marginTop: 6 }}>
          <InkButton label={copy.askDoctor} large={sheet} />
          <SecondaryButton label={actionLabel} large={sheet} />
        </div>

        {showTrace && (
          <div style={{ borderTop: `1px solid ${color.divider}`, display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div style={{ display: 'flex', alignItems: 'center', height: 44 }}>
              <span style={{ flex: 1, fontSize: 14, fontWeight: 500, color: color.ink2 }}>{copy.howWeKnow}</span>
              <span style={{ fontSize: 12, color: color.ink3, marginRight: 4, opacity: traceOpen > 0 ? 1 : 0 }}>{copy.confidence}</span>
              <div style={{ transform: `rotate(${Math.min(1, traceOpen * 3) * 90}deg)` }}>
                <Icon name="chevron" size={16} color={color.ink4} />
              </div>
            </div>
            {traceOpen > 0 && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6, paddingBottom: 4 }}>
                {copy.trace.map((t, i) => {
                  const o = Math.max(0, Math.min(1, rowsShown - i));
                  return (
                    <div key={t} style={{ display: 'flex', alignItems: 'center', gap: 8, opacity: o, transform: `translateY(${(1 - o) * 6}px)` }}>
                      <span style={{ width: 6, height: 6, borderRadius: 3, background: risk.NOT_LISTED.solid }} />
                      <span style={{ fontSize: 12, lineHeight: '16px', color: color.ink3 }}>{t}</span>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        )}

        <div
          style={{
            ...type.caption,
            color: color.ink4,
            textAlign: sheet ? 'center' : 'left',
          }}
        >
          {sheet ? copy.source : copy.sourceShort}
        </div>
      </div>
    </div>
  );
};
