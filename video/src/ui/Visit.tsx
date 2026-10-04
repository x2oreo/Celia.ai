// Doctor visit brief (DoctorVisitPage, DESIGN §11 "Doctor visits") and the pharmacy card (PharmacyCardPage).
// Ola and her numbers are fictional; the brief is labelled SIMULATED like every scripted heart number in the film.
import React from 'react';
import { visit } from '../copy/script';
import { color, radius, risk, type } from '../theme/tokens';
import { SourceBadge } from '../primitives/Badges';
import { StatusBar } from '../primitives/Devices';
import { Icon } from '../primitives/Icon';
import { RiskShape } from '../primitives/RiskShape';

const Caps: React.FC<{ text: string }> = ({ text }) => (
  <span style={{ ...type.label, letterSpacing: '0.06em', color: color.ink3 }}>{text}</span>
);

/** `rows` gives each reveal step 0..1: the four "since" rows, then the questions, then the share button. */
export const DoctorBriefScreen: React.FC<{ rows: number[] }> = ({ rows }) => {
  const at = (i: number): React.CSSProperties => {
    const p = rows[i] ?? 0;
    return { opacity: p, transform: `translateY(${(1 - p) * 12}px)` };
  };
  return (
    <div style={{ display: 'flex', flexDirection: 'column', flex: 1, background: color.bg }}>
      <StatusBar time="09:10" />
      <div style={{ display: 'flex', alignItems: 'center', height: 48, padding: '0 12px' }}>
        <Icon name="back" size={22} stroke={2} />
      </div>
      <div style={{ padding: '0 20px', display: 'flex', flexDirection: 'column', gap: 4 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{ ...type.title1, flex: 1 }}>{visit.title}</div>
          <SourceBadge label={visit.sim} />
        </div>
        <div style={{ ...type.bodySm, color: color.ink3 }}>{visit.who}</div>
      </div>
      <div style={{ padding: '16px 20px 0', display: 'flex', flexDirection: 'column', gap: 10 }}>
        <Caps text={visit.sinceCaps} />
        <div style={{ background: color.surface, border: `1px solid ${color.border}`, borderRadius: radius.m, overflow: 'hidden' }}>
          {visit.since.map((r, i) => {
            const flagged = i === 2;
            return (
              <div
                key={r.k}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 10,
                  padding: '12px 14px',
                  borderTop: i === 0 ? 'none' : `1px solid ${color.divider}`,
                  ...at(i),
                }}
              >
                <span style={{ ...type.bodySm, color: color.ink2, flex: 1 }}>{r.k}</span>
                {flagged && <RiskShape level="KNOWN" dim={18} />}
                <span style={{ ...type.bodySm, fontWeight: 700, color: flagged ? risk.KNOWN.text : color.ink }}>{r.v}</span>
              </div>
            );
          })}
        </div>
        <div style={{ marginTop: 6, ...at(4) }}>
          <Caps text={visit.askCaps} />
        </div>
        {visit.ask.map((q, i) => (
          <div
            key={q}
            style={{ display: 'flex', gap: 10, alignItems: 'flex-start', background: color.surface, border: `1px solid ${color.border}`, borderRadius: radius.m, padding: '12px 14px', ...at(4 + i) }}
          >
            <span style={{ width: 22, height: 22, borderRadius: 11, background: color.brandTint, color: color.brandText, display: 'grid', placeItems: 'center', fontSize: 12, fontWeight: 800, flex: 'none' }}>
              {i + 1}
            </span>
            <span style={{ ...type.bodySm, color: color.ink }}>{q}</span>
          </div>
        ))}
      </div>
      <div style={{ marginTop: 'auto', padding: '0 20px 28px', ...at(6) }}>
        <div style={{ height: 52, borderRadius: radius.btn, background: color.ink, color: color.onBrand, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, ...type.button, fontSize: 16 }}>
          <Icon name="share" size={18} />
          {visit.share}
        </div>
      </div>
    </div>
  );
};

/** Pharmacy card: always light, the country's language big, English under it, then the medicines. */
export const PharmacyCardScreen: React.FC = () => {
  const p = visit.pharmacy;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', flex: 1, background: color.cardBg }}>
      <StatusBar time="17:42" right="LTE · 51%" />
      <div style={{ display: 'flex', alignItems: 'center', height: 48, padding: '0 12px', gap: 8 }}>
        <Icon name="back" size={22} stroke={2} />
        <span style={{ ...type.headline }}>{p.title}</span>
      </div>
      <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 20 }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <div style={{ fontSize: 28, lineHeight: '32px', fontWeight: 800, color: color.cardAlert }}>{p.headline}</div>
          <div style={{ fontSize: 20, lineHeight: '27px', fontWeight: 500, color: color.cardInk }}>{p.body}</div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          <div style={{ fontSize: 18, lineHeight: '23px', fontWeight: 700, color: color.cardAlert }}>{p.enHeadline}</div>
          <div style={{ fontSize: 15, lineHeight: '21px', fontWeight: 500, color: color.cardInk }}>{p.enBody}</div>
        </div>
        <div style={{ height: 1, background: color.cardBorder }} />
        <div style={{ ...type.title3, color: color.cardInk }}>{p.meds}</div>
        <div style={{ ...type.caption, fontSize: 12, color: color.cardInk3 }}>{p.country}</div>
      </div>
    </div>
  );
};
