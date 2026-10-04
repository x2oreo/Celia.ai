// Emergency screens: phone SOS countdown (DESIGN §10.2 "Emergency (active / SOS)"), the card's QR,
// and the shared web card opened on a bystander's phone (§10.2a). Patient data is fictional.
import React from 'react';
import { random } from 'remotion';
import { card, sos } from '../copy/script';
import { color, radius, risk, shadow, type } from '../theme/tokens';
import { StatusBar } from '../primitives/Devices';
import { HeartFill, Icon } from '../primitives/Icon';
import { RiskShape } from '../primitives/RiskShape';

export const SosCountdown: React.FC<{ seconds: number; total: number }> = ({ seconds, total }) => {
  const dim = 200;
  const stroke = 12;
  const r = (dim - stroke) / 2;
  const c = 2 * Math.PI * r;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', flex: 1, background: color.bg }}>
      <StatusBar time="14:34" right="5G · 64%" />
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '40px 20px 0', flex: 1 }}>
        <div style={{ ...type.label, color: risk.KNOWN.text, letterSpacing: '0.08em' }}>{sos.label}</div>
        <div style={{ ...type.title1, fontSize: 32, lineHeight: '36px', marginTop: 8 }}>{sos.title}</div>
        <div style={{ ...type.bodySm, color: color.ink3, marginTop: 6 }}>{sos.sub}</div>
        <div style={{ position: 'relative', width: dim, height: dim, marginTop: 40 }}>
          <svg width={dim} height={dim} style={{ position: 'absolute', inset: 0, transform: 'rotate(-90deg)' }}>
            <circle cx={dim / 2} cy={dim / 2} r={r} fill="none" stroke={color.border} strokeWidth={stroke} />
            <circle
              cx={dim / 2}
              cy={dim / 2}
              r={r}
              fill="none"
              stroke={risk.KNOWN.solid}
              strokeWidth={stroke}
              strokeLinecap="round"
              strokeDasharray={`${(seconds / total) * c} ${c}`}
            />
          </svg>
          <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
            <span style={{ ...type.display, fontSize: 72, lineHeight: '72px', fontVariantNumeric: 'tabular-nums' }}>{Math.ceil(seconds)}</span>
            <span style={{ ...type.bodySm, color: color.ink3 }}>seconds</span>
          </div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, width: '100%', marginTop: 'auto', marginBottom: 32 }}>
          <div style={{ height: 52, borderRadius: radius.btn, border: `1.5px solid ${color.borderStrong}`, background: color.surface, display: 'grid', placeItems: 'center', fontSize: 16, fontWeight: 700 }}>
            {sos.imOk}
          </div>
          <div style={{ height: 52, borderRadius: radius.btn, background: color.danger, color: color.white, display: 'grid', placeItems: 'center', fontSize: 16, fontWeight: 800 }}>
            {sos.sendNow}
          </div>
        </div>
      </div>
    </div>
  );
};

/** A QR-shaped pattern: real finder patterns, modules from a fixed seed. Decorative, it encodes nothing. */
export const QrPattern: React.FC<{ dim: number; seed?: string }> = ({ dim, seed = 'celia-card' }) => {
  const n = 29;
  const cell = dim / n;
  const finder = (x: number, y: number): boolean => {
    const inBox = (ox: number, oy: number): boolean => x >= ox && x < ox + 7 && y >= oy && y < oy + 7;
    return inBox(0, 0) || inBox(n - 7, 0) || inBox(0, n - 7);
  };
  const rects: React.ReactNode[] = [];
  for (let y = 0; y < n; y++) {
    for (let x = 0; x < n; x++) {
      if (finder(x, y) || (x < 8 && y < 8) || (x > n - 9 && y < 8) || (x < 8 && y > n - 9)) {
        continue;
      }
      if (random(`${seed}-${x}-${y}`) > 0.52) {
        rects.push(<rect key={`${x}-${y}`} x={x * cell} y={y * cell} width={cell + 0.3} height={cell + 0.3} fill={color.ink} />);
      }
    }
  }
  const eye = (ox: number, oy: number): React.ReactNode => (
    <g key={`e${ox}-${oy}`}>
      <rect x={ox * cell} y={oy * cell} width={7 * cell} height={7 * cell} fill={color.ink} rx={cell * 1.2} />
      <rect x={(ox + 1) * cell} y={(oy + 1) * cell} width={5 * cell} height={5 * cell} fill={color.white} rx={cell * 0.8} />
      <rect x={(ox + 2) * cell} y={(oy + 2) * cell} width={3 * cell} height={3 * cell} fill={color.ink} rx={cell * 0.6} />
    </g>
  );
  return (
    <svg width={dim} height={dim}>
      <rect width={dim} height={dim} fill={color.white} />
      {rects}
      {eye(0, 0)}
      {eye(n - 7, 0)}
      {eye(0, n - 7)}
    </svg>
  );
};

export const CardQrScreen: React.FC<{ qr: number }> = ({ qr }) => (
  <div style={{ display: 'flex', flexDirection: 'column', flex: 1, background: color.bg }}>
    <StatusBar time="14:35" right="5G · 64%" />
    <div style={{ padding: '14px 20px 0', display: 'flex', flexDirection: 'column', gap: 16 }}>
      <div style={{ ...type.title1 }}>{sos.qrTitle}</div>
      <div style={{ background: color.cardBg, border: `1.5px solid ${color.cardAlertBorder}`, borderRadius: radius.ml, padding: 16, display: 'flex', flexDirection: 'column', gap: 6 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, color: color.cardAlert }}>
          <HeartFill size={16} color={color.cardAlert} />
          <span style={{ ...type.label, letterSpacing: '0.08em' }}>MEDICAL ALERT</span>
        </div>
        <div style={{ ...type.title2, fontWeight: 800 }}>{card.patient}</div>
        <div style={{ ...type.bodySm, color: color.cardInk2 }}>{sos.tab.cardTitle} · {sos.tab.cardFacts}</div>
      </div>
      <div
        style={{
          alignSelf: 'center',
          padding: 16,
          background: color.surface,
          border: `1px solid ${color.border}`,
          borderRadius: radius.l,
          opacity: qr,
          transform: `translateY(${(1 - qr) * 12}px)`,
          boxShadow: shadow.e1,
        }}
      >
        <QrPattern dim={196} />
      </div>
      <div style={{ ...type.bodySm, color: color.ink3, textAlign: 'center', opacity: qr }}>{sos.qrSub}</div>
    </div>
  </div>
);

/** v2 06 Emergency tab: Start SOS + Call 112 first, responder view, medical card summary. `press` 0..1 dims the tile. */
export const EmergencyTab: React.FC<{ press: number }> = ({ press }) => {
  const t = sos.tab;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', flex: 1, background: color.bg }}>
      <StatusBar time="14:34" right="5G · 64%" />
      <div style={{ padding: '10px 16px 0', display: 'flex', flexDirection: 'column', gap: 12 }}>
        <div style={{ display: 'flex', alignItems: 'center', padding: '0 4px' }}>
          <span style={{ ...type.title1, flex: 1 }}>{t.title}</span>
          <span style={{ width: 44, height: 44, borderRadius: 22, border: `1px solid ${color.border}`, background: color.surface, display: 'grid', placeItems: 'center', color: color.ink2, boxSizing: 'border-box' }}>
            <Icon name="settings" size={20} />
          </span>
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          <div style={{ flex: 1.45, height: 132, borderRadius: radius.ml, background: color.danger, color: color.white, padding: 14, boxSizing: 'border-box', display: 'flex', flexDirection: 'column', justifyContent: 'space-between', transform: `scale(${1 - 0.03 * press})`, filter: `brightness(${1 - 0.12 * press})` }}>
            <span style={{ ...type.label, letterSpacing: '0.08em' }}>SOS</span>
            <div>
              <div style={{ fontSize: 24, lineHeight: '28px', fontWeight: 800 }}>{t.start}</div>
              <div style={{ fontSize: 12, lineHeight: '15px', fontWeight: 600, opacity: 0.92 }}>{t.startSub}</div>
            </div>
          </div>
          <div style={{ flex: 1, height: 132, borderRadius: radius.ml, background: color.surface, border: `1.5px solid ${color.danger}`, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', boxSizing: 'border-box', color: risk.KNOWN.text }}>
            <span style={{ fontSize: 15, fontWeight: 700 }}>{t.call}</span>
            <span style={{ fontSize: 36, lineHeight: '40px', fontWeight: 800 }}>{t.number}</span>
          </div>
        </div>
        <div style={{ borderRadius: radius.ml, background: color.ink, color: color.white, padding: '14px 16px', display: 'flex', alignItems: 'center' }}>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.06em', opacity: 0.75 }}>{t.responderCaps}</div>
            <div style={{ fontSize: 19, lineHeight: '24px', fontWeight: 800 }}>{t.responder}</div>
            <div style={{ fontSize: 13, opacity: 0.8 }}>{t.responderSub}</div>
          </div>
          <Icon name="chevronRight" size={20} />
        </div>
        <div style={{ borderRadius: radius.ml, background: color.surface, border: `1px solid ${color.border}`, padding: 16, display: 'flex', flexDirection: 'column', gap: 4 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <span style={{ fontSize: 12, fontWeight: 700, letterSpacing: '0.06em', color: risk.KNOWN.text }}>{t.cardCaps}</span>
            <span style={{ fontSize: 13, fontWeight: 700, color: color.brandText }}>{t.open}</span>
          </div>
          <div style={{ ...type.headline, fontSize: 18 }}>{t.cardTitle}</div>
          <div style={{ ...type.bodySm, color: color.ink2 }}>{t.cardFacts}</div>
          <div style={{ fontSize: 12, fontWeight: 600, color: color.ink3 }}>{t.cardInside}</div>
        </div>
      </div>
    </div>
  );
};

/**
 * The web card in Polish on a bystander's phone: the glance layer of the v3 card (DESIGN §11, 10.2a). Always light,
 * plain shapes, no coloured header band: identity, chips, 112 first, then "Do not give" as the Known-risk notice.
 */
export const WebCardPl: React.FC<{ langIndex: number }> = ({ langIndex }) => {
  const t = card.pl;
  const chip: React.CSSProperties = { height: 28, padding: '0 10px', borderRadius: 14, border: `1px solid ${color.cardBorder}`, fontSize: 12, fontWeight: 700, display: 'inline-flex', alignItems: 'center', whiteSpace: 'nowrap', color: color.cardInk };
  return (
    <div style={{ display: 'flex', flexDirection: 'column', flex: 1, background: color.cardBg }}>
      <StatusBar time="14:36" right="LTE · 41%" />
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '6px 16px 6px' }}>
        <span style={{ ...type.label, letterSpacing: '0.08em', color: color.cardAlert }}>{t.title}</span>
        <span style={{ height: 32, padding: '0 12px', borderRadius: 16, border: `1px solid ${color.cardBorder}`, display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 13, fontWeight: 700 }}>
          <Icon name="languages" size={16} />
          {card.languages[langIndex % card.languages.length]}
        </span>
      </div>
      <div style={{ padding: '6px 16px 0', display: 'flex', flexDirection: 'column', gap: 12 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <span style={{ width: 48, height: 48, borderRadius: 24, background: color.cardAlertTint, color: color.cardAlert, display: 'grid', placeItems: 'center', fontSize: 20, fontWeight: 800 }}>
            {card.patient.slice(0, 1)}
          </span>
          <div>
            <div style={{ ...type.title2, fontWeight: 800, color: color.cardInk }}>{card.patient}</div>
            <div style={{ ...type.bodySm, fontSize: 13, lineHeight: '17px', color: color.cardInk2 }}>{t.condition}</div>
          </div>
        </div>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
          <span style={chip}>{t.genotype}</span>
          <span style={chip}>{t.icd}</span>
        </div>
        <div style={{ height: 56, borderRadius: radius.m, background: color.danger, color: color.white, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10, fontSize: 19, fontWeight: 800 }}>
          <Icon name="phone" size={22} color={color.white} />
          {t.call}
        </div>
        <div style={{ background: color.cardAlertTint, border: `1px solid ${color.cardAlertBorder}`, borderRadius: radius.m, padding: '12px 14px', display: 'flex', gap: 10 }}>
          <RiskShape level="KNOWN" dim={24} />
          <span style={{ fontSize: 14, lineHeight: '19px', fontWeight: 700, color: color.cardAlert }}>{t.avoid}</span>
        </div>
        <div style={{ fontSize: 13, color: color.cardInk3 }}>
          {t.meds}: <b style={{ color: color.cardInk }}>{t.medsValue}</b>
        </div>
        <div style={{ height: 52, borderRadius: radius.m, border: `1px solid ${color.cardBorder}`, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, fontSize: 15, fontWeight: 700 }}>
          <Icon name="phone" size={18} />
          {t.contact}
        </div>
        <div style={{ ...type.caption, color: color.ink4, textAlign: 'center' }}>{t.footer}</div>
      </div>
    </div>
  );
};
