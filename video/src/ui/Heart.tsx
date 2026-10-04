// Phone heart-rate ring (components/HrRing.ets), Today (v2 01), the v2 tab bar and the check-in sheet (B3).
// Heart rate only: the ring is a progress arc, never a trace.
import React from 'react';
import { useCurrentFrame } from 'remotion';
import { today, watch as wcopy } from '../copy/script';
import { heartbeat } from '../theme/motion';
import { color, radius, risk, type } from '../theme/tokens';
import { SourceBadge } from '../primitives/Badges';
import { HeartFill, Icon } from '../primitives/Icon';
import { RiskShape } from '../primitives/RiskShape';
import { AgentAvatar } from './Orb';
import { SilkOrb } from './SilkOrb';

export type HrZone = 'CALM' | 'ELEVATED' | 'ALERT';

const zoneColor = (zone: HrZone): string =>
  zone === 'ALERT' ? risk.KNOWN.solid : zone === 'ELEVATED' ? risk.POSSIBLE.solid : color.brand;

export const HrRing: React.FC<{ bpm: number; zone: HrZone; caption: string; source: 'WATCH' | 'SIMULATED'; dim?: number }> = ({
  bpm,
  zone,
  caption,
  source,
  dim = 232,
}) => {
  const frame = useCurrentFrame();
  const stroke = 12;
  const r = (dim - stroke) / 2;
  const c = 2 * Math.PI * r;
  const arc = Math.max(4, Math.min(100, ((bpm - 40) / 140) * 100)) / 100;
  const beat = heartbeat(frame, zone === 'CALM' ? 1100 : 600);
  return (
    <div style={{ position: 'relative', width: dim, height: dim }}>
      <svg width={dim} height={dim} style={{ position: 'absolute', inset: 0, transform: 'rotate(-90deg)' }}>
        <circle cx={dim / 2} cy={dim / 2} r={r} fill="none" stroke={color.border} strokeWidth={stroke} />
        <circle
          cx={dim / 2}
          cy={dim / 2}
          r={r}
          fill="none"
          stroke={zoneColor(zone)}
          strokeWidth={stroke}
          strokeLinecap="round"
          strokeDasharray={`${arc * c} ${c}`}
        />
      </svg>
      <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 2 }}>
        <div style={{ transform: `scale(${beat})` }}>
          <HeartFill size={20} color={color.brand} />
        </div>
        <span style={{ ...type.display, fontVariantNumeric: 'tabular-nums', lineHeight: '64px', color: color.ink }}>{Math.round(bpm)}</span>
        <span style={{ ...type.body, color: color.ink3 }}>{caption}</span>
        <div style={{ marginTop: 8 }}>
          <SourceBadge label={source} solid={source === 'WATCH'} />
        </div>
      </div>
    </div>
  );
};

const Tab: React.FC<{ icon: 'tabHome' | 'tabMedicines' | 'tabHeart'; label: string; active?: boolean }> = ({ icon, label, active = false }) => (
  <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3, color: active ? color.brandText : color.tabInactive, fontWeight: active ? 700 : 600 }}>
    <Icon name={icon} size={24} color={active ? color.brand : color.tabInactive} />
    {label}
  </div>
);

/** v2 tab bar (DESIGN §6.5): Today · Medicines · the orb · Health · Emergency. */
export const TabBar: React.FC<{ orbFrame?: number; dot?: boolean }> = ({ orbFrame, dot = true }) => (
  <div style={{ position: 'relative', marginTop: 'auto', display: 'flex', alignItems: 'center', height: 64, padding: '6px 4px 12px', background: color.surface, borderTop: `1px solid ${color.border}`, fontSize: 11, flex: 'none' }}>
    <Tab icon="tabHome" label={today.tabs.today} active />
    <Tab icon="tabMedicines" label={today.tabs.medicines} />
    <div style={{ flex: 1, position: 'relative', alignSelf: 'stretch' }}>
      <div style={{ position: 'absolute', left: '50%', top: -36, transform: 'translateX(-50%)', width: 68, height: 68, borderRadius: 34, background: color.surface, display: 'grid', placeItems: 'center' }}>
        <SilkOrb dim={56} small frame={orbFrame} glow={false} pixelRatio={3} />
        {dot && <span style={{ position: 'absolute', right: 6, top: 6, width: 12, height: 12, borderRadius: 6, background: color.ink, border: `2px solid ${color.surface}` }} />}
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, textAlign: 'center', color: color.tabInactive, fontWeight: 600 }}>{today.tabs.talk}</div>
    </div>
    <Tab icon="tabHeart" label={today.tabs.health} />
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3, color: risk.KNOWN.text, fontWeight: 700 }}>
      <span style={{ height: 24, padding: '0 10px', borderRadius: 12, background: color.brandTint, fontSize: 10, fontWeight: 800, letterSpacing: '0.06em', display: 'grid', placeItems: 'center' }}>SOS</span>
      {today.tabs.emergency}
    </div>
  </div>
);

const Card: React.FC<{ children: React.ReactNode; style?: React.CSSProperties }> = ({ children, style }) => (
  <div style={{ background: color.surface, border: `1px solid ${color.border}`, borderRadius: radius.l, padding: 16, ...style }}>{children}</div>
);

const Caps: React.FC<{ text: string }> = ({ text }) => (
  <span style={{ fontSize: 12, lineHeight: '16px', fontWeight: 700, letterSpacing: '0.06em', color: color.ink3 }}>{text}</span>
);

/** v2 01 Today: header, agent line, next dose, resting 7 days, quick actions, medicines chip. */
export const TodayScreen: React.FC<{ bpm: number; zone: HrZone }> = ({ bpm, zone }) => {
  const frame = useCurrentFrame();
  const beat = heartbeat(frame, zone === 'CALM' ? 1100 : 600);
  const max = Math.max(...today.restingBars);
  const ringDim = 84;
  const r = (ringDim - 8) / 2;
  const c = 2 * Math.PI * r;
  const arc = Math.max(0.05, Math.min(1, (bpm - 40) / 140));
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 12, padding: '4px 16px 0' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '0 4px' }}>
        <div style={{ flex: 1 }}>
          <div style={{ ...type.bodySm, color: color.ink3 }}>{today.date}</div>
          <div style={{ ...type.title3, fontWeight: 800, color: color.ink }}>{today.greeting}</div>
        </div>
        <span style={{ height: 32, padding: '0 12px', borderRadius: 16, border: `1px solid ${color.border}`, background: color.surface, fontSize: 13, fontWeight: 700, display: 'grid', placeItems: 'center' }}>{today.genotype}</span>
        <span style={{ width: 44, height: 44, borderRadius: 22, border: `1px solid ${color.border}`, background: color.surface, display: 'grid', placeItems: 'center', color: color.ink2, boxSizing: 'border-box' }}>
          <Icon name="settings" size={20} />
        </span>
      </div>
      <Card style={{ display: 'flex', alignItems: 'center', gap: 12, padding: 12 }}>
        <AgentAvatar dim={40} />
        <span style={{ flex: 1, fontSize: 15, lineHeight: '21px', fontWeight: 600 }}>{today.agentLine}</span>
        <Icon name="chevronRight" size={18} color={color.ink4} />
      </Card>
      <Card style={{ display: 'flex', flexDirection: 'column', gap: 10, padding: 14 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
          <Caps text={today.nextDose} />
          <span style={{ fontSize: 13, fontWeight: 700, color: color.brandText }}>{today.allReminders}</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <span style={{ width: 44, height: 44, borderRadius: 12, background: color.surfaceAlt, display: 'grid', placeItems: 'center', color: color.ink2 }}>
            <Icon name="pill" size={22} />
          </span>
          <div style={{ flex: 1 }}>
            <div style={{ ...type.headline }}>{today.doseName}</div>
            <div style={{ ...type.bodySm, fontSize: 13, color: color.ink3 }}>{today.doseDue}</div>
          </div>
          <span style={{ height: 44, padding: '0 16px', borderRadius: 22, background: color.ink, color: color.onBrand, display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 15, fontWeight: 700 }}>
            <Icon name="check" size={16} />
            {today.taken}
          </span>
        </div>
      </Card>
      <Card style={{ display: 'flex', alignItems: 'center', gap: 14, padding: 14 }}>
        <div style={{ position: 'relative', width: ringDim, height: ringDim, flex: 'none' }}>
          <svg width={ringDim} height={ringDim} style={{ position: 'absolute', inset: 0, transform: 'rotate(-90deg)' }}>
            <circle cx={ringDim / 2} cy={ringDim / 2} r={r} fill="none" stroke={color.border} strokeWidth={8} />
            <circle cx={ringDim / 2} cy={ringDim / 2} r={r} fill="none" stroke={zoneColor(zone)} strokeWidth={8} strokeLinecap="round" strokeDasharray={`${arc * c} ${c}`} />
          </svg>
          <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
            <span style={{ fontSize: 26, lineHeight: '28px', fontWeight: 800, fontVariantNumeric: 'tabular-nums', transform: `scale(${1 + (beat - 1) * 0.2})` }}>{Math.round(bpm)}</span>
            <span style={{ fontSize: 11, color: color.ink3 }}>bpm</span>
          </div>
          <div style={{ position: 'absolute', left: '50%', bottom: -6, transform: 'translateX(-50%)' }}>
            <SourceBadge label="SIMULATED" />
          </div>
        </div>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 8 }}>
          <Caps text={today.resting} />
          <div style={{ display: 'flex', alignItems: 'flex-end', gap: 5, height: 36 }}>
            {today.restingBars.map((v, i) => (
              <span key={i} style={{ flex: 1, height: `${(v / max) * 100}%`, borderRadius: 3, background: i === today.restingBars.length - 1 ? color.brand : color.brandTint }} />
            ))}
          </div>
          <span style={{ ...type.bodySm, fontSize: 13, lineHeight: '17px', color: color.ink2 }}>{today.restingNote}</span>
        </div>
      </Card>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
        {today.actions.map((a) => (
          <div key={a.label} style={{ height: 64, background: color.surface, border: `1px solid ${color.border}`, borderRadius: radius.m, display: 'flex', alignItems: 'center', gap: 10, padding: '0 12px', boxSizing: 'border-box' }}>
            <span style={{ width: 36, height: 36, borderRadius: 10, background: color.brandTint, display: 'grid', placeItems: 'center', color: color.brand, flex: 'none' }}>
              <Icon name={a.icon} size={18} />
            </span>
            <span style={{ fontSize: 15, lineHeight: '18px', fontWeight: 700 }}>{a.label}</span>
          </div>
        ))}
      </div>
      <span style={{ alignSelf: 'flex-start', height: 36, padding: '0 14px 0 8px', display: 'inline-flex', alignItems: 'center', gap: 8, borderRadius: 18, background: color.surface, border: `1px solid ${color.border}`, fontSize: 14, fontWeight: 600 }}>
        <RiskShape level="NOT_LISTED" dim={20} />
        {today.medsChip}
      </span>
    </div>
  );
};

export const TodayWithTabs: React.FC<{ bpm: number; zone: HrZone; orbFrame?: number }> = ({ bpm, zone, orbFrame }) => (
  <div style={{ display: 'flex', flexDirection: 'column', flex: 1 }}>
    <TodayScreen bpm={bpm} zone={zone} />
    <TabBar orbFrame={orbFrame} />
  </div>
);

/** B3 check-in sheet body. */
export const CheckInBody: React.FC<{ bpm: number; question?: string }> = ({ bpm, question = wcopy.checkInQuestion }) => {
  const s = risk.POSSIBLE;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
        <AgentAvatar dim={40} />
        <div>
          <div style={{ fontSize: 16, fontWeight: 700, lineHeight: '20px' }}>The agent</div>
          <div style={{ fontSize: 13, color: color.ink3 }}>{wcopy.checkInFrom}</div>
        </div>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 16px', borderRadius: radius.m, background: s.tint, border: `1px solid ${s.border}` }}>
        <RiskShape level="POSSIBLE" dim={34} />
        <div>
          <div style={{ fontSize: 28, lineHeight: '30px', fontWeight: 800, color: s.text, fontVariantNumeric: 'tabular-nums' }}>{Math.round(bpm)} bpm</div>
          <div style={{ fontSize: 14, fontWeight: 600, color: s.text }}>{wcopy.checkInChipTitle}</div>
        </div>
      </div>
      <div style={{ ...type.title3, color: color.ink }}>{question}</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        <div style={{ height: 52, borderRadius: radius.btn, border: `1.5px solid ${color.borderStrong}`, background: color.surface, display: 'grid', placeItems: 'center', fontSize: 16, fontWeight: 700 }}>
          {wcopy.fine}
        </div>
        <div style={{ height: 52, borderRadius: radius.btn, background: color.ink, color: color.white, display: 'grid', placeItems: 'center', fontSize: 16, fontWeight: 800 }}>
          {wcopy.dizzy}
        </div>
        <div style={{ height: 52, borderRadius: radius.btn, background: color.danger, color: color.white, display: 'grid', placeItems: 'center', fontSize: 16, fontWeight: 800 }}>
          {wcopy.callHelp}
        </div>
      </div>
      <div style={{ ...type.caption, fontSize: 12, color: color.ink3, textAlign: 'center' }}>{wcopy.checkAgain}</div>
    </div>
  );
};
